import 'package:flutter/material.dart';
import '../models/slot_model.dart';
import '../config/app_colors.dart';
import 'slot_card.dart';

class VendingScreenPanel extends StatefulWidget {
  final List<SlotModel> slots;
  final bool isLoading;
  final bool Function(String) isSlotInCart;
  final void Function(SlotModel) onToggleSelect;
  final Future<void> Function() onRefresh;

  const VendingScreenPanel({
    Key? key,
    required this.slots,
    required this.isLoading,
    required this.isSlotInCart,
    required this.onToggleSelect,
    required this.onRefresh,
  }) : super(key: key);

  @override
  State<VendingScreenPanel> createState() => _VendingScreenPanelState();
}

class _VendingScreenPanelState extends State<VendingScreenPanel> {
  String _selectedCategory = 'all';

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': 'ทั้งหมด'},
    {'id': 'drinks', 'label': 'เครื่องดื่ม'},
    {'id': 'snacks', 'label': 'ขนมขบเคี้ยว'},
  ];

  @override
  Widget build(BuildContext context) {
    // กรองสินค้าตามหมวดหมู่
    final filteredSlots = _selectedCategory == 'all'
        ? widget.slots
        : widget.slots
            .where((s) => s.category.toLowerCase() == _selectedCategory)
            .toList();

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // แถบหัวข้อด้านบน + หมวดหมู่ + ปุ่ม Refresh
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront_rounded, color: AppColors.primary, size: 26),
                const SizedBox(width: 8),
                const Text(
                  "เลือกสินค้าในตู้",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(width: 16),

                // หมวดหมู่สินค้า
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _categories.map((cat) {
                        final bool isCatSelected = _selectedCategory == cat['id'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(cat['label']!),
                            selected: isCatSelected,
                            selectedColor: AppColors.primary,
                            backgroundColor: Colors.grey.shade100,
                            labelStyle: TextStyle(
                              color: isCatSelected ? Colors.white : Colors.grey.shade700,
                              fontWeight: isCatSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 13,
                            ),
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedCategory = cat['id']!;
                                });
                              }
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // ปุ่ม Refresh ข้อมูล
                IconButton(
                  tooltip: 'รีเฟรชสินค้า',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.grey),
                  onPressed: widget.onRefresh,
                ),
              ],
            ),
          ),

          // ตารางแสดงสินค้า (GridView)
          Expanded(
            child: widget.isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSlots.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 12),
                            Text(
                              "ไม่พบรายการสินค้าในหมวดหมู่นี้",
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: widget.onRefresh,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // แบ่ง 3 หรือ 4 คอลัมน์ตามขนาดความกว้างหน้าจอ
                            final int crossAxisCount = constraints.maxWidth > 900 ? 4 : 3;

                            return GridView.builder(
                              padding: const EdgeInsets.all(16),
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: crossAxisCount,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                                childAspectRatio: 0.65, // ให้การ์ดยาวขึ้น เพื่อให้รูปขยายใหญ่ได้เต็มที่
                              ),
                              itemCount: filteredSlots.length,
                              itemBuilder: (context, index) {
                                final slot = filteredSlots[index];
                                final bool inCart = widget.isSlotInCart(slot.slotId);

                                return SlotCard(
                                  slot: slot,
                                  isInCart: inCart,
                                  onTap: () => widget.onToggleSelect(slot),
                                );
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}