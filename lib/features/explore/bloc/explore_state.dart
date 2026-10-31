import 'package:equatable/equatable.dart';
import '../../../domain/entities/product.dart';
import '../../../domain/entities/brand.dart';
import '../../../domain/entities/branch.dart';
import '../../../domain/entities/category.dart';

enum ExploreStatus { initial, loading, success, failure }
enum ExploreLoadMoreStatus { initial, loading, failure }

class ExploreState extends Equatable {
  final ExploreStatus status;
  final ExploreLoadMoreStatus loadMoreStatus;
  
  final String keyword;
  final String? categoryId;
  final String? brandId;
  final String? branchId;

  final List<Product> products;
  final int totalProducts;
  final int currentPage;
  final bool hasMore;

  final List<Brand> brands;
  final List<Branch> branches;
  final List<DeviceCategory> categories;

  const ExploreState({
    this.status = ExploreStatus.initial,
    this.loadMoreStatus = ExploreLoadMoreStatus.initial,
    this.keyword = '',
    this.categoryId,
    this.brandId,
    this.branchId,
    this.products = const [],
    this.totalProducts = 0,
    this.currentPage = 1,
    this.hasMore = true,
    this.brands = const [],
    this.branches = const [],
    this.categories = const [],
  });

  ExploreState copyWith({
    ExploreStatus? status,
    ExploreLoadMoreStatus? loadMoreStatus,
    String? keyword,
    String? categoryId,
    String? brandId,
    String? branchId,
    List<Product>? products,
    int? totalProducts,
    int? currentPage,
    bool? hasMore,
    List<Brand>? brands,
    List<Branch>? branches,
    List<DeviceCategory>? categories,
  }) {
    return ExploreState(
      status: status ?? this.status,
      loadMoreStatus: loadMoreStatus ?? this.loadMoreStatus,
      keyword: keyword ?? this.keyword,
      categoryId: categoryId ?? this.categoryId,
      brandId: brandId ?? this.brandId,
      branchId: branchId ?? this.branchId,
      products: products ?? this.products,
      totalProducts: totalProducts ?? this.totalProducts,
      currentPage: currentPage ?? this.currentPage,
      hasMore: hasMore ?? this.hasMore,
      brands: brands ?? this.brands,
      branches: branches ?? this.branches,
      categories: categories ?? this.categories,
    );
  }

  // To allow clearing nullable fields
  ExploreState clearCriteria({
    bool clearCategory = false,
    bool clearBrand = false,
    bool clearBranch = false,
  }) {
    return ExploreState(
      status: status,
      loadMoreStatus: loadMoreStatus,
      keyword: keyword,
      categoryId: clearCategory ? null : categoryId,
      brandId: clearBrand ? null : brandId,
      branchId: clearBranch ? null : branchId,
      products: products,
      totalProducts: totalProducts,
      currentPage: currentPage,
      hasMore: hasMore,
      brands: brands,
      branches: branches,
      categories: categories,
    );
  }

  @override
  List<Object?> get props => [
        status,
        loadMoreStatus,
        keyword,
        categoryId,
        brandId,
        branchId,
        products,
        totalProducts,
        currentPage,
        hasMore,
        brands,
        branches,
        categories,
      ];
}
