import 'cart_item_model.dart';

class CartBranchGroupModel {
  final String branchId;
  final String branchName;
  final List<CartItemModel> items;

  const CartBranchGroupModel({
    required this.branchId,
    required this.branchName,
    required this.items,
  });

  int get totalItemCount => items.length;

  int get selectedItemCount => items.where((item) => item.isSelected).length;

  int get totalQuantity => items.fold(0, (sum, item) => sum + item.quantity);

  int get selectedQuantity => items
      .where((item) => item.isSelected)
      .fold(0, (sum, item) => sum + item.quantity);

  num get selectedTotalPrice => items
      .where((item) => item.isSelected)
      .fold<num>(0, (sum, item) => sum + item.itemTotalPrice);

  num? get selectedTotalDeposit {
    final selectedItems = items.where((item) => item.isSelected).toList();
    if (selectedItems.isEmpty) return 0;
    num sum = 0;
    for (final item in selectedItems) {
      if (item.depositPrice == null) {
        return null; // Deposit cannot be fully determined
      }
      sum += item.itemTotalDeposit!;
    }
    return sum;
  }
}
