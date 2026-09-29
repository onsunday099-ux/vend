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

  String paymentMethod = "cash";
  bool isCreatingOrder = false;

  OrderModel? activeOrder;
  double enteredAmount = 0.0;
  Timer? _pollingTimer;

  WebSocketChannel? _stockSocket;
  StreamSubscription? _stockSub;

  @override
  void initState() {
    super.initState();
    loadSlots();
    _connectStockSocket();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
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
    if (activeOrder != null) return;
    setState(() {
      final index = cart.indexWhere((c) => c.slot.slotId == slot.slotId);
      if (index >= 0) {
        cart.removeAt(index);
      } else {
        cart.add(CartItemModel(slot: slot, quantity: 1));
      }
    });
  }

  // แก้ไขรับ String slotId ให้ตรงกับ SlotModel
  bool isSlotInCart(String slotId) {
    return cart.any((c) => c.slot.slotId == slotId);
  }

  void clearCart() {
    if (activeOrder != null) return;
    setState(() {
      cart.clear();
    });
  }

  void cancelActiveOrder({bool notifyServer = true}) {
    _pollingTimer?.cancel();
    if (notifyServer && activeOrder != null) {
      ApiService.cancelOrder(activeOrder!.orderNo);
    }
    setState(() {
      activeOrder = null;
      enteredAmount = 0.0;
    });
  }

  void _completeOrder() {
    _showToast("ชำระเงินสำเร็จ รับสินค้าที่ช่องรับของ");
    setState(() {
      cart.clear();
      activeOrder = null;
      enteredAmount = 0.0;
    });
    loadSlots();
  }

  Future<void> handleCheckout() async {
    if (cart.isEmpty || activeOrder != null) return;

    setState(() => isCreatingOrder = true);
    try {
      final items = cart.map((c) => {'slot_id': c.slot.slotId, 'qty': c.quantity}).toList();
      final apiPaymentMethod = paymentMethod == 'cash' ? 'cash' : 'promptpay_qr';

      // ต้องสร้างออเดอร์กับ backend ได้จริงเท่านั้น (ไม่มีการจำลองจ่ายเงินเองในแอปอีกต่อไป)
      final order = await ApiService.checkout(
        items: items,
        paymentMethod: apiPaymentMethod,
      );
      if (paymentMethod == 'cash') {
        await ApiService.startCashSession(order.orderNo, order.amount.toInt());
      }

      if (!mounted) return;
      setState(() {
        isCreatingOrder = false;
        activeOrder = order;
        enteredAmount = 0.0;
      });
      _startPolling();
    } catch (e) {
      if (mounted) {
        setState(() => isCreatingOrder = false);
        _showToast(e.toString().replaceAll("Exception: ", ""), isError: true);
      }
    }
  }

  void _startPolling() {
    if (activeOrder == null) return;

    if (activeOrder!.isCash) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        try {
          final status = await ApiService.getCashStatus();
          if (!mounted || activeOrder == null) {
            timer.cancel();
            return;
          }
          setState(() {
            enteredAmount = (status['amount_inserted'] as num?)?.toDouble() ?? 0.0;
          });
          if (status['order_status'] == 'CANCELLED') {
            timer.cancel();
            cancelActiveOrder(notifyServer: false);
            _showToast("ยกเลิกรายการที่ตัวรับเงินแล้ว", isError: true);
            return;
          }
          if (status['is_completed'] == true) {
            timer.cancel();
            await ApiService.completeCashOrder(activeOrder!.orderNo);
            _completeOrder();
          }
        } catch (_) {}
      });
    } else {
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        try {
          final res = await ApiService.checkOrderStatus(activeOrder!.orderNo);
          if (!mounted || activeOrder == null) {
            timer.cancel();
            return;
          }
          if (res['status'] == 'PAID') {
            timer.cancel();
            _completeOrder();
          } else if (res['status'] == 'CANCELLED') {
            timer.cancel();
            cancelActiveOrder(notifyServer: false);
            _showToast("รายการถูกยกเลิก", isError: true);
          }
        } catch (_) {}
      });
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
                    if (activeOrder == null) {
                      setState(() => paymentMethod = m);
                    }
                  },
                  isCreatingOrder: isCreatingOrder,
                  activeOrder: activeOrder,
                  enteredAmount: enteredAmount,
                  onCheckout: handleCheckout,
                  onClearCart: clearCart,
                  onCancelOrder: () => cancelActiveOrder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}