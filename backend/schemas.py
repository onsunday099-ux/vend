from pydantic import BaseModel, ConfigDict
from typing import Optional, List
from datetime import datetime

# --- SLOT SCHEMAS ---
class SlotCreate(BaseModel):
    product_name: str
    price: float
    category: str
    current_stock: int
    image_url: Optional[str] = ""  
    description: Optional[str] = ""

class SlotCreate(SlotBase):
    slot_id: str

class SlotUpdate(BaseModel):
    product_name: str
    price: float
    category: str
    current_stock: int
    image_url: Optional[str] = "" 
    description: Optional[str] = ""

class SlotRestock(BaseModel):
    quantity: int

class SlotResponse(SlotBase):
    slot_id: str
    last_updated: datetime

    model_config = ConfigDict(from_attributes=True)


# --- ORDER SCHEMAS ---
class OrderItem(BaseModel):
    slot_id: str
    quantity: int

class OrderCreate(BaseModel):
    items: List[OrderItem]
    payment_method: str  # PROMPTPAY, CASH, CREDIT_CARD

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