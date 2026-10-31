import '../domain/models/cart_branch_group_model.dart';
import '../domain/models/cart_item_model.dart';
import '../domain/models/cart_summary_model.dart';

enum CartStatus { initial, loading, loaded, failure }

class CartState {
  final CartStatus status;
  final List<CartItemModel> items;
  final bool isEditMode;
  final bool isRefreshing;
  final Set<String> updatingItemIds;
  final String? errorMessage;
  final bool checkingOut;
  final Map<String, dynamic>? checkout;

  const CartState({
    this.status = CartStatus.initial,
    this.items = const [],
    this.isEditMode = false,
    this.isRefreshing = false,
    this.updatingItemIds = const {},
    this.errorMessage,
    this.checkingOut = false,
    this.checkout,
  });

  CartSummaryModel get summary => CartSummaryModel.fromItems(items);

  int get totalLinesCount => items.length;

  int get selectedLinesCount =>
      items.where((i) => i.isSelected && i.isAvailable).length;

  bool get isEmpty => items.isEmpty;

  List<CartBranchGroupModel> get branchGroups {
    final Map<String, List<CartItemModel>> map = {};
    for (final item in items) {
      map.putIfAbsent(item.branchId, () => []).add(item);
    }
    return map.entries.map((entry) {
      final branchItems = entry.value;
      return CartBranchGroupModel(
        branchId: entry.key,
        branchName: branchItems.first.branchName,
        items: branchItems,
      );
    }).toList();
  }

  CartState copyWith({
    CartStatus? status,
    List<CartItemModel>? items,
    bool? isEditMode,
    bool? isRefreshing,
    Set<String>? updatingItemIds,
    String? errorMessage,
    bool? checkingOut,
    Map<String, dynamic>? checkout,
  }) {
    return CartState(
      status: status ?? this.status,
      items: items ?? this.items,
      isEditMode: isEditMode ?? this.isEditMode,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      updatingItemIds: updatingItemIds ?? this.updatingItemIds,
      errorMessage: errorMessage,
      checkingOut: checkingOut ?? this.checkingOut,
      checkout: checkout,
    );
  }
}
