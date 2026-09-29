"""Payment Middleware (จำลองตู้รับเงิน) — หน้า /cash-simulator คือ "ตัวรับเงินจริง" ของตู้
   * เงินสด: หยอดเหรียญ/ธนบัตรในหน้า simulator เท่านั้น -> Flutter อ่านยอดผ่าน /api/orders/cash/status
   * QR: กดปุ่ม "จ่ายด้วย QR" ในหน้า simulator -> ออเดอร์เป็น PAID -> Flutter poll เจอแล้วจ่ายสินค้า
   ไม่มีการจ่ายเงินอัตโนมัติจากฝั่งแอปอีกต่อไป
"""
import json
import logging
from typing import List

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from database import SessionLocal
from models import Order
from payment_service import finalize_paid, PaymentError
from websocket_manager import broadcast_stock

logger = logging.getLogger("CashMiddleware")
router = APIRouter(prefix="/api/cash", tags=["Cash Middleware"])

VALID_DENOMINATIONS = {1, 2, 5, 10, 20, 50, 100, 500, 1000}


class CashSessionState:
    def __init__(self):
        self.reset()

    def reset(self):
        self.status = "idle"       # idle | waiting | paid
        self.mode = "cash"         # cash | qr
        self.order_no = ""
        self.amount_due = 0.0
        self.amount_inserted = 0.0
        self.change = 0.0

    def start(self, order_no: str, amount_due: float, mode: str = "cash"):
        self.reset()
        self.status = "waiting"
        self.mode = mode
        self.order_no = order_no
        self.amount_due = float(amount_due)

    def insert(self, amount: float) -> bool:
        if self.status != "waiting" or self.mode != "cash":
            return False
        if int(amount) not in VALID_DENOMINATIONS:
            return False
        if self.amount_inserted >= self.amount_due:   # ครบแล้ว ไม่รับเพิ่ม
            return False
        self.amount_inserted = round(self.amount_inserted + amount, 2)
        if self.amount_inserted >= self.amount_due:
            self.change = round(self.amount_inserted - self.amount_due, 2)
        return True

    @property
    def is_completed(self) -> bool:
        if self.status == "paid":
            return True
        return (self.status == "waiting" and self.mode == "cash"
                and self.amount_due > 0 and self.amount_inserted >= self.amount_due)

    def to_dict(self) -> dict:
        return {
            "isActive": self.status != "idle",
            "status": self.status,
            "mode": self.mode,
            "orderNo": self.order_no,
            "amountDue": self.amount_due,
            "amountInserted": self.amount_inserted,
            "change": self.change,
            "isCompleted": self.is_completed,
        }


session = CashSessionState()
active_websockets: List[WebSocket] = []


async def broadcast_cash_status():
    payload = json.dumps({"type": "cash_update", "data": session.to_dict()})
    for ws in active_websockets[:]:
        try:
            await ws.send_text(payload)
        except Exception:
            if ws in active_websockets:
                active_websockets.remove(ws)


def cancel_pending_order(order_no: str):
    if not order_no:
        return
    db = SessionLocal()
    try:
        order = db.query(Order).filter(Order.order_no == order_no).first()
        if order and order.status == "PENDING":
            order.status = "CANCELLED"
            db.commit()
    finally:
        db.close()


async def pay_qr_now() -> bool:
    """กดจ่าย QR ใน simulator -> ตัดสต็อก + ออเดอร์ PAID"""
    if session.status != "waiting" or session.mode != "qr":
        return False
    db = SessionLocal()
    try:
        order = db.query(Order).filter(Order.order_no == session.order_no).first()
        if not order:
            return False
        try:
            ok = finalize_paid(db, order)
        except PaymentError as e:
            logger.warning(str(e))
            return False
        if not ok:
            return False
        session.status = "paid"
        await broadcast_stock(db)
    finally:
        db.close()
    await broadcast_cash_status()
    return True


@router.websocket("/ws")
async def cash_websocket(websocket: WebSocket):
    await websocket.accept()
    active_websockets.append(websocket)
    await websocket.send_text(json.dumps({"type": "cash_update", "data": session.to_dict()}))
    try:
        while True:
            data = json.loads(await websocket.receive_text())
            action = data.get("action")

            if action == "insert_cash":
                session.insert(float(data.get("amount", 0)))
                await broadcast_cash_status()

            elif action == "pay_qr":
                await pay_qr_now()

            elif action == "cancel_session":
                if session.status == "waiting":
                    cancel_pending_order(session.order_no)
                session.reset()
                await broadcast_cash_status()

    except WebSocketDisconnect:
        pass
    finally:
        if websocket in active_websockets:
            active_websockets.remove(websocket)


@router.get("/status")
async def get_status():
    return session.to_dict()
