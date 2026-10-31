abstract class CartEvent {
  const CartEvent();
}

class CartItemPeriodOrBranchChanged extends CartEvent {
  final String itemId;
  final DateTime? start, end;
  final String? branchId;
  const CartItemPeriodOrBranchChanged(
    this.itemId, {
    this.start,
    this.end,
    this.branchId,
  });
}

class CartCheckoutRequested extends CartEvent {
  const CartCheckoutRequested();
}

class CartSessionChanged extends CartEvent {
  const CartSessionChanged();
}

class CartItemAdded extends CartEvent {
  final String modelId, branchId;
  final int quantity;
  final DateTime start, end;
  const CartItemAdded(
    this.modelId,
    this.branchId,
    this.quantity,
    this.start,
    this.end,
  );
}

class CartStarted extends CartEvent {
  final bool isRefresh;

  const CartStarted({this.isRefresh = false});
}

class CartItemQuantityChanged extends CartEvent {
  final String cartItemId;
  final int quantity;

  const CartItemQuantityChanged({
    required this.cartItemId,
    required this.quantity,
  });
}

class CartItemSelectionToggled extends CartEvent {
  final String cartItemId;
  final bool isSelected;

  const CartItemSelectionToggled({
    required this.cartItemId,
    required this.isSelected,
  });
}

class CartItemRemoveRequested extends CartEvent {
  final String cartItemId;

  const CartItemRemoveRequested({required this.cartItemId});
}

class CartEditModeToggled extends CartEvent {
  const CartEditModeToggled();
}

class CartResetRequested extends CartEvent {
  const CartResetRequested();
}
