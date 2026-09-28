import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="Cash Middleware (No Tube Inventory)")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class CashSession:
    def __init__(self):
        self.is_active: bool = False
        self.order_no: str = ""
        self.amount_due: int = 0
        self.amount_inserted: int = 0

    def start(self, order_no: str, amount_due: int):
        self.is_active = True
        self.order_no = order_no
        self.amount_due = amount_due
        self.amount_inserted = 0

    def insert(self, amount: int) -> int:
        if not self.is_active:
            raise ValueError("ไม่มี Session ที่เปิดอยู่")
        self.amount_inserted += amount
        return self.amount_inserted

    def get_change(self) -> int:
        if not self.is_active or self.amount_inserted < self.amount_due:
            return 0
        return self.amount_inserted - self.amount_due

    def reset(self):
        self.is_active = False
        self.order_no = ""
        self.amount_due = 0
        self.amount_inserted = 0

session = CashSession()

class StartRequest(BaseModel):
    order_no: str
    amount_due: int

class InsertRequest(BaseModel):
    amount: int

@app.post("/api/middleware/cash/session/start")
def start_session(req: StartRequest):
    session.start(req.order_no, req.amount_due)
    return {"status": "STARTED", "order_no": session.order_no, "amount_due": session.amount_due}

@app.post("/api/middleware/cash/insert")
def insert_money(req: InsertRequest):
    try:
        total = session.insert(req.amount)
        change = session.get_change()
        return {
            "status": "INSERTED",
            "inserted": req.amount,
            "total_inserted": total,
            "amount_due": session.amount_due,
            "change_due": change,
            "is_completed": total >= session.amount_due,
        }
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/api/middleware/cash/status")
def get_status():
    return {
        "is_active": session.is_active,
        "order_no": session.order_no,
        "amount_due": session.amount_due,
        "amount_inserted": session.amount_inserted,
        "change_due": session.get_change(),
        "is_completed": (session.amount_inserted >= session.amount_due) if session.is_active else False,
    }

@app.post("/api/middleware/cash/dispense")
def dispense_change():
    """ทอนเงินตามยอดจริงโดยไม่ต้องตรวจ Tube"""
    change = session.get_change()
    session.reset()
    return {"status": "SUCCESS", "dispensed_change": change}

@app.post("/api/middleware/cash/cancel")
def cancel_session():
    refund = session.amount_inserted
    session.reset()
    return {"status": "CANCELLED", "refund_amount": refund}

if __name__ == "__main__":
    uvicorn.run(app, host="127.0.0.1", port=8080)