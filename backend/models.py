from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from datetime import datetime, timezone
from database import Base

class Product(Base):
    __tablename__ = "products"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    category = Column(String)
    price = Column(Float)
    image_url = Column(String, default="")  # เก็บ URL รูปภาพ
    description = Column(Text, default="")

    slots = relationship("MachineSlot", back_populates="product")

class MachineSlot(Base):
    __tablename__ = "machine_slots"

    id = Column(Integer, primary_key=True, index=True)
    slot_code = Column(String, unique=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"), nullable=True)
    current_stock = Column(Integer, default=0)
    capacity = Column(Integer, default=15)
    status = Column(String, default="NORMAL")

    product = relationship("Product", back_populates="slots")

class Order(Base):
    __tablename__ = "orders"

    id = Column(Integer, primary_key=True, index=True)
    order_no = Column(String, unique=True, index=True)
    total_amount = Column(Float, default=0.0)
    payment_method = Column(String)  # CASH, PROMPTPAY
    status = Column(String, default="PENDING")  # PENDING, PAID, CANCELLED
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    items = relationship("OrderItem", back_populates="order")
    payments = relationship("Payment", back_populates="order")

class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"))
    product_id = Column(Integer, ForeignKey("products.id"))
    slot_code = Column(String)
    quantity = Column(Integer, default=1)
    unit_price = Column(Float)

    order = relationship("Order", back_populates="items")

class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"))
    amount = Column(Float)
    status = Column(String, default="PENDING")
    transaction_ref = Column(String, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))

    order = relationship("Order", back_populates="payments")