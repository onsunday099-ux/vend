import os

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DATABASE_URL = "sqlite:///./vending.db"
PROMPTPAY_ID = os.getenv("PROMPTPAY_ID", "0812345678")
MACHINE_CODE = os.getenv("MACHINE_CODE", "VM-01")  #รหัสตู้
