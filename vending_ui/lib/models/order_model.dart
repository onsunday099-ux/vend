class OrderModel {
  final String orderNo;
  final String slotCode;
  final String productName;
  final double amount;
  final String qrPayload;

  OrderModel({
    required this.orderNo,
    required this.slotCode,
    required this.productName,
    required this.amount,
    required this.qrPayload,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderNo: json['order_no'] ?? '',
      slotCode: json['slot_code'] ?? '',
      productName: json['product_name'] ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      qrPayload: json['qr_payload'] ?? '',
    );
  }
}