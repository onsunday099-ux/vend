"""
Real Hardware Machine Controller & Cash Middleware
รองรับทั้งฮาร์ดแวร์จริง (Serial / GPIO) และ Fallback เป็น Simulation Mode
"""
import asyncio
import json
import logging
import os
from typing import Dict, Optional
import httpx
import uvicorn
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("MachineController")

# ตรวจสอบการรองรับ Hardware Libraries
try:
    import serial
    HAS_SERIAL = True
except ImportError:
    HAS_SERIAL = False

try:
    import RPi.GPIO as GPIO
    HAS_GPIO = True
except ImportError:
    HAS_GPIO = False

app = FastAPI(title="Vending Machine Controller Middleware")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BACKEND_API_URL = os.getenv("BACKEND_API_URL", "http://127.0.0.1:8000")
SERIAL_PORT = os.getenv("CASH_SERIAL_PORT", "/dev/ttyUSB0")
BAUD_RATE = 9600

# กำหนดขา GPIO จำลองสำหรับบอร์ด Raspberry Pi (ปรับตามวงจรจริง)
SLOT_GPIO_MAP = {
    "A1": 17,
    "A2": 27,
    "A3": 22,
    "B1": 23,
    "B2": 24,
    "B3": 25,
}
DROP_SENSOR_PIN = 18

class HardwareManager:
    def __init__(self):
        self.serial_conn = None
        self.hardware_mode = False
        self.init_hardware()

    def init_hardware(self):
        if HAS_GPIO:
            try:
                GPIO.setmode(GPIO.BCM)
                GPIO.setwarnings(False)
                for pin in SLOT_GPIO_MAP.values():
                    GPIO.setup(pin, GPIO.OUT, initial=GPIO.LOW)
                GPIO.setup(DROP_SENSOR_PIN, GPIO.IN, pull_up_down=GPIO.PUD_UP)
                self.hardware_mode = True
                logger.info("GPIO hardware initialized successfully.")
            except Exception as e:
                logger.warning(f"Failed to init GPIO: {e}")

        if HAS_SERIAL:
            try:
                self.serial_conn = serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=0.1)
                logger.info(f"Connected to Serial Cash Acceptor on {SERIAL_PORT}")
            except Exception as e:
                logger.warning(f"Serial port not available ({e}). Running in simulation fallback.")

    async def dispense_product(self, slot_code: str, timeout_seconds: float = 5.0) -> bool:
        """
        สั่งหมุนมอเตอร์ช่องสินค้า และรอสัญญาณจาก Drop Sensor ตรวจจับสินค้าตก
        """
        logger.info(f"Dispensing slot: {slot_code}")
        pin = SLOT_GPIO_MAP.get(slot_code)

        if self.hardware_mode and pin:
            try:
                # 1. เริ่มหมุนมอเตอร์
                GPIO.output(pin, GPIO.HIGH)
                
                # 2. รอสัญญาณจาก Drop Sensor (Active LOW เมื่อมีวัตถุตัดลำแสง)
                start_time = asyncio.get_event_loop().time()
                item_dropped = False

                while (asyncio.get_event_loop().time() - start_time) < timeout_seconds:
                    if GPIO.input(DROP_SENSOR_PIN) == GPIO.LOW:
                        item_dropped = True
                        break
                    await asyncio.sleep(0.05)

                # หยุดหมุนมอเตอร์
                GPIO.output(pin, GPIO.LOW)
                return item_dropped
            except Exception as e:
                logger.error(f"Hardware dispense error: {e}")
                if pin:
                    GPIO.output(pin, GPIO.LOW)
                return False
        else:
            # Fallback Simulation: หน่วงเวลาเสมือนมอเตอร์หมุน 1.5 วินาที
            await asyncio.sleep(1.5)
            logger.info(f"[SIMULATION] Dispensed slot {slot_code} successfully.")
            return True

hw = HardwareManager()

class CashSession:
    def __init__(self, session_id: str, order_id: int, amount_due: float, slot_code: str):
        self.session_id = session_id
        self.order_id = order_id
        self.amount_due = amount_due
        self.slot_code = slot_code
        self.amount_inserted = 0.0
        self.is_completed = False

active_sessions: Dict[str, CashSession] = {}
active_connections: list[WebSocket] = []

class CreateSessionRequest(BaseModel):
    session_id: str
    order_id: int
    amount_due: float
    slot_code: str

class InsertCashRequest(BaseModel):
    session_id: str
    amount: float

async def broadcast_event(event_type: str, data: dict):
    message = json.dumps({"type": event_type, "data": data})
    for ws in active_connections[:]:
        try:
            await ws.send_text(message)
        except Exception:
            active_connections.remove(ws)

@app.websocket("/ws/cash")
async def websocket_endpoint(websocket: WebSocket):
    await websocket.accept()
    active_connections.append(websocket)
    try:
        while True:
            await websocket.receive_text()
    except WebSocketDisconnect:
        if websocket in active_connections:
            active_connections.remove(websocket)

@app.post("/api/cash/session/start")
async def start_cash_session(req: CreateSessionRequest):
    session = CashSession(
        session_id=req.session_id,
        order_id=req.order_id,
        amount_due=req.amount_due,
        slot_code=req.slot_code
    )
    active_sessions[req.session_id] = session
    logger.info(f"Started cash session {req.session_id} for order {req.order_id}")
    return {"status": "started", "session_id": req.session_id}

@app.post("/api/cash/insert")
async def insert_cash(req: InsertCashRequest):
    session = active_sessions.get(req.session_id)
    if not session or session.is_completed:
        return {"status": "error", "message": "Invalid or expired session"}

    session.amount_inserted += req.amount
    change = max(0.0, round(session.amount_inserted - session.amount_due, 2))

    await broadcast_event("cash_inserted", {
        "session_id": session.session_id,
        "inserted": session.amount_inserted,
        "due": session.amount_due,
        "change": change
    })

    if session.amount_inserted >= session.amount_due:
        session.is_completed = True
        
        # 1. สั่งจ่ายสินค้าผ่านฮาร์ดแวร์
        await broadcast_event("dispensing_start", {"slot_code": session.slot_code})
        dispensed = await hw.dispense_product(session.slot_code)

        if dispensed:
            # 2. แจ้งยืนยันการชำระเงินและตัดสต็อกกับ Cloud Backend
            try:
                async with httpx.AsyncClient() as client:
                    await client.post(
                        f"{BACKEND_API_URL}/api/orders/{session.order_id}/complete",
                        json={"status": "paid", "change": change}
                    )
            except Exception as e:
                logger.error(f"Failed to update backend order status: {e}")

            await broadcast_event("dispensing_success", {
                "session_id": session.session_id,
                "slot_code": session.slot_code,
                "change": change
            })
        else:
            await broadcast_event("dispensing_failed", {
                "session_id": session.session_id,
                "error": "Item drop sensor timeout / jam"
            })

    return {
        "inserted": session.amount_inserted,
        "due": session.amount_due,
        "completed": session.is_completed
    }

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8001)