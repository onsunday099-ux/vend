from typing import List, Optional

from pydantic import BaseModel

class SlotCreate(BaseModel):
    product_name: str
    price: float = 20.0
    category: str = "เครื่องดื่ม"
    description: str = ""
    current_stock: int = 15

class SlotUpdate(BaseModel):
    product_name: str
    price: float
    category: str
    description: str = ""
    current_stock: int

class SlotOut(BaseModel):
    slot_id: int
    machine_code: str
    slot_code: str
    product_name: str
    category: str
    price: float
    description: str
    current_stock: int
    image_url: str

class CartLine(BaseModel):
    slot_id: int
    qty: int = 1

class CartCheckout(BaseModel):
    items: List[CartLine]
    payment_method: str = "promptpay_qr"  # promptpay_qr | cash

class OrderItemOut(BaseModel):
    slot_code: str
    product_name: str
    qty: int
    unit_price: float

class OrderResponse(BaseModel):
    order_no: str
    machine_code: str
    items: List[OrderItemOut]
    amount: float
    payment_method: str
    qr_payload: Optional[str] = None
    status: str
