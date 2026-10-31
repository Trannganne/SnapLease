import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/core/theme/app_theme.dart';
import 'package:rentcam/core/widgets/primary_button.dart';
import 'package:rentcam/core/widgets/retro_camera_loader.dart';
import 'package:rentcam/core/widgets/snap_loading_view.dart';
import 'package:rentcam/core/widgets/snap_skeleton.dart';
import 'package:rentcam/domain/entities/product.dart';
import 'package:rentcam/features/catalog/data/catalog_repository.dart';
import 'package:rentcam/features/cart/bloc/cart_bloc.dart';
import 'package:rentcam/features/cart/data/repositories/mock_cart_repository.dart';
import 'package:rentcam/features/home/bloc/home_bloc.dart';
import 'package:rentcam/features/home/bloc/home_state.dart';
import 'package:rentcam/features/home/presentation/home_page.dart';
import 'package:rentcam/features/home/presentation/widgets/product_card.dart';
import 'package:rentcam/features/home/presentation/widgets/product_card_skeleton.dart';
import 'package:rentcam/features/explore/bloc/explore_bloc.dart';
import 'package:rentcam/features/explore/bloc/explore_state.dart';
import 'package:rentcam/features/explore/presentation/explore_page.dart';
import 'package:rentcam/features/contract/data/contract_list_repository.dart';
import 'package:rentcam/features/contract/domain/models/contract_summary_model.dart';
import 'package:rentcam/features/contract/presentation/list/bloc/contract_list_bloc.dart';
import 'package:rentcam/features/contract/presentation/list/bloc/contract_list_state.dart';
import 'package:rentcam/features/contract/presentation/list/contract_list_page.dart';
import 'package:rentcam/features/contract/presentation/list/widgets/contract_card_skeleton.dart';
import 'package:rentcam/features/notification/bloc/notification_bloc.dart';
import 'package:rentcam/features/notification/bloc/notification_state.dart';
import 'package:rentcam/features/notification/data/repositories/notification_repository.dart';
import 'package:rentcam/features/notification/domain/models/notification_item_model.dart';
import 'package:rentcam/features/notification/presentation/notification_page.dart';
import 'package:rentcam/features/notification/presentation/widgets/notification_card.dart';
import 'package:rentcam/features/notification/presentation/widgets/notification_item_skeleton.dart';

Widget app(Widget child, {bool dark = false, bool reduced = false}) =>
    MaterialApp(
      themeAnimationDuration: Duration.zero,
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: child,
      ),
    );

final product = Product(
  id: 'p',
  name: 'Test camera',
  image: '',
  rating: 5,
  reviewCount: 2,
  pricePerDay: '100.000đ/ngày',
  available: true,
);

void main() {
  testWidgets(
    'Skeletons fit small screens in both themes and stop for reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      for (final dark in [false, true]) {
        for (final child in [
          const ProductLoadingGrid(),
          SnapSkeleton(
            label: 'Đang tải',
            child: ListView(
              children: const [
                ContractCardSkeleton(),
                NotificationItemSkeleton(),
              ],
            ),
          ),
        ]) {
          await tester.pumpWidget(app(Scaffold(body: child), dark: dark));
          await tester.pump(const Duration(milliseconds: 800));
          expect(tester.takeException(), isNull);
          expect(tester.binding.transientCallbackCount, 1);
          expect(find.byType(ElevatedButton), findsNothing);
          await tester.pumpWidget(
            app(Scaffold(body: child), dark: dark, reduced: true),
          );
          await tester.pump();
          expect(tester.binding.transientCallbackCount, 0);
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );

  testWidgets(
    'PrimaryButton keeps label, disables duplicate taps, restores content',
    (tester) async {
      var taps = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        app(
          Scaffold(
            body: PrimaryButton(
              text: 'Gửi đánh giá',
              isLoading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 1200));
      expect(find.byType(SnapButtonLoader), findsOneWidget);
      expect(find.bySemanticsLabel('Gửi đánh giá. Đang xử lý'), findsOneWidget);
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 0);
      await tester.pumpWidget(
        app(
          Scaffold(
            body: PrimaryButton(text: 'Gửi đánh giá', onPressed: () => taps++),
          ),
        ),
      );
      await tester.tap(find.byType(ElevatedButton));
      expect(taps, 1);
      expect(find.byType(SnapButtonLoader), findsNothing);
      // Give the button ink/pressed-state transition its initial frame.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(tester.binding.transientCallbackCount, 0);
      semantics.dispose();
    },
  );

  testWidgets(
    'Home initial camera, content retained on refresh, error removes loader',
    (tester) async {
      final home = _Home();
      final cart = CartBloc(repository: MockCartRepository());
      addTearDown(home.close);
      addTearDown(cart.close);
      await tester.pumpWidget(
        app(
          MultiBlocProvider(
            providers: [
              BlocProvider<HomeBloc>.value(value: home),
              BlocProvider<CartBloc>.value(value: cart),
            ],
            child: const HomeView(),
          ),
        ),
      );
      expect(find.byType(SnapLoadingView), findsOneWidget);
      home.show(
        HomeState(status: HomeStatus.loaded, popularProducts: [product]),
      );
      await tester.pump();
      expect(find.byType(ProductCard), findsOneWidget);
      home.show(
        HomeState(status: HomeStatus.loading, popularProducts: [product]),
      );
      await tester.pump();
      expect(find.byType(SnapLoadingView), findsNothing);
      expect(find.byType(ProductCard), findsOneWidget);
      expect(find.byType(SnapLoadingProgress), findsOneWidget);
      home.show(const HomeState(status: HomeStatus.error));
      await tester.pump();
      expect(find.byType(SnapLoadingProgress), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Explore camera transitions to content and retry error', (
    tester,
  ) async {
    final explore = _Explore();
    final cart = CartBloc(repository: MockCartRepository());
    addTearDown(explore.close);
    addTearDown(cart.close);
    await tester.pumpWidget(
      app(
        MultiBlocProvider(
          providers: [
            BlocProvider<ExploreBloc>.value(value: explore),
            BlocProvider<CartBloc>.value(value: cart),
          ],
          child: const ExplorePage(),
        ),
      ),
    );
    expect(find.byType(SnapLoadingView), findsOneWidget);
    explore.show(
      ExploreState(status: ExploreStatus.success, products: [product]),
    );
    await tester.pump();
    expect(find.byType(ProductCard), findsOneWidget);
    explore.show(const ExploreState(status: ExploreStatus.failure));
    await tester.pump();
    expect(find.byType(SnapLoadingView), findsNothing);
    expect(find.byType(TextButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Contract camera, real content retained on refresh, error', (
    tester,
  ) async {
    final bloc = _Contracts();
    addTearDown(bloc.close);
    await tester.pumpWidget(
      app(
        BlocProvider<ContractListBloc>.value(
          value: bloc,
          child: const ContractListView(),
        ),
      ),
    );
    expect(find.byType(SnapLoadingView), findsOneWidget);
    final contracts = [
      ContractSummaryModel(
        id: 'HD-LOADING',
        status: ContractStatus.completed,
        imagePath: '',
        deviceName: 'Test camera',
        packageInfo: '1 máy',
        pickupDate: DateTime(2026, 10, 1),
        returnDate: DateTime(2026, 10, 2),
        branchName: 'HCM',
        totalAmount: 100000,
      ),
    ];
    bloc.show(
      ContractListState(
        status: ContractListStatus.loaded,
        allContracts: contracts,
      ),
    );
    await tester.pump();
    expect(find.text('HD-LOADING'), findsOneWidget);
    bloc.show(
      ContractListState(
        status: ContractListStatus.loading,
        allContracts: contracts,
      ),
    );
    await tester.pump();
    expect(find.text('HD-LOADING'), findsOneWidget);
    expect(find.byType(ContractCardSkeleton), findsNothing);
    expect(find.byType(SnapLoadingProgress), findsOneWidget);
    bloc.show(
      const ContractListState(
        status: ContractListStatus.error,
        errorMessage: 'Test error',
      ),
    );
    await tester.pump();
    expect(find.text('Test error'), findsOneWidget);
    expect(find.byType(SnapLoadingProgress), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notification camera, content, refreshing retains cards, error', (
    tester,
  ) async {
    final bloc = _Notifications();
    addTearDown(bloc.close);
    await tester.pumpWidget(
      app(
        BlocProvider<NotificationBloc>.value(
          value: bloc,
          child: const NotificationView(),
        ),
      ),
    );
    expect(find.byType(SnapLoadingView), findsOneWidget);
    final items = [
      NotificationItemModel(
        id: 'N',
        rawType: 'HOP_DONG',
        title: 'Test notice',
        content: 'Ready',
        sentAt: DateTime.now(),
        isRead: true,
      ),
    ];
    bloc.show(
      NotificationState(status: NotificationStatus.success, items: items),
    );
    await tester.pump();
    expect(find.byType(NotificationCard), findsOneWidget);
    bloc.show(
      NotificationState(
        status: NotificationStatus.success,
        items: items,
        isRefreshing: true,
      ),
    );
    await tester.pump();
    expect(find.byType(NotificationCard), findsOneWidget);
    expect(find.byType(NotificationItemSkeleton), findsNothing);
    expect(find.byType(SnapLoadingProgress), findsOneWidget);
    bloc.show(
      const NotificationState(
        status: NotificationStatus.failure,
        errorMessage: 'Test error',
      ),
    );
    await tester.pump();
    expect(find.text('Test error'), findsOneWidget);
    expect(find.byType(SnapSkeleton), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

// Controlled presentation states; no HTTP requests, timers, or production logic changes.
class _Home extends HomeBloc {
  _Home() : super(repository: CatalogRepository());
  void show(HomeState value) => emit(value);
}

class _Explore extends ExploreBloc {
  _Explore() : super(repository: CatalogRepository());
  void show(ExploreState value) => emit(value);
}

class _Contracts extends ContractListBloc {
  _Contracts() : super(repository: ContractListRepository());
  void show(ContractListState value) => emit(value);
}

class _Notifications extends NotificationBloc {
  _Notifications() : super(repository: MockNotificationRepository());
  void show(NotificationState value) => emit(value);
}
