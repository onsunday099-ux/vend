from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models import Product, MachineSlot
from schemas import SlotCreate, SlotUpdate

router = APIRouter(prefix="/api/slots", tags=["Slots"])

@router.get("")
def get_slots(db: Session = Depends(get_db)):
    slots = db.query(MachineSlot).all()
    result = []
    for s in slots:
        result.append({
            "slot_id": str(s.id),
            "slot_code": s.slot_code,
            "product_name": s.product.name if s.product else "ว่าง",
            "price": s.product.price if s.product else 0.0,
            "category": s.product.category if s.product else "ทั่วไป",
            "current_stock": s.current_stock,
            "max_capacity": s.capacity,
            "image_url": s.product.image_url if (s.product and s.product.image_url) else "",
            "status": s.status
        })
    return result

@router.put("/{slot_id}")
def update_slot(slot_id: int, data: SlotUpdate, db: Session = Depends(get_db)):
    slot = db.query(MachineSlot).filter(MachineSlot.id == slot_id).first()
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบช่องสินค้านี้")

    slot.current_stock = data.current_stock

    if slot.product:
        slot.product.name = data.product_name
        slot.product.price = data.price
        slot.product.category = data.category
        if data.image_url is not None:
            slot.product.image_url = data.image_url
    else:
        new_prod = Product(
            name=data.product_name,
            price=data.price,
            category=data.category,
            image_url=data.image_url or ""
        )
        db.add(new_prod)
        db.flush()
        slot.product_id = new_prod.id

    db.commit()
    return {"status": "success", "message": "อัปเดตข้อมูลสำเร็จ"}

@router.post("")
def add_slot(data: SlotCreate, db: Session = Depends(get_db)):
    # สร้างรหัส Slot อัตโนมัติ เช่น S1, S2, ...
    count = db.query(MachineSlot).count()
    new_slot_code = f"S{count + 1}"

    product = Product(
        name=data.product_name,
        price=data.price,
        category=data.category,
        image_url=data.image_url or "",
        description=data.description or ""
    )
    db.add(product)
    db.flush()

    slot = MachineSlot(
        slot_code=new_slot_code,
        product_id=product.id,
        current_stock=data.current_stock,
        capacity=data.capacity
    )
    db.add(slot)
    db.commit()
    return {"status": "success", "slot_code": new_slot_code}

@router.delete("/{slot_id}")
def delete_slot(slot_id: int, db: Session = Depends(get_db)):
    slot = db.query(MachineSlot).filter(MachineSlot.id == slot_id).first()
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบช่องสินค้า")
    db.delete(slot)
    db.commit()
    return {"status": "success", "message": "ลบสำเร็จ"}