import 'cart_item_model.dart';

class CartSummaryModel {
  final num totalRentalPrice;
  final num? totalDeposit;
  final int selectedLinesCount;
  final int totalLinesCount;
  final int selectedTotalUnits;

  const CartSummaryModel({
    required this.totalRentalPrice,
    required this.totalDeposit,
    required this.selectedLinesCount,
    required this.totalLinesCount,
    required this.selectedTotalUnits,
  });

  bool get canCheckout => selectedLinesCount > 0;

  factory CartSummaryModel.fromItems(List<CartItemModel> items) {
    final selectedItems =
        items.where((i) => i.isSelected && i.isAvailable).toList();

    num rentalPrice = 0;
    num? depositPrice = 0;
    int selectedUnits = 0;

    for (final item in selectedItems) {
      rentalPrice += item.itemTotalPrice;
      selectedUnits += item.quantity;

      if (depositPrice != null) {
        if (item.depositPrice != null) {
          depositPrice += item.itemTotalDeposit!;
        } else {
          depositPrice = null; // Undetermined deposit data
        }
      }
    }

    return CartSummaryModel(
      totalRentalPrice: rentalPrice,
      totalDeposit: selectedItems.isEmpty ? 0 : depositPrice,
      selectedLinesCount: selectedItems.length,
      totalLinesCount: items.length,
      selectedTotalUnits: selectedUnits,
    );
  }

  static const CartSummaryModel empty = CartSummaryModel(
    totalRentalPrice: 0,
    totalDeposit: 0,
    selectedLinesCount: 0,
    totalLinesCount: 0,
    selectedTotalUnits: 0,
  );
}
