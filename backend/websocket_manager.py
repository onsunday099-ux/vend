import json
from typing import List

from fastapi import WebSocket
from sqlalchemy.orm import Session

from config import MACHINE_CODE
from models import MachineSlot


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


def slot_to_dict(s: MachineSlot) -> dict:
    """รูปแบบเดียวกันทั้ง GET /api/slots และ WebSocket /ws/stock"""
    p = s.product
    return {
        "slot_id": str(s.id),
        "slot_code": s.slot_code,
        "machine_code": MACHINE_CODE,
        "product_name": p.name if p else "ว่าง",
        "price": p.price if p else 0.0,
        "category": p.category if p else "ทั่วไป",
        "description": (p.description if p else "") or "",
        "current_stock": s.current_stock,
        "max_capacity": s.capacity,
        "image_url": (p.image_url if p and p.image_url else ""),
        "status": s.status or "NORMAL",
    }


def _slots_payload(db: Session) -> dict:
    slots = db.query(MachineSlot).order_by(MachineSlot.slot_code).all()
    return {"type": "stock_update", "slots": [slot_to_dict(s) for s in slots]}


async def broadcast_stock(db: Session):
    await manager.broadcast_json(_slots_payload(db))
