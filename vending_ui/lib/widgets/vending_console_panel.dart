import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_colors.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';

class VendingConsolePanel extends StatelessWidget {
  final List<CartItemModel> cart;
  final String paymentMethod;
  final Function(String) onSelectPaymentMethod;
  final OrderModel? activeOrder;
  final bool isCreatingOrder;
  final VoidCallback onCheckout;
  final VoidCallback onConfirmPaid;
  final VoidCallback onClearCart;

  const VendingConsolePanel({
    super.key,
    required this.cart,
    required this.paymentMethod,
    required this.onSelectPaymentMethod,
    required this.activeOrder,
    required this.isCreatingOrder,
    required this.onCheckout,
    required this.onConfirmPaid,
    required this.onClearCart,
  });

  double get totalAmount => cart.fold(0, (sum, i) => sum + i.totalPrice);

  Widget _buildPaymentArea() {
    if (isCreatingOrder) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (paymentMethod == 'qr' && activeOrder != null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: QrImageView(
              data: activeOrder!.qrPayload,
              size: 115,
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "สแกนจ่าย ฿${activeOrder!.amount.toStringAsFixed(0)}",
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.onlineGreen,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: onConfirmPaid,
              child: const Text(
                "ยืนยันรับสินค้า",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    if (paymentMethod == 'cash') {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: AppColors.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.payments_outlined,
              size: 32,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "ใส่ธนบัตรหรือหยอดเหรียญ\nที่ช่องรับด้านล่าง",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColors.textDark, height: 1.3),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: cart.isEmpty ? null : onCheckout,
              child: const Text(
                "ชำระด้วยเงินสด",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.primaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.qr_code_2_rounded,
            size: 32,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "กดปุ่มด้านล่าง\nเพื่อสร้าง QR Code",
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppColors.textMuted, height: 1.3),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 36,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: cart.isEmpty ? null : onCheckout,
            child: const Text(
              "สร้าง QR สแกนจ่าย",
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Digital Cart Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "ยอดชำระทั้งหมด",
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 16),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "฿${totalAmount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // รายการสินค้าในตะกร้า (แสดงเฉพาะชื่อสินค้า ไม่เอา #)
          Container(
            height: 115,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: cart.isEmpty
                ? const Center(
                    child: Text(
                      "แตะเลือกสินค้าจากจอซ้าย",
                      style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                    ),
                  )
                : Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "รายการ (${cart.length})",
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          GestureDetector(
                            onTap: onClearCart,
                            child: const Text(
                              "ล้าง",
                              style: TextStyle(
                                color: Colors.redAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 8),
                      Expanded(
                        child: ScrollConfiguration(
                          behavior: const ScrollBehavior().copyWith(scrollbars: false),
                          child: ListView.builder(
                            padding: const EdgeInsets.only(right: 6),
                            itemCount: cart.length,
                            itemBuilder: (_, i) {
                              final item = cart[i];
                              final cleanName = item.slot.productName.split('#').first.trim();
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2.5),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cleanName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    Text(
                                      "฿${item.slot.price.toStringAsFixed(0)}",
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.priceRed,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),

          // 2. แถบเลือกวิธีจ่ายเงิน
          const Text(
            "เลือกวิธีชำระเงิน",
            style: TextStyle(color: AppColors.textDark, fontSize: 11, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () => onSelectPaymentMethod('cash'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'cash' ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: paymentMethod == 'cash' ? AppColors.primary : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.payments_outlined,
                          size: 15,
                          color: paymentMethod == 'cash' ? Colors.white : AppColors.textDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "เงินสด",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: paymentMethod == 'cash' ? Colors.white : AppColors.textDark,
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
                  onTap: () => onSelectPaymentMethod('qr'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: paymentMethod == 'qr' ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: paymentMethod == 'qr' ? AppColors.primary : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.qr_code_2_rounded,
                          size: 15,
                          color: paymentMethod == 'qr' ? Colors.white : AppColors.textDark,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "สแกน QR",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: paymentMethod == 'qr' ? Colors.white : AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. QR Area & Payment Area
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: _buildPaymentArea(),
            ),
          ),
          const SizedBox(height: 12),

          // 4. ขั้นตอนการซื้อ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "ขั้นตอนการสั่งซื้อ",
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  "1. แตะเลือกสินค้าที่ต้องการ\n2. เลือกชำระเงิน (เงินสด หรือ QR)\n3. รับสินค้าเมื่อชำระสำเร็จ",
                  style: TextStyle(color: AppColors.textMuted, fontSize: 9.5, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}