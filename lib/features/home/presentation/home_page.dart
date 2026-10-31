import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_sizes.dart';
import '../../catalog/data/catalog_repository.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import 'widgets/home_header.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/home_banner.dart';
import 'widgets/category_list.dart';
import 'widgets/popular_products.dart';
import 'widgets/insurance_banner.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';

class HomePage extends StatelessWidget {
  final VoidCallback? onNavigateToExplore;

  const HomePage({super.key, this.onNavigateToExplore});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) =>
              HomeBloc(repository: context.read<CatalogRepository>())
                ..add(LoadHomeData()),
      child: HomeView(onNavigateToExplore: onNavigateToExplore),
    );
  }
}

class HomeView extends StatelessWidget {
  final VoidCallback? onNavigateToExplore;

  const HomeView({super.key, this.onNavigateToExplore});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: BlocBuilder<HomeBloc, HomeState>(
          builder: (context, state) {
            final initialLoading =
                (state.status == HomeStatus.initial ||
                    state.status == HomeStatus.loading) &&
                state.popularProducts.isEmpty;

            if (initialLoading) {
              return Column(
                children: [
                  const Padding(
                    padding: EdgeInsets.all(AppSizes.pageMargin),
                    child: HomeHeader(),
                  ),
                  const Expanded(
                    child: SnapLoadingView(
                      message: 'Đang tải thiết bị cho bạn',
                      size: RetroCameraLoader.large,
                    ),
                  ),
                ],
              );
            }

            if (state.status == HomeStatus.error) {
              return const Center(child: Text('Đã có lỗi xảy ra'));
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.pageMargin),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.status == HomeStatus.loading && !initialLoading)
                    const SnapLoadingProgress(label: 'Đang làm mới thiết bị')
                  else
                    const SizedBox(height: 3),
                  const HomeHeader(),
                  const SizedBox(height: 24),
                  HomeSearchBar(onNavigateToExplore: onNavigateToExplore),
                  const SizedBox(height: 24),
                  const HomeBanner(),
                  const SizedBox(height: 12),
                  CategoryList(categories: state.categories),
                  const SizedBox(height: 12),
                  PopularProducts(
                    products: state.popularProducts,
                    totalProducts: state.totalProducts,
                    brands: state.brands, // Replace filter chip hardcode
                    onNavigateToExplore: onNavigateToExplore,
                  ),
                  const SizedBox(height: 24),
                  const InsuranceBanner(),
                  const SizedBox(height: 24), // padding for bottom
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
