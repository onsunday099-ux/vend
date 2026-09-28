import json

from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from database import SessionLocal
from websocket_manager import manager, _slots_payload

router = APIRouter()


@router.websocket("/ws/stock")
async def ws_stock(websocket: WebSocket):
    """ไคลเอนต์ (แอป Flutter / หน้าเติมสินค้า) เชื่อมต่อเข้ามาเพื่อรับการอัปเดตสต็อกแบบพุชทันทีที่มีการเปลี่ยนแปลง
    (แทนที่การเรียก GET /api/slots ซ้ำ ๆ)"""
    await manager.connect(websocket)
    db = SessionLocal()
    try:
        # ส่งสถานะปัจจุบันทันทีที่เชื่อมต่อสำเร็จ
        await websocket.send_text(json.dumps(_slots_payload(db), ensure_ascii=False))
        while True:
            # เก็บ connection ไว้แบบ passive รอรับ broadcast; ยังฟังข้อความจากฝั่ง client ไว้เผื่ออนาคต (เช่น ping)
            await websocket.receive_text()
    except WebSocketDisconnect:
        manager.disconnect(websocket)
    finally:
        db.close()
