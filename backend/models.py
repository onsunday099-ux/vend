from sqlalchemy import Column, Integer, String, Float, DateTime
from datetime import datetime, timezone
from database import Base

class Slot(Base):
    __tablename__ = "slots"

    slot_id = Column(String, primary_key=True, index=True)
    product_name = Column(String)
    price = Column(Float)
    current_stock = Column(Integer, default=0)
    max_capacity = Column(Integer, default=10)
    category = Column(String)
    status = Column(String, default="NORMAL")
    image_url = Column(String, nullable=True)  # <-- เพิ่มฟิลด์เก็บ URL รูปภาพ
    last_updated = Column(DateTime, default=lambda: datetime.now(timezone.utc))

class Order(Base):
    __tablename__ = "orders"

    order_id = Column(String, primary_key=True, index=True)
    slot_id = Column(String)
    product_name = Column(String)
    price = Column(Float)
    quantity = Column(Integer, default=1)
    total_amount = Column(Float)
    payment_method = Column(String)  # PROMPTPAY, CASH, CREDIT_CARD
    status = Column(String, default="SUCCESS")  # SUCCESS, FAILED, PENDING
    timestamp = Column(DateTime, default=lambda: datetime.now(timezone.utc))