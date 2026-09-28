from datetime import datetime

from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey
from sqlalchemy.orm import relationship

from config import MACHINE_CODE
from database import Base, engine

# --- โครงสร้างฐานข้อมูล ---
class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, nullable=False)
    category = Column(String, nullable=False)
    price = Column(Float, nullable=False)
    image_url = Column(String, default="")
    description = Column(String, default="")

class MachineSlot(Base):
    __tablename__ = "machine_slots"
    id = Column(Integer, primary_key=True, index=True)
    machine_code = Column(String, nullable=False, default=MACHINE_CODE)
    slot_code = Column(String, unique=True, nullable=False)  # รหัสลำดับ 1, 2, 3...
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    current_stock = Column(Integer, default=0)
    product = relationship("Product")

class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    order_no = Column(String, unique=True, index=True)
    machine_code = Column(String, nullable=False, default=MACHINE_CODE)
    slot_id = Column(Integer, ForeignKey("machine_slots.id"), nullable=True)   # ช่องหลักของออเดอร์ หรือ null เมื่อเป็นตะกร้าหลายรายการ
    product_id = Column(Integer, ForeignKey("products.id"), nullable=True)
    amount = Column(Float, nullable=False)
    status = Column(String, default="pending")
    created_at = Column(DateTime, default=datetime.utcnow)
    slot = relationship("MachineSlot")

class OrderItem(Base):
    """รายการสินค้าย่อยภายในออเดอร์เดียว รองรับตะกร้าที่มีหลายรายการ"""
    __tablename__ = "order_items"
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    slot_id = Column(Integer, ForeignKey("machine_slots.id"), nullable=False)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=False)
    qty = Column(Integer, default=1)
    unit_price = Column(Float, nullable=False)

class Payment(Base):
    __tablename__ = "payments"
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"), nullable=False)
    amount = Column(Float, nullable=False)
    payment_method = Column(String, nullable=False, default="promptpay_qr")  # promptpay_qr | cash
    qr_payload = Column(String, nullable=True)
    status = Column(String, default="unpaid")
    paid_at = Column(DateTime, nullable=True)


Base.metadata.create_all(bind=engine)
