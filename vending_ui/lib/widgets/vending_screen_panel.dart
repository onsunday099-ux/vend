import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
  @override
  Widget build(BuildContext context) {
    final filteredSlots = widget.slots;

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

                const Spacer(),

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
                              "ไม่พบรายการสินค้า",
                              style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
                            ),
                          ],
                        ),
                      )
                    : _buildGrid(filteredSlots),
          ),
        ],
      ),
    );
  }

  // ---------- ตารางสินค้า: ปรับจำนวนคอลัมน์/แถวให้พอดีหน้าจอ ไม่ต้องเลื่อน ----------
  static const double _pad = 16;
  static const double _gap = 14;
  static const double _minCardW = 130;
  static const double _minCardH = 190;
  static const double _maxRatio = 1.0; // กว้าง/สูง สูงสุดของการ์ด
  static const double _minRatio = 0.6; // กว้าง/สูง ต่ำสุดของการ์ด

  Widget _card(SlotModel slot) {
    return SlotCard(
      slot: slot,
      isInCart: widget.isSlotInCart(slot.slotId),
      onTap: () => widget.onToggleSelect(slot),
    );
  }

  Widget _buildGrid(List<SlotModel> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth - _pad * 2;
        final double h = constraints.maxHeight - _pad * 2;
        final int n = items.length;

        // หาจำนวนคอลัมน์ที่ทำให้การ์ดใหญ่ที่สุด โดยทุกใบต้องพอดีในหน้าจอ
        int bestCols = 0;
        double bestArea = 0;
        for (int cols = 1; cols <= n; cols++) {
          final int rows = (n / cols).ceil();
          final double cw = (w - _gap * (cols - 1)) / cols;
          final double ch = (h - _gap * (rows - 1)) / rows;
          if (cw < _minCardW || ch < _minCardH) continue;
          double aw = cw, ah = ch;
          final double ratio = cw / ch;
          if (ratio > _maxRatio) {
            aw = ch * _maxRatio;
          } else if (ratio < _minRatio) {
            ah = cw / _minRatio;
          }
          if (aw * ah > bestArea) {
            bestArea = aw * ah;
            bestCols = cols;
          }
        }

        // สินค้าเยอะจนการ์ดเล็กเกินไป -> เลื่อนได้ (แต่ซ่อนแถบ scroll)
        if (bestCols == 0) {
          final int cols = ((w + _gap) / (_minCardW + _gap)).floor().clamp(1, 6);
          return ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              scrollbars: false,
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: GridView.builder(
              padding: const EdgeInsets.all(_pad),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                crossAxisSpacing: _gap,
                mainAxisSpacing: _gap,
                childAspectRatio: 0.72,
              ),
              itemCount: n,
              itemBuilder: (context, i) => _card(items[i]),
            ),
          );
        }

        final int rows = (n / bestCols).ceil();
        return Padding(
          padding: const EdgeInsets.all(_pad),
          child: Column(
            children: [
              for (int r = 0; r < rows; r++) ...[
                if (r > 0) const SizedBox(height: _gap),
                Expanded(
                  child: Row(
                    children: [
                      for (int c = 0; c < bestCols; c++) ...[
                        if (c > 0) const SizedBox(width: _gap),
                        Expanded(
                          child: r * bestCols + c < n
                              ? LayoutBuilder(
                                  builder: (context, cell) {
                                    double aw = cell.maxWidth, ah = cell.maxHeight;
                                    final double ratio = aw / ah;
                                    if (ratio > _maxRatio) {
                                      aw = ah * _maxRatio;
                                    } else if (ratio < _minRatio) {
                                      ah = aw / _minRatio;
                                    }
                                    return Center(
                                      child: SizedBox(
                                        width: aw,
                                        height: ah,
                                        child: _card(items[r * bestCols + c]),
                                      ),
                                    );
                                  },
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}