import json
from typing import List

from fastapi import WebSocket
from sqlalchemy.orm import Session

from models import MachineSlot

# --- ระบบแจ้งเตือนสต็อกแบบเรียลไทม์ผ่าน WebSocket ---
class ConnectionManager:
    def __init__(self):
        self.active: List[WebSocket] = []

    async def connect(self, ws: WebSocket):
        await ws.accept()
        self.active.append(ws)

    def disconnect(self, ws: WebSocket):
        if ws in self.active:
            self.active.remove(ws)

    async def broadcast_json(self, payload: dict):
        dead = []
        for ws in self.active:
            try:
                await ws.send_text(json.dumps(payload, ensure_ascii=False))
            except Exception:
                dead.append(ws)
        for ws in dead:
            self.disconnect(ws)

manager = ConnectionManager()

def _slots_payload(db: Session) -> dict:
    slots = db.query(MachineSlot).all()
    return {
        "type": "stock_update",
        "slots": [
            {
                "slot_id": s.id,
                "machine_code": s.machine_code,
                "slot_code": s.slot_code,
                "product_name": s.product.name,
                "category": s.product.category,
                "price": s.product.price,
                "description": s.product.description,
                "current_stock": s.current_stock,
                "image_url": s.product.image_url,
            }
            for s in slots
        ],
    }

async def broadcast_stock(db: Session):
    await manager.broadcast_json(_slots_payload(db))






