import 'package:flutter_bloc/flutter_bloc.dart';
import '../../catalog/data/catalog_repository.dart';
import 'explore_event.dart';
import 'explore_state.dart';

class ExploreBloc extends Bloc<ExploreEvent, ExploreState> {
  final CatalogRepository _repository;
  int _currentRequestId = 0;

  ExploreBloc({required CatalogRepository repository})
      : _repository = repository,
        super(const ExploreState()) {
    on<ExploreCriteriaChanged>(_onCriteriaChanged);
    on<ExploreLoadMore>(_onLoadMore);
    on<ExploreRetry>(_onRetry);
  }

  Future<void> _onCriteriaChanged(
    ExploreCriteriaChanged event,
    Emitter<ExploreState> emit,
  ) async {
    final requestId = ++_currentRequestId;
    
    // Clear old state completely, show loading
    var newState = state.clearCriteria(
      clearCategory: event.categoryId == null,
      clearBrand: event.brandId == null,
      clearBranch: event.branchId == null,
    ).copyWith(
      status: ExploreStatus.loading,
      keyword: event.keyword ?? '',
      categoryId: event.categoryId,
      brandId: event.brandId,
      branchId: event.branchId,
      products: [],
      currentPage: 1,
      hasMore: true,
      totalProducts: 0,
    );
    emit(newState);

    try {
      // Parallel loading if brands/branches/categories are not loaded yet
      Future<List<dynamic>>? brandsFuture;
      Future<List<dynamic>>? branchesFuture;
      Future<List<dynamic>>? categoriesFuture;

      if (state.brands.isEmpty) {
        brandsFuture = _repository.getBrands();
      }
      if (state.branches.isEmpty) {
        branchesFuture = _repository.getBranches();
      }
      if (state.categories.isEmpty) {
        categoriesFuture = _repository.getCategories();
      }

      final productsFuture = _repository.getProducts(
        keyword: newState.keyword,
        categoryId: newState.categoryId,
        brandId: newState.brandId,
        branchId: newState.branchId,
        page: 1,
        pageSize: 20,
      );

      final results = await Future.wait([
        productsFuture,
        if (brandsFuture != null) brandsFuture else Future.value(state.brands),
        if (branchesFuture != null) branchesFuture else Future.value(state.branches),
        if (categoriesFuture != null) categoriesFuture else Future.value(state.categories),
      ]);

      if (_currentRequestId != requestId) return; // Ignore old response

      final productsData = results[0] as Map<String, dynamic>;
      final fetchedBrands = results[1] as List<dynamic>;
      final fetchedBranches = results[2] as List<dynamic>;
      final fetchedCategories = results[3] as List<dynamic>;

      final newProducts = (productsData['products'] as List<dynamic>).cast<dynamic>();
      final tongSo = productsData['tongSo'] as int;

      emit(newState.copyWith(
        status: ExploreStatus.success,
        products: newProducts.cast(),
        totalProducts: tongSo,
        brands: fetchedBrands.cast(),
        branches: fetchedBranches.cast(),
        categories: fetchedCategories.cast(),
        hasMore: newProducts.length < tongSo && newProducts.isNotEmpty,
      ));
    } catch (e) {
      if (_currentRequestId != requestId) return;
      emit(newState.copyWith(status: ExploreStatus.failure));
    }
  }

  Future<void> _onLoadMore(
    ExploreLoadMore event,
    Emitter<ExploreState> emit,
  ) async {
    if (state.status != ExploreStatus.success || 
        state.loadMoreStatus == ExploreLoadMoreStatus.loading || 
        !state.hasMore) {
      return;
    }

    final requestId = ++_currentRequestId;
    emit(state.copyWith(loadMoreStatus: ExploreLoadMoreStatus.loading));

    try {
      final nextPage = state.currentPage + 1;
      final productsData = await _repository.getProducts(
        keyword: state.keyword,
        categoryId: state.categoryId,
        brandId: state.brandId,
        branchId: state.branchId,
        page: nextPage,
        pageSize: 20,
      );

      if (_currentRequestId != requestId) return;

      final fetchedProducts = (productsData['products'] as List<dynamic>).cast<dynamic>();
      final tongSo = productsData['tongSo'] as int;

      // Prevent duplicates by checking ID
      final existingIds = state.products.map((p) => p.id).toSet();
      final newUniqueProducts = fetchedProducts.where((p) => !existingIds.contains(p.id)).toList();

      final combinedProducts = List.of(state.products)..addAll(newUniqueProducts.cast());

      emit(state.copyWith(
        loadMoreStatus: ExploreLoadMoreStatus.initial,
        products: combinedProducts.cast(),
        currentPage: nextPage,
        totalProducts: tongSo,
        hasMore: combinedProducts.length < tongSo && fetchedProducts.isNotEmpty,
      ));
    } catch (e) {
      if (_currentRequestId != requestId) return;
      emit(state.copyWith(loadMoreStatus: ExploreLoadMoreStatus.failure));
    }
  }

  Future<void> _onRetry(
    ExploreRetry event,
    Emitter<ExploreState> emit,
  ) async {
    if (state.status == ExploreStatus.failure) {
      // Retry initial load
      add(ExploreCriteriaChanged(
        keyword: state.keyword,
        categoryId: state.categoryId,
        brandId: state.brandId,
        branchId: state.branchId,
      ));
    } else if (state.loadMoreStatus == ExploreLoadMoreStatus.failure) {
      // Retry load more
      add(ExploreLoadMore());
    }
  }
}
