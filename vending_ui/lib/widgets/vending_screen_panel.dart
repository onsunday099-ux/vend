import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/slot_model.dart';
import 'slot_card.dart' show SlotCard;

class VendingScreenPanel extends StatefulWidget {
  final List<SlotModel> slots;
  final bool isLoading;
  final bool Function(String) isSlotInCart;
  final Function(SlotModel) onToggleSelect;
  final VoidCallback onRefresh;

  const VendingScreenPanel({
    super.key,
    required this.slots,
    required this.isLoading,
    required this.isSlotInCart,
    required this.onToggleSelect,
    required this.onRefresh,
  });

  @override
  State<VendingScreenPanel> createState() => _VendingScreenPanelState();
}

class _VendingScreenPanelState extends State<VendingScreenPanel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  // 1 แถวมี 3 อัน (3 คอลัมน์ x 2 แถว = หน้าละ 6 รายการ)
  static const int cols = 3;
  static const int rows = 2;
  static const int itemsPerPage = cols * rows;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int totalPages = widget.slots.isEmpty
        ? 1
        : (widget.slots.length / itemsPerPage).ceil();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // 1. หัวข้อด้านบน
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                SizedBox(width: 8),
                Text(
                  "VENDING MACHINE",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                    color: AppColors.textDark,
                  ),
                ),
              ],
            ),
          ),

          // 2. ตารางสินค้า 3 ช่องต่อแถว ขยายเต็มความสูงอัตโนมัติ
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : widget.slots.isEmpty
                    ? const Center(
                        child: Text(
                          "ไม่พบรายการสินค้าในระบบ",
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ScrollConfiguration(
                        behavior: const ScrollBehavior().copyWith(scrollbars: false),
                        child: PageView.builder(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(), // ปิด Mousewheel
                          itemCount: totalPages,
                          itemBuilder: (context, pageIndex) {
                            final startIndex = pageIndex * itemsPerPage;
                            final endIndex = (startIndex + itemsPerPage > widget.slots.length)
                                ? widget.slots.length
                                : startIndex + itemsPerPage;
                            final pageSlots = widget.slots.sublist(startIndex, endIndex);

                            return LayoutBuilder(
                              builder: (context, constraints) {
                                const double padding = 12.0;
                                const double crossSpacing = 10.0;
                                const double mainSpacing = 10.0;

                                // คำนวณขนาดให้การ์ดขยายเต็มพื้นที่พอดีทั้งกว้างและสูง
                                final double cardWidth = (constraints.maxWidth - (padding * 2) - ((cols - 1) * crossSpacing)) / cols;
                                final double cardHeight = (constraints.maxHeight - (padding * 2) - ((rows - 1) * mainSpacing)) / rows;
                                final double dynamicAspectRatio = cardWidth / cardHeight;

                                return GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  padding: const EdgeInsets.all(padding),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: cols, // 3 ช่องต่อแถว
                                    crossAxisSpacing: crossSpacing,
                                    mainAxisSpacing: mainSpacing,
                                    childAspectRatio: dynamicAspectRatio,
                                  ),
                                  itemCount: pageSlots.length,
                                  itemBuilder: (context, i) {
                                    final slot = pageSlots[i];
                                    return SlotCard(
                                      slot: slot,
                                      isSelected: widget.isSlotInCart(slot.slotId),
                                      onToggleSelect: () => widget.onToggleSelect(slot),
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),

          // 3. แถบควบคุมเปลี่ยนหน้าด้านล่าง
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              border: Border(
                top: BorderSide(color: Color(0xFFE2E8F0), width: 1.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded, size: 16),
                  color: _currentPage > 0 ? AppColors.textDark : Colors.grey[300],
                  onPressed: _currentPage > 0
                      ? () {
                          setState(() => _currentPage--);
                          _pageController.animateToPage(
                            _currentPage,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
                Text(
                  "หน้า ${_currentPage + 1} / $totalPages",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textDark,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  color: _currentPage < totalPages - 1 ? AppColors.textDark : Colors.grey[300],
                  onPressed: _currentPage < totalPages - 1
                      ? () {
                          setState(() => _currentPage++);
                          _pageController.animateToPage(
                            _currentPage,
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                          );
                        }
                      : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}