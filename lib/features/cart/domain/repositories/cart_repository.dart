import '../models/cart_item_model.dart';
import '../../../../domain/entities/device_detail.dart';

abstract class CartRepository {
  Future<List<BranchAvailability>> branchOptions(String modelId) =>
      throw UnsupportedError('Preview');
  Future<CartItemModel> addItem({
    required String modelId,
    required String branchId,
    required int quantity,
    required DateTime start,
    required DateTime end,
  }) => throw UnsupportedError('Preview');
  Future<CartItemModel> updateItem(
    CartItemModel item, {
    DateTime? start,
    DateTime? end,
    String? branchId,
  }) => throw UnsupportedError('Preview');
  Future<Map<String, dynamic>> checkout(List<CartItemModel> items) =>
      throw UnsupportedError('Preview');
  void invalidateSession() {}
  Future<List<CartItemModel>> getCartItems({bool forceRefresh = false});

  Future<CartItemModel> updateQuantity({
    required String cartItemId,
    required int quantity,
  });

  Future<void> removeItem({required String cartItemId});

  Future<CartItemModel> toggleItemSelection({
    required String cartItemId,
    required bool isSelected,
  });

  Future<void> clearCart();
}
