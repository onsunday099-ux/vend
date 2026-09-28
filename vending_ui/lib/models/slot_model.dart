class SlotModel {
  final int slotId;
  final String machineCode;
  final String slotCode;
  final String productName;
  final String category;
  final double price;
  final String description;
  final int currentStock;

  SlotModel({
    required this.slotId,
    required this.machineCode,
    required this.slotCode,
    required this.productName,
    required this.category,
    required this.price,
    required this.description,
    required this.currentStock,
  });

  bool get isOutOfStock => currentStock <= 0;

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      slotId: json['slot_id'] ?? 0,
      machineCode: json['machine_code'] ?? '',
      slotCode: json['slot_code'] ?? '',
      productName: json['product_name'] ?? 'ไม่มีชื่อสินค้า',
      category: json['category'] ?? 'ทั่วไป',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] ?? '',
      currentStock: json['current_stock'] ?? 0,
    );
  }
}
