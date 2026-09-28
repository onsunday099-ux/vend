from fastapi import WebSocket
from typing import Dict, List

class ConnectionManager:
    def __init__(self):
        self.active_connections: Dict[str, List[WebSocket]] = {}

    async def connect(self, order_id: str, websocket: WebSocket):
        await websocket.accept()
        if order_id not in self.active_connections:
            self.active_connections[order_id] = []
        self.active_connections[order_id].append(websocket)

    def disconnect(self, order_id: str, websocket: WebSocket):
        if order_id in self.active_connections:
            self.active_connections[order_id].remove(websocket)

    async def broadcast_status(self, order_id: str, status: str, extra: dict = None):
        if order_id in self.active_connections:
            payload = {"order_id": order_id, "status": status, **(extra or {})}
            for ws in self.active_connections[order_id]:
                await ws.send_json(payload)

ws_manager = ConnectionManager()