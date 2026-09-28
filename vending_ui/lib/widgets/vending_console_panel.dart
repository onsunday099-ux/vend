import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';

class VendingConsolePanel extends StatelessWidget {
  final List<CartItemModel> cart;
  final String paymentMethod;
  final ValueChanged<String> onSelectPaymentMethod;
  final bool isCreatingOrder;
  final OrderModel? activeOrder;
  final double enteredAmount;
  final VoidCallback onCheckout;
  final VoidCallback onClearCart;
  final VoidCallback onCancelOrder;

  const VendingConsolePanel({
    Key? key,
    required this.cart,
    required this.paymentMethod,
    required this.onSelectPaymentMethod,
    required this.isCreatingOrder,
    required this.activeOrder,
    required this.enteredAmount,
    required this.onCheckout,
    required this.onClearCart,
    required this.onCancelOrder,
  }) : super(key: key);

  // คำนวณยอดเงินรวมในตะกร้า
  double get totalAmount {
    double sum = 0.0;
    for (var item in cart) {
      sum += (item.slot.price * item.quantity).toDouble();
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasOrder = activeOrder != null;
    final double dueAmount = totalAmount;
    final double remainingAmount = (dueAmount - enteredAmount) > 0 ? (dueAmount - enteredAmount) : 0.0;
    final double changeAmount = (enteredAmount - dueAmount) > 0 ? (enteredAmount - dueAmount) : 0.0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. หัวข้อ: ยอดชำระทั้งหมด
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "ยอดชำระทั้งหมด",
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    "฿${dueAmount.toStringAsFixed(0)}",
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 10),

          // 2. รายการสินค้าในตะกร้า
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "รายการ (${cart.length})",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Color(0xFF334155),
                ),
              ),
              if (cart.isNotEmpty && !hasOrder)
                GestureDetector(
                  onTap: onClearCart,
                  child: const Text(
                    "ล้าง",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // รายการสินค้า (ดึงชื่อและรหัสช่องผ่าน item.slot อย่างถูกต้อง)
          Expanded(
            flex: 2,
            child: cart.isEmpty
                ? Center(
                    child: Text(
                      "แตะเลือกสินค้าจากจอซ้าย",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: cart.length,
                    separatorBuilder: (_, __) => Divider(height: 8, color: Colors.grey.shade100),
                    itemBuilder: (context, index) {
                      final item = cart[index];
                      // ดึงชื่อสินค้าจาก item.slot.productName หรือ item.slot.name
                      final String pName = item.slot.productName;
                      final String sId = item.slot.slotId;

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              "$pName ($sId) x${item.quantity}",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ),
                          Text(
                            "฿${(item.slot.price * item.quantity).toStringAsFixed(0)}",
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      );
                    },
                  ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),

          // 3. แถบเลือกวิธีชำระเงิน (เงินสด / QR Code)
          const Text(
            "เลือกวิธีชำระเงิน",
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: hasOrder ? null : () => onSelectPaymentMethod('cash'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'cash' ? AppColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 16,
                          color: paymentMethod == 'cash' ? Colors.white : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "เงินสด",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: paymentMethod == 'cash' ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: InkWell(
                  onTap: hasOrder ? null : () => onSelectPaymentMethod('qr'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'qr' ? AppColors.primary : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 16,
                          color: paymentMethod == 'qr' ? Colors.white : Colors.grey.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "สแกน QR",
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: paymentMethod == 'qr' ? Colors.white : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 4. พื้นที่แสดงสถานะการชำระเงิน
          Expanded(
            flex: 3,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: paymentMethod == 'cash'
                  ? (hasOrder
                      // เมื่อเริ่มมีคำสั่งซื้อและรอหยอดเงินสด
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(strokeWidth: 3),
                            const SizedBox(height: 10),
                            const Text(
                              "กำลังรอรับธนบัตร / เหรียญ...",
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "หยอดแล้ว: ฿${enteredAmount.toStringAsFixed(0)}",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Colors.green,
                              ),
                            ),
                            if (changeAmount > 0)
                              Text(
                                "เงินทอน: ฿${changeAmount.toStringAsFixed(0)}",
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blue),
                              )
                            else
                              Text(
                                "คงเหลือ: ฿${remainingAmount.toStringAsFixed(0)}",
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                          ],
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.point_of_sale_rounded, size: 36, color: AppColors.primary),
                            const SizedBox(height: 6),
                            const Text(
                              "ใส่ธนบัตรหรือหยอดเหรียญ\nที่ช่องรับด้านล่าง",
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ))
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded, size: 40, color: AppColors.primary),
                        const SizedBox(height: 6),
                        Text(
                          hasOrder ? "พร้อมสแกน Dynamic QR" : "กดปุ่มด้านล่างเพื่อสร้าง QR",
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 10),

          // 5. ปุ่มแอ็กชัน (ชำระเงิน หรือ ยกเลิกคำสั่งซื้อ)
          if (hasOrder)
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: onCancelOrder,
              child: const Text(
                "ยกเลิกคำสั่งซื้อ",
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              onPressed: (cart.isEmpty || isCreatingOrder) ? null : onCheckout,
              child: isCreatingOrder
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      paymentMethod == 'cash' ? "ชำระด้วยเงินสด" : "สร้าง QR ชำระเงิน",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),

          const SizedBox(height: 6),

          // 6. ข้อความแนะนำขั้นตอน
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ขั้นตอนการสั่งซื้อ",
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                SizedBox(height: 2),
                Text(
                  "1. แตะเลือกสินค้าที่ต้องการ\n2. เลือกชำระเงิน (เงินสด หรือ QR)\n3. รับสินค้าเมื่อชำระสำเร็จ",
                  style: TextStyle(fontSize: 9, color: Color(0xFF475569), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}