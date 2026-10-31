import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../explore/bloc/explore_bloc.dart';
import '../../../explore/bloc/explore_event.dart';
import 'search_filter_bottom_sheet.dart';

class HomeSearchBar extends StatelessWidget {
  final VoidCallback? onNavigateToExplore;

  const HomeSearchBar({super.key, this.onNavigateToExplore});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) {
                  context.read<ExploreBloc>().add(
                    ExploreCriteriaChanged(keyword: value.trim()),
                  );
                  if (onNavigateToExplore != null) {
                    onNavigateToExplore!();
                  }
                }
              },
              decoration: InputDecoration(
                hintText: 'Tìm máy ảnh, ống kính...',
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          height: 48,
          width: 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              Icons.tune,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            onPressed: () {
              final exploreBloc = context.read<ExploreBloc>();
              // Show bottom sheet using data from ExploreBloc state
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) {
                  return SearchFilterBottomSheet(
                    initialCategoryId: exploreBloc.state.categoryId,
                    initialBranchId: exploreBloc.state.branchId,
                    categories: exploreBloc.state.categories,
                    branches: exploreBloc.state.branches,
                    onApply: (categoryId, branchId) {
                      exploreBloc.add(
                        ExploreCriteriaChanged(
                          categoryId: categoryId,
                          branchId: branchId,
                        ),
                      );
                      if (onNavigateToExplore != null) {
                        onNavigateToExplore!();
                      }
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
