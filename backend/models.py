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
    image_url = Column(String, default="")
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
    machine_code = Column(String, default="")
    amount = Column(Float, default=0.0)
    payment_method = Column(String)          # cash | promptpay_qr
    status = Column(String, default="PENDING")  # PENDING | PAID | CANCELLED
    qr_payload = Column(Text, nullable=True)
    created_at = Column(DateTime, default=lambda: datetime.now(timezone.utc))
    paid_at = Column(DateTime, nullable=True)

    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")


class OrderItem(Base):
    __tablename__ = "order_items"

    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"))
    slot_code = Column(String)
    product_name = Column(String, default="")
    qty = Column(Integer, default=1)
    unit_price = Column(Float, default=0.0)

    order = relationship("Order", back_populates="items")
