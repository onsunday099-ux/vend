from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional
from sqlalchemy.orm import Session
from database import get_db
import models

router = APIRouter(prefix="/api/orders", tags=["orders"])

class CheckoutRequest(BaseModel):
    slot_code: str
    payment_method: str  # "cash" หรือ "qr"
    inserted_amount: Optional[float] = 0.0  # จำนวนเงินที่หยอดเข้ามา

class CheckoutResponse(BaseModel):
    status: str
    message: str
    slot_code: str
    price: float
    inserted_amount: float
    change_amount: float
    order_id: Optional[int] = None

@router.post("/checkout", response_model=CheckoutResponse)
def process_checkout(req: CheckoutRequest, db: Session = Depends(get_db)):
    # 1. ตรวจสอบช่องสินค้า
    slot = db.query(models.MachineSlot).filter(models.MachineSlot.slot_code == req.slot_code).first()
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบช่องสินค้าดังกล่าว")
    
    if slot.current_stock <= 0:
        raise HTTPException(status_code=400, detail="สินค้าในช่องนี้หมดแล้ว")

    product = slot.product
    if not product:
        raise HTTPException(status_code=404, detail="ไม่พบข้อมูลสินค้า")

    price = float(product.price)

    # 2. กรณีเลือกชำระด้วยเงินสด (Cash)
    if req.payment_method == "cash":
        if req.inserted_amount < price:
            raise HTTPException(
                status_code=400, 
                detail=f"ยอดเงินไม่เพียงพอ (ต้องการ {price} บาท แต่ได้รับ {req.inserted_amount} บาท)"
            )
        
        change = round(req.inserted_amount - price, 2)

        # ตัดสต็อกสินค้า
        slot.current_stock -= 1
        
        # บันทึก Order
        new_order = models.Order(
            machine_code=slot.machine_code,
            slot_id=slot.id,
            product_id=product.id,
            amount=price,
            status="completed"
        )
        db.add(new_order)
        db.commit()
        db.refresh(new_order)

        return CheckoutResponse(
            status="success",
            message="ชำระเงินสดสำเร็จ และปล่อยสินค้าเรียบร้อย",
            slot_code=slot.slot_code,
            price=price,
            inserted_amount=req.inserted_amount,
            change_amount=change,
            order_id=new_order.id
        )

    # 3. กรณีเลือกชำระด้วย QR Code
    elif req.payment_method == "qr":
        # ตัดสต็อกและบันทึกออเดอร์เมื่อยืนยันชำระเสร็จ
        slot.current_stock -= 1
        new_order = models.Order(
            machine_code=slot.machine_code,
            slot_id=slot.id,
            product_id=product.id,
            amount=price,
            status="completed"
        )
        db.add(new_order)
        db.commit()
        db.refresh(new_order)

        return CheckoutResponse(
            status="success",
            message="ชำระเงินผ่าน QR สำเร็จ และปล่อยสินค้าเรียบร้อย",
            slot_code=slot.slot_code,
            price=price,
            inserted_amount=price,
            change_amount=0.0,
            order_id=new_order.id
        )

    else:
        raise HTTPException(status_code=400, detail="รูปแบบการชำระเงินไม่ถูกต้อง")