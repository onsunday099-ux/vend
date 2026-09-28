from database import SessionLocal, engine, Base
from models import Slot
from datetime import datetime, timezone

# อัปเดตโครงสร้างตาราง
Base.metadata.create_all(bind=engine)

def seed_slots():
    db = SessionLocal()
    
    # ล้างข้อมูลเดิมในช่องตู้สินค้า
    db.query(Slot).delete()

    # รายการสินค้าจำลอง (พร้อมรูปภาพจริงจาก Unsplash)
    mock_items = [
        Slot(
            slot_id="A1",
            product_name="น้ำดื่มสิงห์ 600ml",
            price=10.0,
            current_stock=7,
            max_capacity=10,
            category="เครื่องดื่ม",
            status="NORMAL",
            image_url="https://images.unsplash.com/photo-1548839140-29a749e1bc4e?w=200&auto=format&fit=crop",
            last_updated=datetime.now(timezone.utc)
        ),
        Slot(
            slot_id="A2",
            product_name="โค้ก ออริจินัล 325ml",
            price=16.0,
            current_stock=6,
            max_capacity=10,
            category="เครื่องดื่ม",
            status="NORMAL",
            image_url="https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=200&auto=format&fit=crop",
            last_updated=datetime.now(timezone.utc)
        ),
        Slot(
            slot_id="A3",
            product_name="ชาเขียวอิชิตัน 420ml",
            price=20.0,
            current_stock=5,
            max_capacity=10,
            category="เครื่องดื่ม",
            status="NORMAL",
            image_url="https://images.unsplash.com/photo-1556881286-fc6915169721?w=200&auto=format&fit=crop",
            last_updated=datetime.now(timezone.utc)
        ),
        Slot(
            slot_id="A4",
            product_name="กาแฟกระป๋อง เบอร์ดี้",
            price=17.0,
            current_stock=8,
            max_capacity=10,
            category="เครื่องดื่ม",
            status="NORMAL",
            image_url="https://images.unsplash.com/photo-1514432324607-a09d9b4aefdd?w=200&auto=format&fit=crop",
            last_updated=datetime.now(timezone.utc)
        ),
        Slot(
            slot_id="B1",
            product_name="เลย์ คลาสสิค 50g",
            price=22.0,
            current_stock=4,
            max_capacity=8,
            category="ขนมขบเคี้ยว",
            status="NORMAL",
            image_url="https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=200&auto=format&fit=crop",
            last_updated=datetime.now(timezone.utc)
        ),
        Slot(
            slot_id="B2",
            product_name="คิทแคท 2 Finger",
            price=15.0,
            current_stock=10,
            max_capacity=10,
            category="ขนมขบเคี้ยว",
            status="NORMAL",
            image_url="https://images.unsplash.com/photo-1582293041079-7814c2f12063?w=200&auto=format&fit=crop",
            last_updated=datetime.now(timezone.utc)
        ),
        Slot(
            slot_id="B3",
            product_name="ช็อกโกแลต เอ็มแอนด์เอ็ม",
            price=25.0,
            current_stock=9,
            max_capacity=10,
            category="ขนมขบเคี้ยว",
            status="NORMAL",
            image_url="https://images.unsplash.com/photo-1581798459219-318e76aecc7b?w=200&auto=format&fit=crop",
            last_updated=datetime.now(timezone.utc)
        ),
        Slot(
            slot_id="B4",
            product_name="นมสดไทย-เดนมาร์ค 200ml",
            price=13.0,
            current_stock=0,  # สินค้าหมดเพื่อทดสอบสถานะปุ่ม
            max_capacity=10,
            category="เครื่องดื่ม",
            status="NORMAL",
            image_url="https://images.unsplash.com/photo-1550583724-b2692b85b150?w=200&auto=format&fit=crop",
            last_updated=datetime.now(timezone.utc)
        ),
    ]

    for item in mock_items:
        db.add(item)

    db.commit()
    db.close()
    print("Seed ข้อมูลจำลองพร้อมรูปภาพสำเร็จ!")

if __name__ == "__main__":
    seed_slots()