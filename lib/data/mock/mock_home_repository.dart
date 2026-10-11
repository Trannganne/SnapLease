import '../../domain/entities/product.dart';
import '../../domain/entities/category.dart';

class MockHomeRepository {
  Future<List<DeviceCategory>> getCategories() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      DeviceCategory(
        id: 'c1',
        name: 'Máy ảnh',
        subtitle: 'Mirrorless, DSLR',
        iconPath: 'assets/images/camera.png', // Fallback icon path if needed
      ),
      DeviceCategory(
        id: 'c2',
        name: 'Ống kính',
        subtitle: 'Zoom, Prime, Cine',
        iconPath: 'assets/images/lens.png',
      ),
      DeviceCategory(
        id: 'c3',
        name: 'Phụ kiện',
        subtitle: 'Gimbal, Mic, Đèn',
        iconPath: 'assets/images/screen.png',
      ),
    ];
  }

  Future<List<Product>> getPopularProducts(
    String categoryFilter,
    String branchFilter,
  ) async {
    await Future.delayed(const Duration(milliseconds: 500));
    final products = [
      Product(
        id: 'p1',
        name: 'Sony Alpha A7 IV Body',
        image: 'assets/images/camera.png',
        rating: 4.9,
        reviewCount: 128,
        pricePerDay: '350.000đ/ngày',
        available: true,
        category: 'Mirrorless',
        branchIds: ['Quận 1', 'Quận 3'],
      ),
      Product(
        id: 'p2',
        name: 'Canon EOS R5 Body',
        image: 'assets/images/camera.png',
        rating: 4.8,
        reviewCount: 96,
        pricePerDay: '450.000đ/ngày',
        available: true,
        category: 'Mirrorless',
        branchIds: ['Quận 7'],
      ),
      Product(
        id: 'p3',
        name: 'Sony FE 24-70mm F/2.8 GM II',
        image: 'assets/images/lens.png',
        rating: 4.9,
        reviewCount: 112,
        pricePerDay: '280.000đ/ngày',
        available: true,
        category: 'Ống kính',
        branchIds: ['Quận 1', 'Quận 7', 'Bình Thạnh'],
      ),
      Product(
        id: 'p4',
        name: 'DJI RS 3 Pro Combo Gimbal',
        image: 'assets/images/screen.png',
        rating: 4.8,
        reviewCount: 64,
        pricePerDay: '250.000đ/ngày',
        available: true,
        category: 'Phụ kiện',
        branchIds: ['Quận 3', 'Bình Thạnh'],
      ),
    ];

    return products.where((p) {
      final matchesCategory =
          categoryFilter == 'Tất cả' ||
          p.category == categoryFilter ||
          p.name.contains(categoryFilter);
      final matchesBranch =
          branchFilter == 'Tất cả' || p.branchIds.contains(branchFilter);
      return matchesCategory && matchesBranch;
    }).toList();
  }
}
