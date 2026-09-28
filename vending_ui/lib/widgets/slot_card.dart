import 'package:flutter/material.dart';
import '../models/slot_model.dart';
import '../config/app_colors.dart';

class SlotCard extends StatelessWidget {
  final SlotModel slot;
  final bool isInCart;
  final VoidCallback? onTap;

  const SlotCard({
    Key? key,
    required this.slot,
    this.isInCart = false,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isOutOfStock = slot.currentStock <= 0;
    final bool hasImage = slot.imageUrl != null && slot.imageUrl!.isNotEmpty;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isInCart
              ? AppColors.primary
              : (isOutOfStock ? Colors.grey.shade300 : Colors.grey.shade200),
          width: isInCart ? 3.0 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isInCart
                ? AppColors.primary.withOpacity(0.25)
                : Colors.black.withOpacity(0.04),
            blurRadius: isInCart ? 10 : 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: isOutOfStock ? null : onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. หัวการ์ด: รหัสช่อง (slotId) และสต็อกคงเหลือ (currentStock)
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isOutOfStock
                            ? Colors.grey.shade400
                            : (isInCart ? AppColors.primary : Colors.grey.shade800),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        slot.slotId,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    // ป้ายสถานะ
                    if (isInCart)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.check_circle, size: 12, color: AppColors.primary),
                            SizedBox(width: 3),
                            Text(
                              "ในตะกร้า",
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Text(
                        isOutOfStock ? "หมด" : "เหลือ ${slot.currentStock}",
                        style: TextStyle(
                          color: isOutOfStock ? Colors.red.shade600 : Colors.green.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),

              // 2. ส่วนรูปภาพสินค้า: สัดส่วน flex 6 เพื่อให้รูปใหญ่และชัดเจนที่สุด
              Expanded(
                flex: 6,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Center(
                        child: hasImage
                            ? Image.network(
                                slot.imageUrl!,
                                fit: BoxFit.contain, // แสดงรูปเต็มกระป๋อง/ขวด ไม่โดนตัดขอบ
                                width: double.infinity,
                                height: double.infinity,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) => Icon(
                                  Icons.fastfood_rounded,
                                  size: 64,
                                  color: Colors.grey.shade300,
                                ),
                              )
                            : Icon(
                                Icons.inventory_2_outlined,
                                size: 64,
                                color: Colors.grey.shade300,
                              ),
                      ),

                      // คลุมทับเมื่อสินค้าหมด
                      if (isOutOfStock)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.75),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Center(
                              child: Chip(
                                backgroundColor: Colors.black87,
                                label: Text(
                                  "SOLD OUT",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              Divider(height: 1, color: Colors.grey.shade100),

              // 3. ส่วนข้อมูลสินค้า: ชื่อ (productName) และราคา (price)
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slot.productName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isOutOfStock ? Colors.grey.shade500 : Colors.grey.shade800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "฿${slot.price.toStringAsFixed(0)}",
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isOutOfStock
                              ? Colors.grey.shade400
                              : (isInCart ? AppColors.primary : Colors.black),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}