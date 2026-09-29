from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from typing import List
from database import get_db
from models import Product, MachineSlot
from schemas import SlotCreate, SlotUpdate
from websocket_manager import slot_to_dict, broadcast_stock

router = APIRouter(prefix="/api/slots", tags=["Slots"])

@router.get("")
def get_slots(db: Session = Depends(get_db)):
    slots = db.query(MachineSlot).order_by(MachineSlot.slot_code).all()
    return [slot_to_dict(s) for s in slots]

@router.put("/{slot_id}")
async def update_slot(slot_id: int, data: SlotUpdate, db: Session = Depends(get_db)):
    slot = db.query(MachineSlot).filter(MachineSlot.id == slot_id).first()
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบช่องสินค้านี้")

    if data.current_stock is not None:
        slot.current_stock = data.current_stock
    if data.max_capacity is not None:
        slot.capacity = data.max_capacity
    if data.status is not None:
        slot.status = data.status

    if slot.product:
        if data.product_name is not None:
            slot.product.name = data.product_name
        if data.price is not None:
            slot.product.price = data.price
        if data.category is not None:
            slot.product.category = data.category
        if data.image_url is not None:
            slot.product.image_url = data.image_url
    else:
        new_prod = Product(
            name=data.product_name or "สินค้าใหม่",
            price=data.price or 0.0,
            category=data.category or "ทั่วไป",
            image_url=data.image_url or ""
        )
        db.add(new_prod)
        db.flush()
        slot.product_id = new_prod.id

    db.commit()
    await broadcast_stock(db)
    return {"status": "success", "message": "อัปเดตข้อมูลสำเร็จ"}

@router.post("")
async def add_slot(data: SlotCreate, db: Session = Depends(get_db)):
    # สร้างรหัส Slot อัตโนมัติ เช่น S1, S2, ...
    n = db.query(MachineSlot).count() + 1
    while db.query(MachineSlot).filter(MachineSlot.slot_code == f"S{n}").first():
        n += 1
    new_slot_code = f"S{n}"

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
        capacity=data.max_capacity
    )
    db.add(slot)
    db.commit()
    await broadcast_stock(db)
    return {"status": "success", "slot_code": new_slot_code}

@router.delete("/{slot_id}")
async def delete_slot(slot_id: int, db: Session = Depends(get_db)):
    slot = db.query(MachineSlot).filter(MachineSlot.id == slot_id).first()
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบช่องสินค้า")
    db.delete(slot)
    db.commit()
    await broadcast_stock(db)
    return {"status": "success", "message": "ลบสำเร็จ"}