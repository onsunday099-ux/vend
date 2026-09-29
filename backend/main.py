import os
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.responses import HTMLResponse
from fastapi.middleware.cors import CORSMiddleware

from database import ensure_schema
from middleware.cash_middleware import router as cash_router
from routers.orders import router as orders_router
from routers.slots import router as slots_router
from routers.stock_ws import router as stock_ws_router


@asynccontextmanager
async def lifespan(app: FastAPI):
    ensure_schema()
    yield


app = FastAPI(lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(slots_router)      # /api/slots
app.include_router(orders_router)     # /api/orders/...
app.include_router(cash_router)       # /api/cash/... + ws /api/cash/ws
app.include_router(stock_ws_router)   # ws /ws/stock


def _page(*parts) -> str:
    with open(os.path.join(os.path.dirname(__file__), *parts), "r", encoding="utf-8") as f:
        return f.read()


@app.get("/", response_class=HTMLResponse)
async def get_index():
    return _page("index.html")


@app.get("/shop", response_class=HTMLResponse)
async def get_shop():
    return _page("shop.html")


@app.get("/cash-simulator", response_class=HTMLResponse)
async def get_cash_simulator():
    return _page("middleware", "cash_simulator.html")


@app.get("/restock", response_class=HTMLResponse)
async def get_restock():
    return _page("restock.html")
