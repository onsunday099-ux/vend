from typing import List

from fastapi import APIRouter, HTTPException, Depends
from sqlalchemy.orm import Session

from config import MACHINE_CODE
from database import get_db
from models import Product, MachineSlot, Order, OrderItem, Payment
from schemas import SlotCreate, SlotUpdate, SlotOut
from websocket_manager import broadcast_stock

router = APIRouter()


@router.get("/api/slots", response_model=List[SlotOut])
def get_slots(db: Session = Depends(get_db)):
    slots = db.query(MachineSlot).all()
    return [
        SlotOut(
            slot_id=s.id,
            machine_code=s.machine_code,
            slot_code=s.slot_code,
            product_name=s.product.name,
            category=s.product.category,
            price=s.product.price,
            description=s.product.description or "",
            current_stock=s.current_stock,
            image_url=s.product.image_url
        ) for s in slots
    ]

# เพิ่มสินค้าใหม่ (รันหมายเลขให้อัตโนมัติ)
@router.post("/api/slots")
async def add_slot(data: SlotCreate, db: Session = Depends(get_db)):
    max_slot = db.query(MachineSlot).count() + 1
    new_code = str(max_slot)

    prod = Product(
        name=data.product_name,
        category=data.category,
        price=data.price,
        image_url="",
        description=data.description,
    )
    db.add(prod)
    db.commit()
    db.refresh(prod)

    slot = MachineSlot(machine_code=MACHINE_CODE, slot_code=new_code, product_id=prod.id, current_stock=data.current_stock)
    db.add(slot)
    db.commit()
    await broadcast_stock(db)
    return {"status": "success", "message": f"เพิ่มรายการสินค้า {data.product_name} เรียบร้อย"}

@router.put("/api/slots/{slot_id}")
async def update_slot(slot_id: int, data: SlotUpdate, db: Session = Depends(get_db)):
    slot = db.get(MachineSlot, slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบรายการนี้")
    slot.current_stock = data.current_stock
    slot.product.name = data.product_name
    slot.product.price = data.price
    slot.product.category = data.category
    slot.product.description = data.description
    db.commit()
    await broadcast_stock(db)
    return {"status": "success", "message": "อัปเดตข้อมูลสำเร็จ"}

@router.delete("/api/slots/{slot_id}")
async def delete_slot(slot_id: int, db: Session = Depends(get_db)):
    slot = db.get(MachineSlot, slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบรายการนี้")

    orders = db.query(Order).filter(Order.slot_id == slot_id).all()
    for o in orders:
        db.query(Payment).filter(Payment.order_id == o.id).delete()
        db.query(OrderItem).filter(OrderItem.order_id == o.id).delete()
    db.query(OrderItem).filter(OrderItem.slot_id == slot_id).delete()
    db.query(Order).filter(Order.slot_id == slot_id).delete()

    db.delete(slot)
    db.commit()
    await broadcast_stock(db)
    return {"status": "success", "message": "ลบรายการสินค้าสำเร็จ"}

@router.post("/api/slots/restock-all")
async def restock_all(target_stock: int = 15, db: Session = Depends(get_db)):
    slots = db.query(MachineSlot).all()
    for s in slots:
        s.current_stock = target_stock
    db.commit()
    await broadcast_stock(db)
    return {"status": "success", "message": f"เติมสต็อกทุกรายการเป็น {target_stock} ชิ้นเรียบร้อย"}
