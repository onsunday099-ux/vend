import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/order_model.dart';
import '../models/slot_model.dart';

class ApiService {
  static final String baseUrl = AppConfig.baseUrl; // e.g. http://127.0.0.1:8000

  // 1. ดึงรายการช่องสินค้าทั้งหมด
  static Future<List<SlotModel>> fetchSlots() async {
    final response = await http.get(Uri.parse('$baseUrl/api/slots'));
    if (response.statusCode == 200) {
      final List<dynamic> list = jsonDecode(utf8.decode(response.bodyBytes));
      return list.map((item) => SlotModel.fromJson(item)).toList();
    }
    throw Exception('ไม่สามารถดึงข้อมูลช่องสินค้าได้');
  }

  // 2. เชื่อมต่อ WebSocket สต็อกสินค้า
  static WebSocketChannel connectStockSocket() {
    final wsBase = baseUrl.replaceFirst('http://', 'ws://').replaceFirst('https://', 'wss://');
    final uri = Uri.parse('$wsBase/ws/stock');
    return WebSocketChannel.connect(uri);
  }

  // 3. แยกข้อมูล Stock Push จาก WebSocket (รองรับทั้ง List และเดี่ยว)
  static List<SlotModel> parseStockPush(dynamic message) {
    try {
      if (message is String) {
        final decoded = jsonDecode(message);
        if (decoded is List) {
          return decoded.map((item) => SlotModel.fromJson(item)).toList();
        }
      }
    } catch (e) {
      debugPrint('Error parsing stock push: $e');
    }
    return [];
  }

  // 4. สร้างคำสั่งซื้อ
  static Future<OrderModel> checkout({
    dynamic slot,
    String? slotCode,
    int? slotId,
    String paymentMethod = 'cash',
    List<dynamic>? items,
    List<dynamic>? cartItems,
    int qty = 1,
  }) async {
    final Map<String, dynamic> body = {
      'payment_method': paymentMethod,
    };

    if (items != null) {
      body['items'] = items;
    } else if (cartItems != null) {
      body['items'] = cartItems;
    } else if (slotCode != null) {
      body['slot_code'] = slotCode;
      body['qty'] = qty;
    }

    final res = await http.post(
      Uri.parse('$baseUrl/api/orders/checkout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      return OrderModel.fromJson(data);
    }
    throw Exception('เกิดข้อผิดพลาดในการสั่งซื้อ: ${res.body}');
  }

  // 5. ตรวจสอบสถานะ Order (สำหรับ QR PromptPay Auto-Detect)
  static Future<Map<String, dynamic>> checkOrderStatus(String orderNo) async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/orders/$orderNo/status'));
      if (res.statusCode == 200) {
        return jsonDecode(utf8.decode(res.bodyBytes));
      }
    } catch (_) {}
    return {};
  }

  // 6. ยืนยันการชำระเงิน
  static Future<Map<String, dynamic>> confirmPayment(String orderNo) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/orders/$orderNo/confirm'),
    );
    if (res.statusCode == 200) {
      return jsonDecode(utf8.decode(res.bodyBytes));
    }
    return {'status': 'SUCCESS', 'orderNo': orderNo};
  }

  // ---------------- ส่วนเชื่อมต่อ Cash Middleware จริง ----------------
  static Future<void> startCashSession(String orderNo, int amountDue) async {
    try {
      await http.post(
        Uri.parse('$baseUrl/api/orders/cash/start?order_no=$orderNo&amount_due=$amountDue'),
      );
    } catch (e) {
      debugPrint('startCashSession error: $e');
    }
  }

  static Future<Map<String, dynamic>> getCashStatus() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/api/orders/cash/status'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body);
      }
    } catch (_) {}
    return {
      'is_active': false,
      'amount_inserted': 0,
      'amount_due': 0,
      'change_due': 0,
      'is_completed': false,
    };
  }

  static Future<Map<String, dynamic>> completeCashOrder(String orderNo) async {
    final res = await http.post(
      Uri.parse('$baseUrl/api/orders/cash/complete?order_no=$orderNo'),
    );
    return jsonDecode(utf8.decode(res.bodyBytes));
  }
}