import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/slot_model.dart';

class SlotCard extends StatelessWidget {
  final SlotModel slot;
  final bool isSelected;
  final VoidCallback onToggleSelect;

  const SlotCard({
    super.key,
    required this.slot,
    required this.isSelected,
    required this.onToggleSelect,
  });

  String get cleanProductName => slot.productName.split('#').first.trim();

  IconData _getIcon(String category) {
    if (category.contains("เครื่องดื่ม")) return Icons.local_drink_rounded;
    if (category.contains("ของว่าง") || category.contains("ขนม")) {
      return Icons.fastfood_rounded;
    }
    return Icons.inventory_2_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final bool isOut = slot.isOutOfStock;

    return InkWell(
      onTap: isOut ? null : onToggleSelect,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.consoleRed
                : (isOut ? Colors.grey[300]! : AppColors.cardBorder),
            width: isSelected ? 1.8 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.consoleRed.withOpacity(0.12)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            // แสดงสถานะจำนวนคงเหลือ
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isOut ? const Color(0xFFFEE2E2) : const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isOut ? "หมด" : "เหลือ ${slot.currentStock}",
                    style: TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      color: isOut ? Colors.red : const Color(0xFF059669),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),

            // ไอคอนสินค้า (ขนาดกะทัดรัด)
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.consoleRed.withOpacity(0.08)
                    : const Color(0xFFF8FAFC),
              ),
              child: Icon(
                _getIcon(slot.category),
                size: 18,
                color: isOut
                    ? Colors.grey[400]
                    : (isSelected ? AppColors.consoleRed : const Color(0xFF0284C7)),
              ),
            ),
            const SizedBox(height: 3),

            // ชื่อสินค้า
            Text(
              cleanProductName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isOut ? Colors.grey[400] : AppColors.textDark,
              ),
            ),
            const SizedBox(height: 1),

            // ราคา
            Text(
              "฿${slot.price.toStringAsFixed(0)}",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isOut ? Colors.grey[400] : AppColors.priceRed,
              ),
            ),
            const Spacer(),

            // ปุ่มเลือกสินค้า
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 3),
              decoration: BoxDecoration(
                color: isOut
                    ? Colors.grey[200]
                    : (isSelected ? AppColors.consoleRed : const Color(0xFF0284C7)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                isOut ? "หมด" : (isSelected ? "✓ เลือก" : "เลือก"),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isOut ? Colors.grey[500] : Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}