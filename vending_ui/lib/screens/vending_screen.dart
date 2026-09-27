import 'package:flutter/material.dart';
import '../config/app_colors.dart';
import '../models/cart_item_model.dart';
import '../models/order_model.dart';
import '../models/slot_model.dart';
import '../services/api_service.dart';
import '../widgets/vending_console_panel.dart';
import '../widgets/vending_screen_panel.dart';

class VendingScreen extends StatefulWidget {
  const VendingScreen({super.key});

  @override
  State<VendingScreen> createState() => _VendingScreenState();
}

class _VendingScreenState extends State<VendingScreen> {
  List<SlotModel> slots = [];
  final List<CartItemModel> cart = [];
  bool isLoading = true;

  String paymentMethod = "qr"; // 'qr' หรือ 'cash'
  OrderModel? activeOrder;
  bool isCreatingOrder = false;

  @override
  void initState() {
    super.initState();
    loadSlots();
  }

  Future<void> loadSlots() async {
    setState(() => isLoading = true);
    try {
      final fetched = await ApiService.fetchSlots();
      setState(() => slots = fetched);
    } catch (_) {
      _showToast("เชื่อมต่อเซิร์ฟเวอร์ตู้ไม่สำเร็จ", isError: true);
    } finally {
      setState(() => isLoading = false);
    }
  }

  void toggleSlotInCart(SlotModel slot) {
    setState(() {
      final index = cart.indexWhere((c) => c.slot.slotId == slot.slotId);
      if (index >= 0) {
        cart.removeAt(index);
      } else {
        cart.add(CartItemModel(slot: slot, quantity: 1));
      }
      activeOrder = null;
    });
  }

  bool isSlotInCart(int slotId) {
    return cart.any((c) => c.slot.slotId == slotId);
  }

  void clearCart() {
    setState(() {
      cart.clear();
      activeOrder = null;
    });
  }

  Future<void> handleCheckout() async {
    if (cart.isEmpty) return;

    if (paymentMethod == 'cash') {
      _showToast("กรุณาหยอดเงินสดให้ครบจำนวน");
      return;
    }

    setState(() => isCreatingOrder = true);
    try {
      final targetSlot = cart.first.slot;
      final order = await ApiService.createOrder(targetSlot.slotId);
      setState(() => activeOrder = order);
    } catch (e) {
      _showToast(e.toString().replaceAll("Exception: ", ""), isError: true);
    } finally {
      setState(() => isCreatingOrder = false);
    }
  }

  Future<void> handleConfirmPaid() async {
    if (activeOrder == null) return;
    try {
      await ApiService.confirmPayment(activeOrder!.orderNo);
      _showToast("ชำระเงินสำเร็จ กรุณารับสินค้าที่ช่องรับของ");
      clearCart();
      loadSlots();
    } catch (e) {
      _showToast(e.toString().replaceAll("Exception: ", ""), isError: true);
    }
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? AppColors.priceRed : AppColors.onlineGreen,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.machineBody,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 68,
                child: VendingScreenPanel(
                  slots: slots,
                  isLoading: isLoading,
                  isSlotInCart: isSlotInCart,
                  onToggleSelect: toggleSlotInCart,
                  onRefresh: loadSlots,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 32,
                child: VendingConsolePanel(
                  cart: cart,
                  paymentMethod: paymentMethod,
                  onSelectPaymentMethod: (m) => setState(() => paymentMethod = m),
                  activeOrder: activeOrder,
                  isCreatingOrder: isCreatingOrder,
                  onCheckout: handleCheckout,
                  onConfirmPaid: handleConfirmPaid,
                  onClearCart: clearCart,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}