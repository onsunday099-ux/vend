@echo off
echo Starting Vending Machine System...
echo  - Backend + Cash Middleware : http://127.0.0.1:8000
echo  - Cash Simulator (ตัวรับเงิน) : http://127.0.0.1:8000/cash-simulator
echo  - Restock                    : http://127.0.0.1:8000/restock
uvicorn main:app --reload --port 8000
pause
