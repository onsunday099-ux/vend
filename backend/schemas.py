from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime

# --- 1. ประกาศ SlotBase ก่อนเป็นตัวแรก ---
class SlotBase(BaseModel):
    product_name: str
    price: float
    current_stock: int
    max_capacity: int = 15
    category: str = "ทั่วไป"
    status: str = "NORMAL"
    image_url: Optional[str] = ""

# --- 2. คลาสที่สืบทอดจาก SlotBase ---
class SlotCreate(SlotBase):
    slot_id: Optional[str] = None
    description: Optional[str] = ""

class SlotUpdate(BaseModel):
    product_name: Optional[str] = None
    price: Optional[float] = None
    current_stock: Optional[int] = None
    max_capacity: Optional[int] = None
    category: Optional[str] = None
    status: Optional[str] = None
    image_url: Optional[str] = None
    description: Optional[str] = ""

class SlotRestock(BaseModel):
    quantity: int

class SlotResponse(SlotBase):
    slot_id: str
    last_updated: Optional[datetime] = None

    model_config = ConfigDict(from_attributes=True)


# --- 3. คลาสฝั่งคำสั่งซื้อ (Orders) ---
class OrderItem(BaseModel):
    slot_id: str
    quantity: int

class OrderCreate(BaseModel):
    items: List[OrderItem]
    payment_method: str  # CASH, PROMPTPAY, CREDIT_CARD

class SingleOrderResponse(BaseModel):
    order_id: str
    slot_id: str
    product_name: str
    price: float
    quantity: int
    total_amount: float
    payment_method: str
    status: str
    timestamp: datetime

    model_config = ConfigDict(from_attributes=True)

class OrderResponse(BaseModel):
    message: str
    orders: List[SingleOrderResponse]
    grand_total: float