import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router/app_router.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../home/presentation/widgets/home_search_bar.dart';
import '../../home/presentation/widgets/product_card.dart';
import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';
import '../../cart/bloc/cart_bloc.dart';
import '../../cart/bloc/cart_state.dart';
import '../bloc/explore_bloc.dart';
import '../bloc/explore_event.dart';
import '../bloc/explore_state.dart';

class ExplorePage extends StatefulWidget {
  const ExplorePage({super.key});

  @override
  State<ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends State<ExplorePage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ExploreBloc>().add(ExploreLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: const AppText(
          'Khám phá',
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 0,
        actions: [
          BlocBuilder<CartBloc, CartState>(
            builder: (context, cartState) {
              final count = cartState.totalLinesCount;
              return IconButton(
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text('$count'),
                  child: Icon(
                    Icons.shopping_bag,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                onPressed: () => context.push(AppRouter.cart),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.pageMargin,
              ),
              child: const HomeSearchBar(),
            ),
            const SizedBox(height: 16),
            _buildBrandsFilter(),
            const SizedBox(height: 8),
            _buildResultsHeader(),
            Expanded(child: _buildProductList()),
          ],
        ),
      ),
    );
  }

  Widget _buildBrandsFilter() {
    return BlocBuilder<ExploreBloc, ExploreState>(
      builder: (context, state) {
        if (state.brands.isEmpty) return const SizedBox.shrink();

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.pageMargin),
          child: Row(
            children: [
              _buildBrandChip(
                label: 'Tất cả',
                isSelected: state.brandId == null,
                onTap: () {
                  context.read<ExploreBloc>().add(
                    const ExploreCriteriaChanged(brandId: null),
                  );
                },
              ),
              ...state.brands.map((brand) {
                return _buildBrandChip(
                  label: brand.name,
                  isSelected: state.brandId == brand.id,
                  onTap: () {
                    context.read<ExploreBloc>().add(
                      ExploreCriteriaChanged(brandId: brand.id),
                    );
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBrandChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: ChoiceChip(
        label: AppText(
          label,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          color:
              isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
        ),
        selected: isSelected,
        selectedColor: Theme.of(context).colorScheme.primary,
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
          ),
        ),
        onSelected: (_) => onTap(),
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }

  Widget _buildResultsHeader() {
    return BlocBuilder<ExploreBloc, ExploreState>(
      builder: (context, state) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.pageMargin,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppText(
                'Kết quả tìm kiếm',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              AppText(
                '${state.totalProducts} thiết bị',
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductList() {
    return BlocBuilder<ExploreBloc, ExploreState>(
      builder: (context, state) {
        if ((state.status == ExploreStatus.initial ||
                state.status == ExploreStatus.loading) &&
            state.products.isEmpty) {
          return const SnapLoadingView(
            message: 'Đang tìm thiết bị phù hợp',
            size: RetroCameraLoader.large,
          );
        }

        if (state.status == ExploreStatus.failure && state.products.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const AppText('Đã có lỗi xảy ra'),
                TextButton(
                  onPressed:
                      () => context.read<ExploreBloc>().add(ExploreRetry()),
                  child: const AppText('Thử lại'),
                ),
              ],
            ),
          );
        }

        if (state.products.isEmpty) {
          return const Center(
            child: AppText('Không tìm thấy thiết bị nào phù hợp'),
          );
        }

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSizes.pageMargin),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  return ProductCard(product: state.products[index]);
                }, childCount: state.products.length),
              ),
            ),
            if (state.loadMoreStatus == ExploreLoadMoreStatus.loading)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            if (state.loadMoreStatus == ExploreLoadMoreStatus.failure)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: TextButton(
                      onPressed:
                          () => context.read<ExploreBloc>().add(ExploreRetry()),
                      child: const AppText('Tải thêm thất bại. Thử lại'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
