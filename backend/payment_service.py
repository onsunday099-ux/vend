from datetime import datetime, timezone

from sqlalchemy.orm import Session

from models import Order, MachineSlot


class PaymentError(Exception):
    pass


def finalize_paid(db: Session, order: Order) -> bool:
    """ยืนยันว่าจ่ายแล้ว: ตัดสต็อก + เปลี่ยนสถานะเป็น PAID (ทำครั้งเดียว)
    คืน True ถ้า PAID แล้ว (รวมกรณีเคยจ่ายแล้ว), False ถ้าออเดอร์ถูกยกเลิก"""
    if order.status == "PAID":
        return True
    if order.status != "PENDING":
        return False

    for it in order.items:
        slot = db.query(MachineSlot).filter(MachineSlot.slot_code == it.slot_code).first()
        if not slot or slot.current_stock < it.qty:
            raise PaymentError(f"สินค้าช่อง {it.slot_code} ไม่พอ")
    for it in order.items:
        slot = db.query(MachineSlot).filter(MachineSlot.slot_code == it.slot_code).first()
        slot.current_stock -= it.qty

    order.status = "PAID"
    order.paid_at = datetime.now(timezone.utc)
    db.commit()
    return True
