import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/order_model.dart';
import '../models/slot_model.dart';

class ApiService {
  // ดึงรายการช่องสินค้าทั้งหมด (ใช้ตอนเปิดแอปครั้งแรก ก่อนที่ WebSocket จะเชื่อมต่อ)
  static Future<List<SlotModel>> fetchSlots() async {
    final res = await http.get(Uri.parse('${AppConfig.baseUrl}/api/slots'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((e) => SlotModel.fromJson(e)).toList();
    } else {
      throw Exception('ไม่สามารถดึงข้อมูลสินค้าได้');
    }
  }

  // สร้างคำสั่งซื้อจากตะกร้า (รองรับหลายรายการในออเดอร์เดียว) เลือกวิธีชำระได้ทั้ง QR และเงินสด
  static Future<OrderModel> checkout({
    required List<Map<String, int>> items, // [{'slot_id': x, 'qty': y}, ...]
    required String paymentMethod, // 'promptpay_qr' | 'cash'
  }) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/orders/checkout'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'items': items, 'payment_method': paymentMethod}),
    );

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 200) {
      return OrderModel.fromJson(data);
    } else {
      throw Exception(data['detail'] ?? 'ไม่สามารถสร้างออเดอร์ได้');
    }
  }

  // ยืนยันการชำระเงินผ่าน QR (ไม่จำเป็นสำหรับออเดอร์ที่จ่ายด้วยเงินสด เพราะตัดสต็อกทันทีตั้งแต่ตอน checkout)
  static Future<void> confirmPayment(String orderNo) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/orders/$orderNo/confirm-pay'),
    );

    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(err['detail'] ?? 'ชำระเงินไม่สำเร็จ');
    }
  }

  // เชื่อมต่อ WebSocket เพื่อรับการอัปเดตสต็อกแบบเรียลไทม์จาก Backend
  // แทนที่การเรียก fetchSlots() ซ้ำ ๆ ด้วยมือหลังทำรายการ
  static WebSocketChannel connectStockSocket() {
    final wsUrl = AppConfig.baseUrl.replaceFirst('http', 'ws');
    return WebSocketChannel.connect(Uri.parse('$wsUrl/ws/stock'));
  }

  static List<SlotModel> parseStockPush(dynamic rawMessage) {
    final decoded = jsonDecode(rawMessage as String);
    final List data = decoded['slots'] ?? [];
    return data.map((e) => SlotModel.fromJson(e)).toList();
  }
}