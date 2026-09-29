from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import declarative_base, sessionmaker

from config import DATABASE_URL

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
Base = declarative_base()


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


def ensure_schema():
    """สร้างตาราง และรีเซ็ตตารางออเดอร์ถ้าเป็นโครงสร้างเก่า (vending.db เดิมใน repo)"""
    import models  # noqa: F401  (ให้ Base รู้จักทุกตาราง)

    insp = inspect(engine)
    if insp.has_table("orders"):
        cols = {c["name"] for c in insp.get_columns("orders")}
        if "qr_payload" not in cols or "amount" not in cols:
            with engine.begin() as conn:
                for t in ("payments", "order_items", "orders"):
                    conn.execute(text(f"DROP TABLE IF EXISTS {t}"))
    Base.metadata.create_all(bind=engine)
