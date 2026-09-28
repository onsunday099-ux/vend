import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/order_model.dart';
import '../services/api_service.dart';

enum MachineState {
  waitingPayment,
  dispensing,
  completed,
}

class PaymentScreen extends StatefulWidget {
  final OrderModel order;

  const PaymentScreen({
    super.key,
    required this.order,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  MachineState _currentState = MachineState.waitingPayment;
  Timer? _pollingTimer;
  double _enteredAmount = 0.0;
  int _qrTimeoutSeconds = 120;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
    if (!widget.order.isCash) {
      _startQrCountdown();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startQrCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_qrTimeoutSeconds > 0) {
        setState(() {
          _qrTimeoutSeconds--;
        });
      } else {
        timer.cancel();
        _cancelOrder();
      }
    });
  }

  void _startPolling() {
    if (widget.order.isCash) {
      _pollingTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        final status = await ApiService.getCashStatus();
        if (!mounted) return;

        setState(() {
          _enteredAmount = (status['amount_inserted'] as num?)?.toDouble() ?? 0.0;
        });

        if (status['is_completed'] == true) {
          timer.cancel();
          await ApiService.completeCashOrder(widget.order.orderNo);
          _processDispense();
        }
      });
    } else {
      _pollingTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
        final res = await ApiService.checkOrderStatus(widget.order.orderNo);
        if (!mounted) return;

        if (res['status'] == 'PAID' || res['status'] == 'SUCCESS') {
          timer.cancel();
          _countdownTimer?.cancel();
          _processDispense();
        }
      });
    }
  }

  void _processDispense() async {
    setState(() {
      _currentState = MachineState.dispensing;
    });
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;
    setState(() {
      _currentState = MachineState.completed;
    });

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _cancelOrder() {
    _pollingTimer?.cancel();
    _countdownTimer?.cancel();
    Navigator.pop(context, false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('ชำระเงิน', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        leading: _currentState == MachineState.waitingPayment
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _cancelOrder,
              )
            : const SizedBox.shrink(),
      ),
      body: SafeArea(
        child: _currentState == MachineState.waitingPayment
            ? _buildPaymentProcess()
            : _buildStatusView(),
      ),
    );
  }

  Widget _buildPaymentProcess() {
    final double remaining = (widget.order.amount - _enteredAmount) > 0 
        ? (widget.order.amount - _enteredAmount) 
        : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'หมายเลขคำสั่งซื้อ: ${widget.order.orderNo}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'จำนวนสินค้า: ${widget.order.items.length} รายการ',
                            style: TextStyle(color: Colors.grey[600], fontSize: 16),
                          ),
                        ],
                      ),
                      Text(
                        '฿${widget.order.amount.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (widget.order.isCash)
            _buildCashPaymentSection(remaining)
          else
            _buildQrPaymentSection(),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: _cancelOrder,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('ยกเลิกรายการ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildCashPaymentSection(double remaining) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ยอดเงินที่ใส่เข้ามาแล้ว:', style: TextStyle(fontSize: 16)),
                Text(
                  '฿${_enteredAmount.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ยอดเงินที่ยังขาด:', style: TextStyle(fontSize: 16)),
                Text(
                  '฿${remaining.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('กรุณาใส่ธนบัตรหรือหยอดเหรียญ...', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrPaymentSection() {
    final qrData = widget.order.qrPayload ?? '';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (qrData.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 200.0,
                ),
              ),
            const SizedBox(height: 16),
            Text(
              'สแกน QR ผ่าน Mobile Banking',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800]),
            ),
            const SizedBox(height: 8),
            Text(
              'เวลาที่เหลือ: $_qrTimeoutSeconds วินาที',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _qrTimeoutSeconds <= 30 ? Colors.red : Colors.blueGrey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusView() {
    IconData icon;
    Color color;
    String title;
    String subtitle;

    switch (_currentState) {
      case MachineState.dispensing:
        icon = Icons.sync;
        color = Colors.blue;
        title = 'กำลังจ่ายสินค้า...';
        subtitle = 'กรุณารอรับสินค้าที่ช่องรับด้านล่าง';
        break;
      case MachineState.completed:
        icon = Icons.check_circle;
        color = Colors.green;
        title = 'ทำรายการสำเร็จ!';
        subtitle = 'ขอบคุณที่ใช้บริการ';
        break;
      default:
        icon = Icons.info;
        color = Colors.grey;
        title = 'ประมวลผล';
        subtitle = '';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _currentState == MachineState.dispensing
                ? const SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(strokeWidth: 6),
                  )
                : Icon(icon, size: 90, color: color),
            const SizedBox(height: 28),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}