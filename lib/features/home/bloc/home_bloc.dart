import 'package:flutter_bloc/flutter_bloc.dart';
import '../../catalog/data/catalog_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final CatalogRepository repository;

  HomeBloc({required this.repository}) : super(const HomeState()) {
    on<LoadHomeData>(_onLoadHomeData);
  }

  Future<void> _onLoadHomeData(
    LoadHomeData event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(status: HomeStatus.loading));
    try {
      final categoriesFuture = repository.getCategories();
      final productsFuture = repository.getProducts(page: 1, pageSize: 20);
      final brandsFuture = repository.getBrands();

      final results = await Future.wait([categoriesFuture, productsFuture, brandsFuture]);

      final categories = results[0] as List<dynamic>;
      final productsData = results[1] as Map<String, dynamic>;
      final brands = results[2] as List<dynamic>;

      emit(
        state.copyWith(
          status: HomeStatus.loaded,
          categories: categories.cast(),
          popularProducts: productsData['products'],
          totalProducts: productsData['tongSo'],
          brands: brands.cast(),
        ),
      );
    } catch (e) {
      emit(state.copyWith(status: HomeStatus.error));
    }
  }
}
