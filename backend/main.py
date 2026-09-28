import os

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.middleware.cors import CORSMiddleware

from config import BASE_DIR
import models  # noqa: F401  (สร้างตารางในฐานข้อมูลตอน import)
from routers import slots, orders, stock_ws

app = FastAPI(title="Vending Cloud Backend")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(slots.router)
app.include_router(orders.router)
app.include_router(stock_ws.router)


@app.get("/")
def root():
    return FileResponse(os.path.join(BASE_DIR, "index.html"))


@app.get("/shop")
def shop_page():
    return FileResponse(os.path.join(BASE_DIR, "shop.html"))


@app.get("/cash-simulator")
def cash_simulator_page():
    return FileResponse(os.path.join(BASE_DIR, "middleware", "cash_simulator.html"))


@app.get("/restock")
def restock_page():
    return FileResponse(os.path.join(BASE_DIR, "restock.html"))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)

