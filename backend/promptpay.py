import re

# --- ตัวสร้าง PromptPay QR ---
def _tlv(tag: str, value: str) -> str:
    return f"{tag}{len(value):02d}{value}"

def _crc16(data: str) -> str:
    crc = 0xFFFF
    for b in data.encode("ascii"):
        crc ^= (b << 8)
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if (crc & 0x8000) else (crc << 1)
            crc &= 0xFFFF
    return f"{crc:04X}"

def generate_promptpay_payload(phone: str, amount: float) -> str:
    digits = re.sub(r"\D", "", phone)
    formatted = "0066" + digits[1:] if len(digits) == 10 and digits.startswith("0") else digits
    merchant = _tlv("00", "A000000677010111") + _tlv("01", formatted)
    data = (
        _tlv("00", "01") + _tlv("01", "12") + _tlv("29", merchant) +
        _tlv("53", "764") + _tlv("54", f"{amount:.2f}") + _tlv("58", "TH") + "6304"
    )
    return data + _crc16(data)
