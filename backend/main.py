import os
from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware
from middleware.cash_middleware import router as cash_router

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ผูก Cash Router (จะทำให้มี /api/cash/... และ ws://127.0.0.1:8000/api/cash/ws)
app.include_router(cash_router)

# เสิร์ฟหน้า cash-simulator
@app.get("/cash-simulator", response_class=HTMLResponse)
async def get_cash_simulator():
    html_path = os.path.join(os.path.dirname(__file__), "middleware", "cash_simulator.html")
    with open(html_path, "r", encoding="utf-8") as f:
        return f.read()