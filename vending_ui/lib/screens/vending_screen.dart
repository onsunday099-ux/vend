import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
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

  WebSocketChannel? _stockSocket;
  StreamSubscription? _stockSub;
  Timer? _pollingTimer; // ใช้ polling middleware สำหรับเงินสดและ QR

  @override
  void initState() {
    super.initState();
    loadSlots();
    _connectStockSocket();
  }

  @override
  void dispose() {
    _stopPolling();
    _stockSub?.cancel();
    _stockSocket?.sink.close();
    super.dispose();
  }

  void _connectStockSocket() {
    try {
      _stockSocket = ApiService.connectStockSocket();
      _stockSub = _stockSocket!.stream.listen(
        (message) {
          final updated = ApiService.parseStockPush(message);
          if (updated.isNotEmpty) {
            setState(() {
              slots = updated;
              isLoading = false;
            });
          }
        },
        onError: (_) {},
      );
    } catch (_) {}
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
      _stopPolling();
    });
  }

  bool isSlotInCart(int slotId) {
    return cart.any((c) => c.slot.slotId == slotId);
  }

  void clearCart() {
    _stopPolling();
    setState(() {
      cart.clear();
      activeOrder = null;
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  // --- เริ่มขั้นตอน Checkout ต่อกับ Middleware จริง ---
  Future<void> handleCheckout() async {
    if (cart.isEmpty) return;

    setState(() => isCreatingOrder = true);
    try {
      final items = cart
          .map((c) => {'slot_id': c.slot.slotId, 'qty': c.quantity})
          .toList();
      final apiPaymentMethod = paymentMethod == 'cash' ? 'cash' : 'promptpay_qr';

      final order = await ApiService.checkout(
        items: items,
        paymentMethod: apiPaymentMethod,
      );

      setState(() => activeOrder = order);

      if (paymentMethod == 'cash') {
        // 1. ส่งสัญญาณให้ Cash Middleware เริ่มรับเหรียญ/ธนบัตร
        final int totalDue = (order.amount ?? 0).toInt();
        await ApiService.startCashSession(order.orderNo, totalDue);
        _startCashPolling(order.orderNo);
      } else {
        // 2. ถ้าเป็น QR ให้คอยเช็กสถานะการโอนอัตโนมัติ
        _startQrStatusPolling(order.orderNo);
      }
    } catch (e) {
      _showToast(e.toString().replaceAll("Exception: ", ""), isError: true);
    } finally {
      setState(() => isCreatingOrder = false);
    }
  }

  // Polling เช็กยอดเงินสดจากฮาร์ดแวร์ตู้ผ่าน Middleware ทุก 1 วินาที
  void _startCashPolling(String orderNo) {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final status = await ApiService.getCashStatus();
      if (!mounted) return;

      if (status['is_completed'] == true) {
        timer.cancel();
        await ApiService.completeCashOrder(orderNo);
        _showToast("รับเงินสดครบแล้ว กำลังปล่อยสินค้า...");
        clearCart();
        loadSlots(); // รีเฟรชสต็อก
      }
    });
  }

  // Polling เช็กสถานะการจ่าย QR Code
  void _startQrStatusPolling(String orderNo) {
    _stopPolling();
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final res = await ApiService.checkOrderStatus(orderNo);
      if (!mounted) return;

      if (res['status'] == 'PAID' || res['status'] == 'SUCCESS') {
        timer.cancel();
        _showToast("ชำระเงินสำเร็จ กรุณารับสินค้าที่ช่องรับของ");
        clearCart();
        loadSlots();
      }
    });
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
                  onSelectPaymentMethod: (m) {
                    setState(() => paymentMethod = m);
                    _stopPolling();
                  },
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