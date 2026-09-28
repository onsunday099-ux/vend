import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/slot_model.dart';
import 'slot_card.dart';

class VendingScreenPanel extends StatelessWidget {
  final dynamic slots;
  final dynamic selectedSlot;
  final dynamic onSelectSlot;
  final dynamic onSelect;
  final int currentPage;
  final int totalPages;
  final VoidCallback? onPrevPage;
  final VoidCallback? onNextPage;

  const VendingScreenPanel({
    Key? key,
    this.slots,
    this.selectedSlot,
    this.onSelectSlot,
    this.onSelect,
    this.currentPage = 1,
    this.totalPages = 1,
    this.onPrevPage,
    this.onNextPage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // รองรับทั้ง List<SlotModel> และ List<dynamic>
    final List<dynamic> slotList = (slots is List) ? (slots as List) : [];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder),
        boxShadow: AppColors.softShadow,
      ),
      child: Column(
        children: [
          // Header ด้านบน
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.storefront_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 8),
              Text(
                'VENDING MACHINE',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 16),

          // ตารางแสดงสินค้า (GridView)
          Expanded(
            child: slotList.isEmpty
                ? const Center(
                    child: Text(
                      'ไม่มีสินค้าในตู้',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 16),
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 0.75,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: slotList.length,
                    itemBuilder: (context, index) {
                      final slot = slotList[index];
                      final isSelected = selectedSlot != null &&
                          (selectedSlot is SlotModel
                              ? selectedSlot.id == slot.id
                              : selectedSlot.toString() == slot.id.toString());

                      return SlotCard(
                        slot: slot,
                        isSelected: isSelected,
                        onTap: () {
                          if (onSelectSlot != null) onSelectSlot(slot);
                          if (onSelect != null) onSelect(slot);
                        },
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.cardBorder, height: 1),
          const SizedBox(height: 12),

          // ปุ่มเลื่อนหน้า (Pagination)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                color: currentPage > 1 ? AppColors.textDark : AppColors.cardBorder,
                onPressed: currentPage > 1 ? onPrevPage : null,
              ),
              Text(
                'หน้า $currentPage / $totalPages',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textDark,
                  fontSize: 14,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                color: currentPage < totalPages ? AppColors.textDark : AppColors.cardBorder,
                onPressed: currentPage < totalPages ? onNextPage : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}