@echo off
echo Starting Vending Machine System...

REM สั่งรัน Cash Middleware ในหน้าต่างใหม่ 
start "Cash Middleware" cmd /c "cd middleware && python cash_middleware.py"

REM สั่งรัน Backend 
uvicorn main:app --reload --port 8000

pause