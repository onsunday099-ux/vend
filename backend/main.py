import os
import re
import uuid
from datetime import datetime
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Depends
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import declarative_base, sessionmaker, Session, relationship

DATABASE_URL = "sqlite:///./vending.db"
PROMPTPAY_ID = os.getenv("PROMPTPAY_ID", "0812345678")

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()

# --- โครงสร้างฐานข้อมูล ---
class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    category = Column(String, nullable=False)
    price = Column(Float, nullable=False)
    image_url = Column(String, default="")

class MachineSlot(Base):
    __tablename__ = "machine_slots"
    id = Column(Integer, primary_key=True, index=True)
    slot_code = Column(String, unique=True, nullable=False)  # รหัสลำดับ 1, 2, 3...
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    stock = Column(Integer, default=0)
    product = relationship("Product")

class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    order_no = Column(String, unique=True, index=True)
    slot_id = Column(Integer, ForeignKey("machine_slots.id"), nullable=False)
    amount = Column(Float, nullable=False)
    status = Column(String, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)
    slot = relationship("MachineSlot")

class Payment(Base):
    __tablename__ = "payments"
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    amount = Column(Float, nullable=False)
    qr_payload = Column(String, nullable=False)
    status = Column(String, default="unpaid")
    paid_at = Column(DateTime, nullable=True)

Base.metadata.create_all(bind=engine)

# --- ตัวสร้าง PromptPay QR ---
def _tlv(tag: str, value: str) -> str:
    return f"{tag}{len(value):02d}{value}"

def _crc16(data: str) -> str:
    crc = 0xFFFF
    for b in data.encode("ascii"):
        crc ^= (b << 8)
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if (crc & 0x8000) else (crc << 1)
            crc &= 0xFFFF
    return f"{crc:04X}"

def generate_promptpay_payload(phone: str, amount: float) -> str:
    digits = re.sub(r"\D", "", phone)
    formatted = "0066" + digits[1:] if len(digits) == 10 and digits.startswith("0") else digits
    merchant = _tlv("00", "A000000677010111") + _tlv("01", formatted)
    data = (
        _tlv("00", "01") + _tlv("01", "12") + _tlv("29", merchant) +
        _tlv("53", "764") + _tlv("54", f"{amount:.2f}") + _tlv("58", "TH") + "6304"
    )
    return data + _crc16(data)

# --- Schemas ---
class SlotCreate(BaseModel):
    product_name: str
    price: float = 20.0
    category: str = "เครื่องดื่ม"
    stock: int = 15

class SlotUpdate(BaseModel):
    product_name: str
    price: float
    category: str
    stock: int

class SlotOut(BaseModel):
    slot_id: int
    slot_code: str
    product_name: str
    category: str
    price: float
    stock: int
    image_url: str

class OrderResponse(BaseModel):
    order_no: str
    slot_code: str
    product_name: str
    amount: float
    qr_payload: str
    status: str

app = FastAPI(title="Vending Cloud Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"]
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


# #testสร้างข้อมูลเริ่มต้น 50 รายการสินค้า
# @app.on_event("startup")
# def seed_data():
#     db = SessionLocal()
#     if db.query(MachineSlot).count() == 0:
#         # รายการเครื่องดื่ม 25 รายการ
#         drinks = [
#             ("ชานมเย็น", 25.0),
#             ("กาแฟโบราณ", 30.0),
#             ("น้ำเปล่า", 10.0),
#             ("ชาเขียวมัทฉะ", 35.0),
#             ("น้ำส้มคั้น", 25.0),
#             ("โกโก้เย็น", 30.0),
#             ("ชาไทยพรีเมียม", 35.0),
#             ("น้ำมะนาวโซดา", 25.0),
#             ("อเมริกาโน่", 35.0),
#             ("นมสดคาราเมล", 30.0),
#             ("น้ำแดงโซดา", 20.0),
#             ("ชาอู่หลง", 25.0),
#             ("น้ำเก๊กฮวย", 20.0),
#             ("ลาเต้เย็น", 35.0),
#             ("ชามะนาว", 25.0),
#             ("มอคค่าเย็น", 40.0),
#             ("ชาเขียวนม", 30.0),
#             ("ชาดำเย็น", 20.0),
#             ("น้ำลิ้นจี่โซดา", 25.0),
#             ("นมชมพู", 25.0),
#             ("คาปูชิโน่", 35.0),
#             ("น้ำแอปเปิ้ล", 25.0),
#             ("ชาพีช", 30.0),
#             ("น้ำองุ่น", 25.0),
#             ("น้ำมะพร้าว", 30.0),
#         ]

#         # รายการของว่าง 25 รายการ
#         snacks = [
#             ("ขนมปังเนยสด", 25.0),
#             ("มันฝรั่งทอดกรอบ", 30.0),
#             ("ช็อกโกแลต", 25.0),
#             ("เวเฟอร์วานิลลา", 20.0),
#             ("คุกกี้ข้าวโอ๊ต", 25.0),
#             ("เยลลี่ผลไม้", 20.0),
#             ("ถั่วรวมมิตร", 25.0),
#             ("สาหร่ายทอดกรอบ", 20.0),
#             ("ป๊อปคอร์นคาราเมล", 30.0),
#             ("บิสกิตเนย", 20.0),
#             ("แครกเกอร์ชีส", 25.0),
#             ("ขนมปังไส้กรอก", 30.0),
#             ("แซนด์วิชทูน่า", 35.0),
#             ("เค้กกล้วยหอม", 25.0),
#             ("โดนัทช็อกโกแลต", 25.0),
#             ("มันหวานอบกรอบ", 25.0),
#             ("ทาโร่กรอบ", 20.0),
#             ("ปลาหมึกอบ", 25.0),
#             ("ถั่วลันเตาอบกรอบ", 20.0),
#             ("พายสับปะรด", 25.0),
#             ("ลูกอมรสมินต์", 15.0),
#             ("บราวนี่กรอบ", 30.0),
#             ("มาการอง", 35.0),
#             ("มาชเมลโล่", 20.0),
#             ("ข้าวโพดอบกรอบ", 20.0),
#         ]

#         # รวมทั้งหมด 50 รายการ (เครื่องดื่ม 1-25, ของว่าง 26-50)
#         all_products = []
#         for name, price in drinks:
#             all_products.append((name, "เครื่องดื่ม", price))
#         for name, price in snacks:
#             all_products.append((name, "ของว่าง", price))

#         # บันทึกลงฐานข้อมูล สต็อกชิ้นละ 15
#         for index, (name, category, price) in enumerate(all_products, start=1):
#             prod = Product(name=name, category=category, price=price, image_url="")
#             db.add(prod)
#             db.commit()
#             db.refresh(prod)

#             db.add(MachineSlot(slot_code=str(index), product_id=prod.id, stock=15))

#         db.commit()
#     db.close()

@app.get("/")
def root():
    return FileResponse("index.html")

@app.get("/restock")
def restock_page():
    return FileResponse("restock.html")

@app.get("/api/slots", response_model=List[SlotOut])
def get_slots(db: Session = Depends(get_db)):
    slots = db.query(MachineSlot).all()
    return [
        SlotOut(
            slot_id=s.id,
            slot_code=s.slot_code,
            product_name=s.product.name,
            category=s.product.category,
            price=s.product.price,
            stock=s.stock,
            image_url=s.product.image_url
        ) for s in slots
    ]

# เพิ่มสินค้าใหม่ (รันหมายเลขให้อัตโนมัติ)
@app.post("/api/slots")
def add_slot(data: SlotCreate, db: Session = Depends(get_db)):
    max_slot = db.query(MachineSlot).count() + 1
    new_code = str(max_slot)

    prod = Product(name=data.product_name, category=data.category, price=data.price, image_url="")
    db.add(prod)
    db.commit()
    db.refresh(prod)

    slot = MachineSlot(slot_code=new_code, product_id=prod.id, stock=data.stock)
    db.add(slot)
    db.commit()
    return {"status": "success", "message": f"เพิ่มรายการสินค้า {data.product_name} เรียบร้อย"}

@app.put("/api/slots/{slot_id}")
def update_slot(slot_id: int, data: SlotUpdate, db: Session = Depends(get_db)):
    slot = db.get(MachineSlot, slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบรายการนี้")
    slot.stock = data.stock
    slot.product.name = data.product_name
    slot.product.price = data.price
    slot.product.category = data.category
    db.commit()
    return {"status": "success", "message": "อัปเดตข้อมูลสำเร็จ"}

@app.delete("/api/slots/{slot_id}")
def delete_slot(slot_id: int, db: Session = Depends(get_db)):
    slot = db.get(MachineSlot, slot_id)
    if not slot:
        raise HTTPException(status_code=404, detail="ไม่พบรายการนี้")
    
    orders = db.query(Order).filter(Order.slot_id == slot_id).all()
    for o in orders:
        db.query(Payment).filter(Payment.order_id == o.id).delete()
    db.query(Order).filter(Order.slot_id == slot_id).delete()
    
    db.delete(slot)
    db.commit()
    return {"status": "success", "message": "ลบรายการสินค้าสำเร็จ"}

@app.post("/api/slots/restock-all")
def restock_all(target_stock: int = 15, db: Session = Depends(get_db)):
    slots = db.query(MachineSlot).all()
    for s in slots:
        s.stock = target_stock
    db.commit()
    return {"status": "success", "message": f"เติมสต็อกทุกรายการเป็น {target_stock} ชิ้นเรียบร้อย"}

@app.post("/api/orders/create/{slot_id}", response_model=OrderResponse)
def create_order(slot_id: int, db: Session = Depends(get_db)):
    slot = db.get(MachineSlot, slot_id)
    if not slot or slot.stock <= 0:
        raise HTTPException(status_code=400, detail="สินค้าหมด")

    order_no = f"ORD-{uuid.uuid4().hex[:8].upper()}"
    order = Order(order_no=order_no, slot_id=slot.id, amount=slot.product.price, status="pending")
    db.add(order)
    db.commit()
    db.refresh(order)

    qr = generate_promptpay_payload(PROMPTPAY_ID, order.amount)
    db.add(Payment(order_id=order.id, amount=order.amount, qr_payload=qr, status="unpaid"))
    db.commit()

    return OrderResponse(
        order_no=order.order_no,
        slot_code=slot.slot_code,
        product_name=slot.product.name,
        amount=order.amount,
        qr_payload=qr,
        status=order.status
    )

@app.post("/api/orders/{order_no}/confirm-pay")
def confirm_payment(order_no: str, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.order_no == order_no).first()
    if not order or order.status != "pending":
        raise HTTPException(status_code=400, detail="สถานะออเดอร์ไม่ถูกต้อง")

    slot = db.get(MachineSlot, order.slot_id)
    if slot.stock > 0:
        slot.stock -= 1
        order.status = "completed"
        db.commit()
        return {"status": "completed", "message": f"จ่ายสินค้า {slot.product.name} สำเร็จ"}
    else:
        order.status = "cancelled"
        db.commit()
        raise HTTPException(status_code=400, detail="สินค้าหมด")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)