import uuid
import httpx
from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

# นำเข้า dependencies ทั้งหมด
from database import get_db
from models import MachineSlot, Order, OrderItem
from schemas import CartCheckout, OrderResponse, OrderItemOut
from promptpay import generate_promptpay_payload
from websocket_manager import broadcast_stock

# ประกาศ Router และตัวแปรแค่ครั้งเดียว
router = APIRouter(prefix="/api/orders", tags=["orders"])
MIDDLEWARE_URL = "http://127.0.0.1:8080/api/middleware/cash"


# ==========================================
# 1. API สำหรับสร้างออเดอร์ (กดปุ่มสแกน QR / เงินสด)
# ==========================================
@router.post("/checkout", response_model=OrderResponse)
async def create_order(cart: CartCheckout, db: Session = Depends(get_db)):
    # สร้างหมายเลขออเดอร์
    order_no = f"ORD-{uuid.uuid4().hex[:8].upper()}"
    total_amount = 0.0
    items_out = []

    # ตรวจสอบสต็อกและคำนวณยอดรวม
    for item in cart.items:
        slot = db.get(MachineSlot, item.slot_id)
        if not slot:
            raise HTTPException(status_code=404, detail=f"ไม่พบสินค้าสล็อตที่ {item.slot_id}")
        if slot.current_stock < item.qty:
            raise HTTPException(status_code=400, detail=f"สินค้า '{slot.product.name}' ไม่เพียงพอ")
        
        # หักสต็อก
        slot.current_stock -= item.qty
        line_price = slot.product.price * item.qty
        total_amount += line_price
        
        items_out.append(
            OrderItemOut(
                slot_code=slot.slot_code,
                product_name=slot.product.name,
                qty=item.qty,
                unit_price=slot.product.price
            )
        )

    db.commit()
    # แจ้งเตือนไปยัง Frontend ให้อัปเดตสต็อกแบบ Real-time
    await broadcast_stock(db) 

    # สร้าง QR Code หากเลือกวิธีชำระเงินเป็น promptpay_qr
    qr_payload = None
    if cart.payment_method == "promptpay_qr":
        # ใส่เบอร์โทรศัพท์หรือหมายเลข PromptPay ของร้านค้า
        MERCHANT_PROMPTPAY = "0812345678" 
        qr_payload = generate_promptpay_payload(MERCHANT_PROMPTPAY, total_amount)

    return OrderResponse(
        order_no=order_no,
        machine_code="VM-01", 
        items=items_out,
        amount=total_amount,
        payment_method=cart.payment_method,
        qr_payload=qr_payload,
        status="PENDING"
    )


# ==========================================
# 2. API สำหรับจัดการ Middleware เงินสด
# ==========================================
@router.post("/cash/start")
async def start_cash_session(order_no: str, amount_due: int):
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.post(
                f"{MIDDLEWARE_URL}/session/start",
                json={"order_no": order_no, "amount_due": amount_due}
            )
            resp.raise_for_status()
            return resp.json()
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=f"Middleware error: {e.response.text}")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Middleware connection failed: {str(e)}")

@router.get("/cash/status")
async def get_cash_status():
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.get(f"{MIDDLEWARE_URL}/status")
            resp.raise_for_status()
            return resp.json()
    except Exception:
        # หากเชื่อมต่อไม่ได้ ให้คืนค่าเริ่มต้นเพื่อไม่ให้หน้าบ้านพัง
        return {"is_active": False, "amount_inserted": 0, "amount_due": 0, "change_due": 0, "is_completed": False}

@router.post("/cash/complete")
async def complete_cash_session(order_no: str):
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            dispense = await client.post(f"{MIDDLEWARE_URL}/dispense")
            dispense.raise_for_status()
            return {"status": "SUCCESS", "detail": dispense.json()}
    except httpx.HTTPStatusError as e:
        raise HTTPException(status_code=e.response.status_code, detail=f"Middleware dispense failed: {e.response.text}")
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Middleware connection failed: {str(e)}")