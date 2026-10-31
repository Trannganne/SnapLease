import '../../domain/models/cart_item_model.dart';
import '../../domain/repositories/cart_repository.dart';

class MockCartRepository extends CartRepository {
  final Duration networkDelay;

  MockCartRepository({this.networkDelay = const Duration(milliseconds: 350)}) {
    _initDefaultItems();
  }

  late List<CartItemModel> _items;

  void _initDefaultItems() {
    _items = [
      CartItemModel(
        id: 'mock_cart_item_1',
        branchId: 'CN_THU_DUC',
        branchName: 'LensGo Thủ Đức',
        modelId: 'sony-alpha-a7-iv',
        modelName: 'Sony Alpha A7 IV',
        imageUrl: 'assets/images/camera.png',
        dailyPrice: 850000,
        depositPrice: 3500000,
        startDate: DateTime(2026, 9, 18, 9, 0),
        endDate: DateTime(2026, 9, 21, 18, 0),
        rentalDays: 3,
        quantity: 1,
        maxAvailable: 5,
        isSelected: true,
        isAvailable: true,
      ),
      CartItemModel(
        id: 'mock_cart_item_2',
        branchId: 'CN_THU_DUC',
        branchName: 'LensGo Thủ Đức',
        modelId: 'sony-fe-24-70mm-f2-8-gm',
        modelName: 'Sony FE 24-70mm F2.8 GM',
        imageUrl: 'assets/images/lens.png',
        dailyPrice: 300000,
        depositPrice: 1500000,
        startDate: DateTime(2026, 9, 18, 9, 0),
        endDate: DateTime(2026, 9, 21, 18, 0),
        rentalDays: 3,
        quantity: 1,
        maxAvailable: 4,
        isSelected: true,
        isAvailable: true,
      ),
    ];
  }

  @override
  Future<List<CartItemModel>> getCartItems({bool forceRefresh = false}) async {
    if (networkDelay > Duration.zero) {
      await Future.delayed(networkDelay);
    }
    return List<CartItemModel>.from(_items);
  }

  @override
  Future<CartItemModel> updateQuantity({
    required String cartItemId,
    required int quantity,
  }) async {
    if (networkDelay > Duration.zero) {
      await Future.delayed(networkDelay);
    }
    final index = _items.indexWhere((i) => i.id == cartItemId);
    if (index == -1) {
      throw Exception('Không tìm thấy thiết bị trong giỏ hàng');
    }

    final item = _items[index];
    final validQuantity =
        quantity < 1
            ? 1
            : (item.maxAvailable != null && quantity > item.maxAvailable!)
            ? item.maxAvailable!
            : quantity;

    final updated = item.copyWith(quantity: validQuantity);
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> removeItem({required String cartItemId}) async {
    if (networkDelay > Duration.zero) {
      await Future.delayed(networkDelay);
    }
    _items.removeWhere((i) => i.id == cartItemId);
  }

  @override
  Future<CartItemModel> toggleItemSelection({
    required String cartItemId,
    required bool isSelected,
  }) async {
    if (networkDelay > Duration.zero) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
    final index = _items.indexWhere((i) => i.id == cartItemId);
    if (index == -1) {
      throw Exception('Không tìm thấy thiết bị trong giỏ hàng');
    }

    final item = _items[index];
    if (!item.isAvailable && isSelected) {
      // Cannot select unavailable items
      return item;
    }

    final updated = item.copyWith(isSelected: isSelected);
    _items[index] = updated;
    return updated;
  }

  @override
  Future<void> clearCart() async {
    if (networkDelay > Duration.zero) {
      await Future.delayed(networkDelay);
    }
    _items.clear();
  }

  void resetToDefault() {
    _initDefaultItems();
  }
}
