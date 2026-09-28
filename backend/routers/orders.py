import uuid
from datetime import datetime

import httpx
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from config import MACHINE_CODE, PROMPTPAY_ID
from database import get_db
from models import MachineSlot, Order, OrderItem, Payment
from schemas import CartCheckout, OrderResponse, OrderItemOut
from promptpay import generate_promptpay_payload
from websocket_manager import broadcast_stock

router = APIRouter(prefix="/api/orders", tags=["orders"])
MIDDLEWARE_URL = "http://127.0.0.1:8080/api/middleware/cash"


def _get_order(db: Session, order_no: str) -> Order:
    order = db.query(Order).filter(Order.order_no == order_no).first()
    if not order:
        raise HTTPException(status_code=404, detail="ไม่พบออเดอร์")
    return order


async def _call_middleware(method: str, path: str, **kwargs):
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.request(method, f"{MIDDLEWARE_URL}{path}", **kwargs)
            resp.raise_for_status()
            return resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=f"Middleware error: {e.response.text}")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"เชื่อมต่อ Cash Middleware ไม่ได้ (พอร์ต 8080): {e}")


# ==========================================
# 1. สร้างออเดอร์ (เลือกช่องทางชำระเงิน: promptpay_qr / cash)
#    จองสต็อกไว้ทันที ถ้ายกเลิกจะคืนสต็อกให้
# ==========================================
@router.post("/checkout", response_model=OrderResponse)
async def create_order(cart: CartCheckout, db: Session = Depends(get_db)):
    if cart.payment_method not in ("promptpay_qr", "cash"):
        raise HTTPException(status_code=400, detail="ช่องทางชำระเงินไม่ถูกต้อง")
    if not cart.items:
        raise HTTPException(status_code=400, detail="ตะกร้าว่าง")

    order_no = f"ORD-{uuid.uuid4().hex[:8].upper()}"
    total_amount = 0.0
    items_out = []
    order_items = []

    for item in cart.items:
        slot = db.get(MachineSlot, item.slot_id)
        if not slot:
            raise HTTPException(status_code=404, detail=f"ไม่พบสินค้าสล็อตที่ {item.slot_id}")
        if item.qty < 1 or slot.current_stock < item.qty:
            raise HTTPException(status_code=400, detail=f"สินค้า '{slot.product.name}' ไม่เพียงพอ")

        slot.current_stock -= item.qty
        total_amount += slot.product.price * item.qty
        order_items.append((slot, item.qty))
        items_out.append(OrderItemOut(
            slot_code=slot.slot_code,
            product_name=slot.product.name,
            qty=item.qty,
            unit_price=slot.product.price,
        ))

    qr_payload = None
    if cart.payment_method == "promptpay_qr":
        qr_payload = generate_promptpay_payload(PROMPTPAY_ID, total_amount)

    order = Order(order_no=order_no, machine_code=MACHINE_CODE, amount=total_amount, status="pending")
    db.add(order)
    db.flush()
    for slot, qty in order_items:
        db.add(OrderItem(order_id=order.id, slot_id=slot.id, product_id=slot.product_id,
                         qty=qty, unit_price=slot.product.price))
    db.add(Payment(order_id=order.id, amount=total_amount, payment_method=cart.payment_method,
                   qr_payload=qr_payload, status="unpaid"))
    db.commit()
    await broadcast_stock(db)

    # เงินสด: เปิด session รับเงินที่ middleware ทันที
    if cart.payment_method == "cash":
        try:
            await _call_middleware("POST", "/session/start",
                                   json={"order_no": order_no, "amount_due": int(round(total_amount))})
        except HTTPException:
            await _release(db, order)  # เปิด session ไม่ได้ -> คืนสต็อก
            raise

    return OrderResponse(
        order_no=order_no, machine_code=MACHINE_CODE, items=items_out,
        amount=total_amount, payment_method=cart.payment_method,
        qr_payload=qr_payload, status="PENDING",
    )


async def _release(db: Session, order: Order):
    """คืนสต็อกและตั้งสถานะยกเลิก (ใช้เฉพาะออเดอร์ที่ยัง pending)"""
    if order.status != "pending":
        return
    for oi in db.query(OrderItem).filter(OrderItem.order_id == order.id).all():
        slot = db.get(MachineSlot, oi.slot_id)
        if slot:
            slot.current_stock += oi.qty
    order.status = "cancelled"
    for p in db.query(Payment).filter(Payment.order_id == order.id).all():
        p.status = "cancelled"
    db.commit()
    await broadcast_stock(db)


# ==========================================
# 2. ยกเลิกออเดอร์ (ปุ่มยกเลิกใน popup ทั้งเงินสดและ QR)
# ==========================================
@router.post("/{order_no}/cancel")
async def cancel_order(order_no: str, db: Session = Depends(get_db)):
    order = _get_order(db, order_no)
    if order.status != "pending":
        raise HTTPException(status_code=400, detail="ออเดอร์นี้ไม่สามารถยกเลิกได้แล้ว")

    payment = db.query(Payment).filter(Payment.order_id == order.id).first()
    refund = 0
    if payment and payment.payment_method == "cash":
        try:
            result = await _call_middleware("POST", "/cancel")
            refund = result.get("refund_amount", 0)
        except HTTPException:
            pass  # middleware ปิดอยู่ ก็ยังยกเลิกออเดอร์ได้
    await _release(db, order)
    return {"status": "CANCELLED", "refund_amount": refund}


# ==========================================
# 3. ยืนยันชำระ QR (จำลอง — ของจริงต้องต่อ webhook ธนาคาร)
# ==========================================
@router.post("/{order_no}/confirm-qr")
async def confirm_qr(order_no: str, db: Session = Depends(get_db)):
    order = _get_order(db, order_no)
    if order.status != "pending":
        raise HTTPException(status_code=400, detail="ออเดอร์นี้ถูกดำเนินการไปแล้ว")
    order.status = "paid"
    for p in db.query(Payment).filter(Payment.order_id == order.id).all():
        p.status = "paid"
        p.paid_at = datetime.utcnow()
    db.commit()
    return {"status": "SUCCESS"}


# ==========================================
# 4. Middleware เงินสด
# ==========================================
@router.post("/cash/start")
async def start_cash_session(order_no: str, amount_due: int):
    return await _call_middleware("POST", "/session/start",
                                  json={"order_no": order_no, "amount_due": amount_due})


@router.get("/cash/status")
async def get_cash_status():
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.get(f"{MIDDLEWARE_URL}/status")
            resp.raise_for_status()
            return resp.json()
    except Exception:
        return {"is_active": False, "amount_inserted": 0, "amount_due": 0,
                "change_due": 0, "is_completed": False, "middleware_offline": True}


@router.post("/cash/complete")
async def complete_cash_session(order_no: str, db: Session = Depends(get_db)):
    order = _get_order(db, order_no)
    if order.status != "pending":
        raise HTTPException(status_code=400, detail="ออเดอร์นี้ถูกดำเนินการไปแล้ว")
    status = await _call_middleware("GET", "/status")
    if not status.get("is_completed") or status.get("order_no") != order_no:
        raise HTTPException(status_code=400, detail="ยังหยอดเงินไม่ครบ")
    dispense = await _call_middleware("POST", "/dispense")
    order.status = "paid"
    for p in db.query(Payment).filter(Payment.order_id == order.id).all():
        p.status = "paid"
        p.paid_at = datetime.utcnow()
    db.commit()
    return {"status": "SUCCESS", "detail": dispense}
