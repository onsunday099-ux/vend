import json
import logging
from typing import Dict, List, Optional
from fastapi import APIRouter, WebSocket, WebSocketDisconnect
from pydantic import BaseModel

logger = logging.getLogger("CashMiddleware")
router = APIRouter(prefix="/api/cash", tags=["Cash Middleware"])

# จัดเก็บสถานะเซสชันการรับเงินสดปัจจุบัน
class CashSessionState:
    def __init__(self):
        self.is_active = False
        self.amount_due = 0.0
        self.amount_inserted = 0.0
        self.change = 0.0
        self.slot_codes: List[str] = []

    def start(self, amount_due: float, slot_codes: List[str] = []):
        self.is_active = True
        self.amount_due = float(amount_due)
        self.amount_inserted = 0.0
        self.change = 0.0
        self.slot_codes = slot_codes

    def insert(self, amount: float):
        if not self.is_active:
            return False
        self.amount_inserted = round(self.amount_inserted + amount, 2)
        if self.amount_inserted >= self.amount_due:
            self.change = round(self.amount_inserted - self.amount_due, 2)
        return True

    def reset(self):
        self.is_active = False
        self.amount_due = 0.0
        self.amount_inserted = 0.0
        self.change = 0.0
        self.slot_codes = []

    def to_dict(self):
        return {
            "isActive": self.is_active,
            "amountDue": self.amount_due,
            "amountInserted": self.amount_inserted,
            "change": self.change,
            "isCompleted": self.is_active and (self.amount_inserted >= self.amount_due),
        }

session = CashSessionState()
active_websockets: List[WebSocket] = []

async def broadcast_cash_status():
    """ส่งข้อมูลสถานะเงินสดไปยังทุก Client (ทั้ง Flutter และ Simulator)"""
    payload = json.dumps({"type": "cash_update", "data": session.to_dict()})
    for ws in active_websockets[:]:
        try:
            await ws.send_text(payload)
        except Exception:
            active_websockets.remove(ws)

# WebSocket สำหรับรับ-ส่งข้อมูล Real-time
@router.websocket("/ws")
async def cash_websocket(websocket: WebSocket):
    await websocket.accept()
    active_websockets.append(websocket)
    # ส่งสถานะปัจจุบันให้ทันทีที่ต่อติด
    await websocket.send_text(json.dumps({"type": "cash_update", "data": session.to_dict()}))
    try:
        while True:
            raw_data = await websocket.receive_text()
            data = json.loads(raw_data)
            action = data.get("action")

            if action == "insert_cash":
                amount = float(data.get("amount", 0))
                session.insert(amount)
                await broadcast_cash_status()

            elif action == "cancel_session":
                session.reset()
                await broadcast_cash_status()

    except WebSocketDisconnect:
        if websocket in active_websockets:
            active_websockets.remove(websocket)

# REST API สำรองสำหรับ Flutter เรียกสั่งเปิดเซสชัน
class StartSessionDTO(BaseModel):
    amount_due: float
    slot_codes: Optional[List[str]] = []

@router.post("/session/start")
async def start_session(dto: StartSessionDTO):
    session.start(dto.amount_due, dto.slot_codes)
    await broadcast_cash_status()
    logger.info(f"Cash session started: Due ฿{dto.amount_due}")
    return {"status": "success", "data": session.to_dict()}

@router.post("/session/cancel")
async def cancel_session():
    session.reset()
    await broadcast_cash_status()
    return {"status": "cancelled"}

@router.get("/status")
async def get_status():
    return session.to_dict()