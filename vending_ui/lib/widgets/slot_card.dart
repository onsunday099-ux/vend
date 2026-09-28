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
    if (category.contains("ขนมขบเคี้ยว") || category.contains("ขนม")) {
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
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            // แถบแสดงสถานะสต็อก
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
                    isOut ? "หมด" : "คงเหลือ ${slot.currentStock}",
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

            // ส่วนแสดงรูปภาพสินค้า (แสดงรูปจริงจาก URL หรือแสดงไอคอนหากไม่มีรูป)
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isSelected
                    ? AppColors.consoleRed.withOpacity(0.08)
                    : const Color(0xFFF8FAFC),
              ),
              clipBehavior: Clip.antiAlias,
              child: (slot.imageUrl != null && slot.imageUrl!.trim().isNotEmpty)
                  ? Image.network(
                      slot.imageUrl!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        _getIcon(slot.category),
                        size: 20,
                        color: isOut
                            ? Colors.grey[400]
                            : (isSelected ? AppColors.consoleRed : const Color(0xFF0284C7)),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 1.5),
                          ),
                        );
                      },
                    )
                  : Icon(
                      _getIcon(slot.category),
                      size: 20,
                      color: isOut
                          ? Colors.grey[400]
                          : (isSelected ? AppColors.consoleRed : const Color(0xFF0284C7)),
                    ),
            ),
            const Spacer(),

            // ชื่อสินค้า
            Text(
              cleanProductName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isOut ? Colors.grey[400] : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 1),

            // ราคาสินค้า
            Text(
              "฿${slot.price.toStringAsFixed(0)}",
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isOut ? Colors.grey[400] : AppColors.consoleRed,
              ),
            ),
            const SizedBox(height: 2),

            // ปุ่มเลือกสินค้า
            SizedBox(
              width: double.infinity,
              height: 20,
              child: ElevatedButton(
                onPressed: isOut ? null : onToggleSelect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isSelected
                      ? AppColors.consoleRed
                      : const Color(0xFFF1F5F9),
                  foregroundColor: isSelected ? Colors.white : const Color(0xFF475569),
                  elevation: 0,
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(
                  isSelected ? "เลือกแล้ว" : (isOut ? "หมด" : "เลือก"),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}