import '../../../domain/entities/product.dart';
import '../../../domain/entities/category.dart';
import '../../../domain/entities/brand.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState {
  final HomeStatus status;
  final List<DeviceCategory> categories;
  final List<Product> popularProducts;
  final int totalProducts;
  final List<Brand> brands;

  const HomeState({
    this.status = HomeStatus.initial,
    this.categories = const [],
    this.popularProducts = const [],
    this.totalProducts = 0,
    this.brands = const [],
  });

  HomeState copyWith({
    HomeStatus? status,
    List<DeviceCategory>? categories,
    List<Product>? popularProducts,
    int? totalProducts,
    List<Brand>? brands,
  }) {
    return HomeState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      popularProducts: popularProducts ?? this.popularProducts,
      totalProducts: totalProducts ?? this.totalProducts,
      brands: brands ?? this.brands,
    );
  }
}
