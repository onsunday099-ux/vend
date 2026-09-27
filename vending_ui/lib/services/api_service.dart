import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/order_model.dart';
import '../models/slot_model.dart';

class ApiService {
  // ดึงรายการช่องสินค้าทั้งหมด
  static Future<List<SlotModel>> fetchSlots() async {
    final res = await http.get(Uri.parse('${AppConfig.baseUrl}/api/slots'));
    if (res.statusCode == 200) {
      final List data = jsonDecode(utf8.decode(res.bodyBytes));
      return data.map((e) => SlotModel.fromJson(e)).toList();
    } else {
      throw Exception('ไม่สามารถดึงข้อมูลสินค้าได้');
    }
  }

  // สร้างคำสั่งซื้อเพื่อรับ QR Code
  static Future<OrderModel> createOrder(int slotId) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/orders/create/$slotId'),
    );

    final data = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode == 200) {
      return OrderModel.fromJson(data);
    } else {
      throw Exception(data['detail'] ?? 'ไม่สามารถสร้างออเดอร์ได้');
    }
  }

  // ยืนยันการชำระเงิน
  static Future<void> confirmPayment(String orderNo) async {
    final res = await http.post(
      Uri.parse('${AppConfig.baseUrl}/api/orders/$orderNo/confirm-pay'),
    );

    if (res.statusCode != 200) {
      final err = jsonDecode(utf8.decode(res.bodyBytes));
      throw Exception(err['detail'] ?? 'ชำระเงินไม่สำเร็จ');
    }
  }
}