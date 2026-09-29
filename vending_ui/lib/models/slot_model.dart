class SlotModel {
  final String slotId;
  final String code; // รหัสช่อง เช่น A1
  final String productName;
  final double price;
  final int currentStock;
  final int maxCapacity;
  final String category;
  final String status;
  final DateTime lastUpdated;
  final String? imageUrl; // <-- เพิ่มฟิลด์ imageUrl
  int get stock => currentStock;
  String get name => productName;
  String get id => slotId;
  String get slotCode => code.isNotEmpty ? code : slotId;

  SlotModel({
    required this.slotId,
    this.code = '',
    required this.productName,
    required this.price,
    required this.currentStock,
    required this.maxCapacity,
    required this.category,
    required this.status,
    required this.lastUpdated,
    this.imageUrl,
  });

  factory SlotModel.fromJson(Map<String, dynamic> json) {
    return SlotModel(
      slotId: json['slot_id']?.toString() ?? '',
      code: json['slot_code']?.toString() ?? '',
      productName: json['product_name'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currentStock: json['current_stock'] ?? 0,
      maxCapacity: json['max_capacity'] ?? 10,
      category: json['category'] ?? '',
      status: json['status'] ?? 'NORMAL',
      lastUpdated: json['last_updated'] != null
          ? DateTime.parse(json['last_updated'])
          : DateTime.now(),
      imageUrl: json['image_url'] as String?, // <-- รับค่า image_url จาก Backend
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'slot_id': slotId,
      'slot_code': code,
      'product_name': productName,
      'price': price,
      'current_stock': currentStock,
      'max_capacity': maxCapacity,
      'category': category,
      'status': status,
      'image_url': imageUrl,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  bool get isOutOfStock => currentStock <= 0;
  bool get isFaulty => status == 'FAULTY';
}