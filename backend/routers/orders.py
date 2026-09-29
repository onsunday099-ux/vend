import random
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

import models
from config import MACHINE_CODE, PROMPTPAY_ID
from database import get_db
from middleware.cash_middleware import (
    session, broadcast_cash_status, cancel_pending_order,
)
from payment_service import finalize_paid, PaymentError
from promptpay import generate_promptpay_payload
from websocket_manager import broadcast_stock

router = APIRouter(prefix="/api/orders", tags=["orders"])


class CheckoutItem(BaseModel):
    slot_id: Optional[str] = None     # id ของช่อง (Flutter ส่งค่านี้)
    slot_code: Optional[str] = None   # หรือรหัสช่อง เช่น A1
    qty: int = 1


class CheckoutRequest(BaseModel):
    payment_method: str               # cash | promptpay_qr (รับ qr ด้วย)
    items: List[CheckoutItem]


def _order_dict(order: models.Order) -> dict:
    return {
        "order_no": order.order_no,
        "machine_code": order.machine_code,
        "items": [
            {"slot_code": i.slot_code, "product_name": i.product_name,
             "qty": i.qty, "unit_price": i.unit_price}
            for i in order.items
        ],
        "amount": order.amount,
        "payment_method": order.payment_method,
        "qr_payload": order.qr_payload,
        "status": order.status,
    }


def _find_slot(db: Session, item: CheckoutItem) -> models.MachineSlot:
    slot = None
    if item.slot_id and str(item.slot_id).isdigit():
        slot = db.query(models.MachineSlot).filter(models.MachineSlot.id == int(item.slot_id)).first()
    if not slot:
        code = item.slot_code or item.slot_id
        if code:
            slot = db.query(models.MachineSlot).filter(models.MachineSlot.slot_code == code).first()
    if not slot:
        raise HTTPException(404, "ไม่พบช่องสินค้าดังกล่าว")
    return slot


@router.post("/checkout")
async def checkout(req: CheckoutRequest, db: Session = Depends(get_db)):
    method = "cash" if req.payment_method == "cash" else "promptpay_qr"
    if not req.items:
        raise HTTPException(400, "ไม่มีสินค้าในตะกร้า")

    # ออเดอร์ค้างเก่า (ตู้รับได้ทีละรายการ) -> ยกเลิก
    for old in db.query(models.Order).filter(models.Order.status == "PENDING").all():
        old.status = "CANCELLED"
    db.commit()

    order = models.Order(
        order_no=f"{MACHINE_CODE}-{datetime.now():%y%m%d%H%M%S}{random.randint(10, 99)}",
        machine_code=MACHINE_CODE,
        payment_method=method,
        status="PENDING",
    )
    total = 0.0
    for it in req.items:
        if it.qty < 1:
            raise HTTPException(400, "จำนวนสินค้าไม่ถูกต้อง")
        slot = _find_slot(db, it)
        if slot.status == "FAULTY":
            raise HTTPException(400, f"ช่อง {slot.slot_code} ขัดข้อง")
        if not slot.product or slot.current_stock < it.qty:
            raise HTTPException(400, f"สินค้าช่อง {slot.slot_code} หมดหรือไม่พอ")
        order.items.append(models.OrderItem(
            slot_code=slot.slot_code,
            product_name=slot.product.name,
            qty=it.qty,
            unit_price=slot.product.price,
        ))
        total += slot.product.price * it.qty
    order.amount = round(total, 2)

    if method == "promptpay_qr":
        order.qr_payload = generate_promptpay_payload(PROMPTPAY_ID, order.amount)

    db.add(order)
    db.commit()
    db.refresh(order)

    # ส่งยอดไปที่ Middleware -> หน้า /cash-simulator จะขึ้นยอดที่ต้องชำระ (เงินสด) หรือปุ่มจ่าย QR
    session.start(order.order_no, order.amount, mode="cash" if method == "cash" else "qr")
    await broadcast_cash_status()
    return _order_dict(order)


# ---------- เงินสด (Flutter poll) ----------
@router.post("/cash/start")
async def cash_start(order_no: str, amount_due: float, db: Session = Depends(get_db)):
    if session.order_no == order_no and session.status != "idle":
        return {"status": "success"}     # checkout เริ่ม session ให้แล้ว
    order = db.query(models.Order).filter(models.Order.order_no == order_no).first()
    if not order or order.status != "PENDING":
        raise HTTPException(404, "ไม่พบออเดอร์ที่รอชำระ")
    session.start(order_no, order.amount, mode="cash")
    await broadcast_cash_status()
    return {"status": "success"}


@router.get("/cash/status")
async def cash_status(db: Session = Depends(get_db)):
    order_status = ""
    if session.order_no:
        o = db.query(models.Order).filter(models.Order.order_no == session.order_no).first()
        order_status = o.status if o else ""
    return {
        "is_active": session.status != "idle",
        "order_no": session.order_no,
        "order_status": order_status,
        "amount_due": session.amount_due,
        "amount_inserted": session.amount_inserted,
        "change_due": session.change,
        "is_completed": session.is_completed,
    }


@router.post("/cash/complete")
async def cash_complete(order_no: str, db: Session = Depends(get_db)):
    order = db.query(models.Order).filter(models.Order.order_no == order_no).first()
    if not order:
        raise HTTPException(404, "ไม่พบออเดอร์")
    if order.payment_method != "cash":
        raise HTTPException(400, "ออเดอร์นี้ไม่ใช่เงินสด")
    if order.status != "PAID":
        if session.order_no != order_no or session.amount_inserted < order.amount:
            raise HTTPException(400, "ยอดเงินยังไม่ครบ")
        try:
            if not finalize_paid(db, order):
                raise HTTPException(400, "ออเดอร์ถูกยกเลิกแล้ว")
        except PaymentError as e:
            raise HTTPException(409, str(e))
        session.status = "paid"
        await broadcast_stock(db)
        await broadcast_cash_status()
    return {"status": "PAID", "order_no": order_no, "change": session.change}


# ---------- QR / ทั่วไป ----------
@router.get("/{order_no}/status")
def order_status(order_no: str, db: Session = Depends(get_db)):
    order = db.query(models.Order).filter(models.Order.order_no == order_no).first()
    if not order:
        raise HTTPException(404, "ไม่พบออเดอร์")
    return {"order_no": order.order_no, "status": order.status}


@router.post("/{order_no}/confirm")
def confirm_payment(order_no: str, db: Session = Depends(get_db)):
    """ไม่ยืนยันให้ — จ่ายได้เฉพาะผ่านตัวรับเงิน (cash_simulator) เท่านั้น"""
    order = db.query(models.Order).filter(models.Order.order_no == order_no).first()
    if not order:
        raise HTTPException(404, "ไม่พบออเดอร์")
    return {"status": order.status, "orderNo": order_no}


@router.post("/{order_no}/cancel")
async def cancel_order(order_no: str, db: Session = Depends(get_db)):
    order = db.query(models.Order).filter(models.Order.order_no == order_no).first()
    if not order:
        raise HTTPException(404, "ไม่พบออเดอร์")
    if order.status == "PENDING":
        order.status = "CANCELLED"
        db.commit()
    if session.order_no == order_no and session.status == "waiting":
        session.reset()
        await broadcast_cash_status()
    return {"status": order.status}
