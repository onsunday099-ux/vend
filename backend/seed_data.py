from database import SessionLocal, engine, Base
from models import Product, MachineSlot

# 1. สร้างตารางทั้งหมดในฐานข้อมูล
Base.metadata.create_all(bind=engine)

def seed():
    db = SessionLocal()
    
    # ล้างข้อมูลเดิมออกก่อน
    db.query(MachineSlot).delete()
    db.query(Product).delete()

    # รายการสินค้าจำลองพร้อมรูปภาพจริง
    mock_items = [
        {
            "slot": "A1", "name": "น้ำดื่มสิงห์ 600ml", "cat": "เครื่องดื่ม", "price": 10.0, "stock": 7,
            "img": "https://images.unsplash.com/photo-1548839140-29a749e1bc4e?w=300&auto=format&fit=crop"
        },
        {
            "slot": "A2", "name": "โค้ก ออริจินัล 325ml", "cat": "เครื่องดื่ม", "price": 16.0, "stock": 6,
            "img": "https://images.unsplash.com/photo-1622483767028-3f66f32aef97?w=300&auto=format&fit=crop"
        },
        {
            "slot": "A3", "name": "ชาเขียวโออิชิ 380ml", "cat": "เครื่องดื่ม", "price": 20.0, "stock": 5,
            "img": "https://images.unsplash.com/photo-1556881286-fc6915169721?w=300&auto=format&fit=crop"
        },
        {
            "slot": "B1", "name": "เลย์ คลาสสิค 50g", "cat": "ของว่าง", "price": 22.0, "stock": 4,
            "img": "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=300&auto=format&fit=crop"
        },
        {
            "slot": "B2", "name": "คิทแคท 2 Finger", "cat": "ของว่าง", "price": 15.0, "stock": 10,
            "img": "https://images.unsplash.com/photo-1582293041079-7814c2f12063?w=300&auto=format&fit=crop"
        },
        {
            "slot": "B3", "name": "นมสด 200ml", "cat": "เครื่องดื่ม", "price": 13.0, "stock": 8,
            "img": "https://images.unsplash.com/photo-1550583724-b2692b85b150?w=300&auto=format&fit=crop"
        },
    ]

    for item in mock_items:
        prod = Product(
            name=item["name"],
            category=item["cat"],
            price=item["price"],
            image_url=item["img"]
        )
        db.add(prod)
        db.flush()

        slot = MachineSlot(
            slot_code=item["slot"],
            product_id=prod.id,
            current_stock=item["stock"],
            capacity=15
        )
        db.add(slot)

    db.commit()
    db.close()
    print("สร้างตารางและใส่ข้อมูลจำลองพร้อมรูปภาพสำเร็จเรียบร้อย!")

if __name__ == "__main__":
    seed()