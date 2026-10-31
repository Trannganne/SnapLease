import '../../../core/widgets/snap_loading_view.dart';
import '../../../core/widgets/retro_camera_loader.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/widgets/app_text.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/user_avatar.dart';
import '../bloc/notification_bloc.dart';
import '../bloc/notification_event.dart';
import '../bloc/notification_state.dart';
import '../data/repositories/notification_repository.dart';
import '../domain/models/notification_item_model.dart';
import 'widgets/notification_card.dart';
import 'widgets/notification_empty_view.dart';
import 'widgets/notification_filter_chips.dart';
import 'widgets/notification_security_card.dart';
import 'package:rentcam/core/navigation/app_route_observer.dart';

class NotificationPage extends StatelessWidget {
  final NotificationRepository? repository;

  const NotificationPage({super.key, this.repository});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create:
          (context) => NotificationBloc(
            repository: repository ?? DioNotificationRepository(),
          )..add(const NotificationLoadStarted()),
      child: const NotificationView(),
    );
  }
}

class NotificationView extends StatefulWidget {
  const NotificationView({super.key});

  @override
  State<NotificationView> createState() => _NotificationViewState();
}

class _NotificationViewState extends State<NotificationView>
    with WidgetsBindingObserver, RouteAware {
  final ScrollController _scrollController = ScrollController();
  ModalRoute<dynamic>? _route;
  bool? _visible;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (_route != route) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      if (route != null) appRouteObserver.subscribe(this, route);
    }
    final visible = TickerMode.of(context);
    if (_visible == false && visible) _refresh();
    _visible = visible;
  }

  void _refresh() {
    if (mounted) {
      context.read<NotificationBloc>().add(
        const NotificationLoadStarted(isRefresh: true),
      );
    }
  }

  @override
  void didPopNext() => _refresh();
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _visible == true &&
        (_route?.isCurrent ?? true)) {
      _refresh();
    }
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<NotificationBloc>().add(const NotificationLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: BlocConsumer<NotificationBloc, NotificationState>(
          listener: (context, state) {
            if (state.userNotice != null && state.userNotice!.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.userNotice!),
                  duration: const Duration(seconds: 3),
                ),
              );
            }
          },
          builder: (context, state) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                NotificationFilterChips(
                  selectedCategory: state.selectedCategory,
                  totalCount: state.totalCount,
                  unreadCount: state.totalUnreadCount,
                  onCategorySelected: (category) {
                    context.read<NotificationBloc>().add(
                      NotificationCategoryChanged(category),
                    );
                  },
                ),
                const SizedBox(height: 4),
                if (state.items.isNotEmpty &&
                    (state.status == NotificationStatus.loading ||
                        state.isRefreshing))
                  const SnapLoadingProgress(label: 'Đang làm mới thông báo')
                else
                  const SizedBox(height: 3),
                Expanded(child: _buildBody(context, state)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.pageMargin,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color:
                      theme.brightness == Brightness.dark
                          ? Colors.white.withValues(alpha: 0.92)
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Image.asset('assets/images/logo.png', height: 24),
              ),
              const SizedBox(width: 8),
              AppText(
                'Thông báo',
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ],
          ),
          const UserAvatar(displayName: 'U', radius: 16),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, NotificationState state) {
    if ((state.status == NotificationStatus.initial ||
            state.status == NotificationStatus.loading) &&
        state.items.isEmpty) {
      return const SnapLoadingView(
        message: 'Đang tải thông báo',
        size: RetroCameraLoader.large,
      );
    }

    if (state.status == NotificationStatus.failure) {
      return _buildErrorView(context, state.errorMessage);
    }

    final groups = state.dateGroups;

    if (groups.isEmpty) {
      return NotificationEmptyView(
        category: state.selectedCategory,
        onReload: () {
          context.read<NotificationBloc>().add(const NotificationLoadStarted());
        },
      );
    }

    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: () async {
        context.read<NotificationBloc>().add(
          const NotificationLoadStarted(isRefresh: true),
        );
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.pageMargin,
          vertical: 8,
        ),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (groups.today.isNotEmpty)
            _buildGroupSection(
              context,
              title: 'HÔM NAY',
              unreadCount: groups.todayUnread,
              isFullListMode:
                  state.selectedCategory == NotificationCategory.all,
              items: groups.today,
            ),
          if (groups.yesterday.isNotEmpty)
            _buildGroupSection(
              context,
              title: 'HÔM QUA',
              unreadCount: groups.yesterdayUnread,
              isFullListMode:
                  state.selectedCategory == NotificationCategory.all,
              items: groups.yesterday,
            ),
          if (groups.earlier.isNotEmpty)
            _buildGroupSection(
              context,
              title: 'TRƯỚC ĐÓ',
              unreadCount: groups.earlierUnread,
              isFullListMode:
                  state.selectedCategory == NotificationCategory.all,
              items: groups.earlier,
            ),
          if (state.loadMoreStatus == NotificationLoadMoreStatus.loading) ...[
            const SizedBox(height: 12),
            Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          const NotificationSecurityCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildGroupSection(
    BuildContext context, {
    required String title,
    required int unreadCount,
    required bool isFullListMode,
    required List<NotificationItemModel> items,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText(
                  title,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
                if (isFullListMode && unreadCount > 0)
                  AppText(
                    '$unreadCount mới',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
              ],
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            NotificationCard(
              item: items[i],
              onTap: () => _handleCardTap(items[i]),
              onActionTap:
                  items[i].actionText != null
                      ? () => _handleActionTap(items[i])
                      : null,
            ),
            if (i < items.length - 1) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Future<void> _handleCardTap(NotificationItemModel item) async {
    try {
      final wasRead = await context.push<bool>(
        '/notification/${item.id}',
        extra: item,
      );
      if (!mounted) return;
      if (wasRead == true) {
        context.read<NotificationBloc>().add(
          NotificationItemReadSynced(item.id),
        );
      }
    } catch (_) {
      if (!item.isRead && mounted) {
        context.read<NotificationBloc>().add(NotificationMarkAsRead(item.id));
      }
    }
  }

  Future<void> _handleActionTap(NotificationItemModel item) async {
    try {
      final wasRead = await context.push<bool>(
        '/notification/${item.id}',
        extra: item,
      );
      if (!mounted) return;
      if (wasRead == true) {
        context.read<NotificationBloc>().add(
          NotificationItemReadSynced(item.id),
        );
      }
    } catch (_) {
      if (!item.isRead && mounted) {
        context.read<NotificationBloc>().add(NotificationMarkAsRead(item.id));
      }
    }
  }

  Widget _buildErrorView(BuildContext context, String? errorMessage) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: colorScheme.error.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: 32,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 16),
            AppText(
              errorMessage ?? 'Đã có lỗi xảy ra',
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            AppText(
              'Không thể kết nối đến máy chủ thông báo. Vui lòng thử lại sau.',
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 140,
              child: PrimaryButton(
                text: 'Thử lại',
                onPressed: () {
                  context.read<NotificationBloc>().add(
                    const NotificationLoadStarted(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
