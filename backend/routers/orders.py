import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from config import MACHINE_CODE, PROMPTPAY_ID
from database import get_db
from models import Product, MachineSlot, Order, OrderItem, Payment
from promptpay import generate_promptpay_payload
from schemas import CartLine, CartCheckout, OrderItemOut, OrderResponse
from websocket_manager import broadcast_stock

router = APIRouter()


def _build_order_response(db: Session, order: Order, qr: Optional[str], payment_method: str) -> OrderResponse:
    items = db.query(OrderItem).filter(OrderItem.order_id == order.id).all()
    return OrderResponse(
        order_no=order.order_no,
        machine_code=order.machine_code,
        items=[
            OrderItemOut(
                slot_code=db.get(MachineSlot, it.slot_id).slot_code,
                product_name=db.get(Product, it.product_id).name,
                qty=it.qty,
                unit_price=it.unit_price,
            ) for it in items
        ],
        amount=order.amount,
        payment_method=payment_method,
        qr_payload=qr,
        status=order.status,
    )


@router.post("/api/orders/checkout", response_model=OrderResponse)
async def checkout_cart(data: CartCheckout, db: Session = Depends(get_db)):
    """สร้างออเดอร์เดียวจากตะกร้าที่มีได้หลายรายการ พร้อมเลือกวิธีชำระเงินได้ทั้ง QR PromptPay และเงินสด"""
    if not data.items:
        raise HTTPException(status_code=400, detail="ตะกร้าว่าง")

    slots = {}
    total = 0.0
    for line in data.items:
        slot = db.get(MachineSlot, line.slot_id)
        if not slot:
            raise HTTPException(status_code=404, detail=f"ไม่พบช่องสินค้ารหัส {line.slot_id}")
        if slot.current_stock < line.qty:
            raise HTTPException(status_code=400, detail=f"{slot.product.name} สินค้าเหลือไม่พอ")
        slots[line.slot_id] = slot
        total += slot.product.price * line.qty

    order_no = f"ORD-{uuid.uuid4().hex[:8].upper()}"
    first_line = data.items[0]
    order = Order(
        order_no=order_no,
        machine_code=MACHINE_CODE,
        slot_id=first_line.slot_id,
        product_id=slots[first_line.slot_id].product_id,
        amount=total,
        status="pending",
    )
    db.add(order)
    db.commit()
    db.refresh(order)

    for line in data.items:
        slot = slots[line.slot_id]
        db.add(OrderItem(
            order_id=order.id,
            slot_id=slot.id,
            product_id=slot.product_id,
            qty=line.qty,
            unit_price=slot.product.price,
        ))
    db.commit()

    qr_payload = None
    if data.payment_method == "cash":
        # ชำระเงินสด: ตัดสต็อกทันทีเสมือนหยอดเงินครบแล้ว ไม่ต้องออก QR
        for line in data.items:
            slots[line.slot_id].current_stock -= line.qty
        order.status = "completed"
        db.add(Payment(order_id=order.id, amount=total, payment_method="cash",
                        qr_payload=None, status="paid", paid_at=datetime.utcnow()))
        db.commit()
        await broadcast_stock(db)
    else:
        qr_payload = generate_promptpay_payload(PROMPTPAY_ID, total)
        db.add(Payment(order_id=order.id, amount=total, payment_method="promptpay_qr",
                        qr_payload=qr_payload, status="unpaid"))
        db.commit()

    return _build_order_response(db, order, qr_payload, data.payment_method)


@router.post("/api/orders/create/{slot_id}", response_model=OrderResponse)
async def create_order(slot_id: int, db: Session = Depends(get_db)):
    """คงไว้เพื่อความเข้ากันได้ย้อนหลัง (สร้างออเดอร์แบบ 1 ช่อง 1 ชิ้น ชำระด้วย QR) — แนะนำให้ใช้ /api/orders/checkout แทน"""
    return await checkout_cart(CartCheckout(items=[CartLine(slot_id=slot_id, qty=1)], payment_method="promptpay_qr"), db)


@router.post("/api/orders/{order_no}/confirm-pay")
async def confirm_payment(order_no: str, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.order_no == order_no).first()
    if not order or order.status != "pending":
        raise HTTPException(status_code=400, detail="สถานะออเดอร์ไม่ถูกต้อง")

    items = db.query(OrderItem).filter(OrderItem.order_id == order.id).all()
    for it in items:
        slot = db.get(MachineSlot, it.slot_id)
        if slot.current_stock < it.qty:
            order.status = "cancelled"
            db.commit()
            raise HTTPException(status_code=400, detail="สินค้าเหลือไม่พอ (มีคนซื้อไปก่อน)")

    for it in items:
        slot = db.get(MachineSlot, it.slot_id)
        slot.current_stock -= it.qty

    order.status = "completed"
    payment = db.query(Payment).filter(Payment.order_id == order.id).first()
    if payment:
        payment.status = "paid"
        payment.paid_at = datetime.utcnow()
    db.commit()
    await broadcast_stock(db)
    return {"status": "completed", "message": "ชำระเงินสำเร็จ กรุณารับสินค้า"}
