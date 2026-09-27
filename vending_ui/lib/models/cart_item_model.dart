import 'slot_model.dart';

class CartItemModel {
  final SlotModel slot;
  int quantity;

  CartItemModel({
    required this.slot,
    this.quantity = 1,
  });

  double get totalPrice => slot.price * quantity;
}