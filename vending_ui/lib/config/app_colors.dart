import 'package:flutter/material.dart';

class AppColors {
  // โทนสีขาวสะอาด สบายตา (Clean White Minimalist Palette)
  static const Color machineBody = Color(0xFFF8FAFC);  // พื้นหลังหลัก ขาวนวล Off-white นุ่มตา
  static const Color cardWhite = Color(0xFFFFFFFF);    // การ์ดสีขาวบริสุทธิ์
  static const Color cardBorder = Color(0xFFE2E8F0);   // เส้นขอบเทาอ่อน เส้นคมละมุน
  static const Color textDark = Color(0xFF0F172A);     // ตัวหนังสือสีเทาดำคมชัด สไตล์ Slate 900
  static const Color textMuted = Color(0xFF64748B);    // สีข้อความรอง Slate 500
  static const Color onlineGreen = Color(0xFF10B981);  // สีเขียวมรกต สถานะพร้อมใช้งาน
  static const Color primary = Color(0xFF2563EB);      // สีน้ำเงิน Modern Royal Blue
  static const Color primaryLight = Color(0xFFEFF6FF); // สีฟ้าอ่อนพาสเทล นวลตา
  static const Color priceRed = Color(0xFFEF4444); 
  static const Color unselected = Color(0xFFFFFFFF);
  static const Color unselectedBorder = Color(0xFFCBD5E1);    // สีแดงราคาสินค้า นุ่มตา ไม่ฉูดฉาด

  // Aliases เพิ่มเติมสำหรับความสะดวก
  static const Color background = machineBody;
  static const Color surface = cardWhite;
  static const Color border = cardBorder;
  static const Color textPrimary = textDark;
  static const Color textSecondary = textMuted;
  static const Color success = onlineGreen;
  static const Color error = priceRed;

  // เงาละมุน (Soft Shadow)
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.04),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];
}