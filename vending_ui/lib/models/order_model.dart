class OrderItemModel {
  final String slotCode;
  final String productName;
  final int qty;
  final double unitPrice;

  OrderItemModel({
    required this.slotCode,
    required this.productName,
    required this.qty,
    required this.unitPrice,
  });

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      slotCode: json['slot_code'] ?? '',
      productName: json['product_name'] ?? '',
      qty: json['qty'] ?? 1,
      unitPrice: (json['unit_price'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class OrderModel {
  final String orderNo;
  final String machineCode;
  final List<OrderItemModel> items;
  final double amount;
  final String paymentMethod; // promptpay_qr | cash
  final String? qrPayload;
  final String status;

  OrderModel({
    required this.orderNo,
    required this.machineCode,
    required this.items,
    required this.amount,
    required this.paymentMethod,
    required this.qrPayload,
    required this.status,
  });

  bool get isCash => paymentMethod == 'cash';

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      orderNo: json['order_no'] ?? '',
      machineCode: json['machine_code'] ?? '',
      items: ((json['items'] as List?) ?? [])
          .map((e) => OrderItemModel.fromJson(e))
          .toList(),
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: json['payment_method'] ?? 'promptpay_qr',
      qrPayload: json['qr_payload'],
      status: json['status'] ?? '',
    );
  }
}
