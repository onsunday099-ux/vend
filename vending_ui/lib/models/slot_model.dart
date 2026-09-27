class SlotModel {
  final int slotId;
  final String slotCode;
  final String productName;
  final String category;
  final double price;
  final int stock;

  SlotModel({
    required this.slotId,
    required this.slotCode,
    required this.productName,
    required this.category,
    required this.price,
    required this.stock,
  });

  bool get isOutOfStock => stock <= 0;

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      slotId: json['slot_id'] ?? 0,
      slotCode: json['slot_code'] ?? '',
      productName: json['product_name'] ?? 'ไม่มีชื่อสินค้า',
      category: json['category'] ?? 'ทั่วไป',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      stock: json['stock'] ?? 0,
    );
  }
}