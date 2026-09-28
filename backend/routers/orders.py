import httpx
from fastapi import APIRouter, HTTPException

router = APIRouter(prefix="/api/orders", tags=["orders"])
MIDDLEWARE_URL = "http://127.0.0.1:8080/api/middleware/cash"

@router.post("/cash/start")
async def start_cash_session(order_no: str, amount_due: int):
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.post(
                f"{MIDDLEWARE_URL}/session/start",
                json={"order_no": order_no, "amount_due": amount_due}
            )
            return resp.json()
    except Exception as e:
        raise HTTPException(status_code=503, detail=f"Middleware error: {str(e)}")

@router.get("/cash/status")
async def get_cash_status():
    try:
        async with httpx.AsyncClient(timeout=2.0) as client:
            resp = await client.get(f"{MIDDLEWARE_URL}/status")
            return resp.json()
    except Exception:
        return {"is_active": False, "amount_inserted": 0, "amount_due": 0, "change_due": 0, "is_completed": False}

@router.post("/cash/complete")
async def complete_cash_session(order_no: str):
    async with httpx.AsyncClient(timeout=2.0) as client:
        dispense = await client.post(f"{MIDDLEWARE_URL}/dispense")
        return {"status": "SUCCESS", "detail": dispense.json()}