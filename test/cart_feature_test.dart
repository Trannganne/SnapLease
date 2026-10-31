import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rentcam/features/cart/bloc/cart_bloc.dart';
import 'package:rentcam/features/cart/bloc/cart_event.dart';
import 'package:rentcam/features/cart/bloc/cart_state.dart';
import 'package:rentcam/features/cart/data/repositories/mock_cart_repository.dart';
import 'package:rentcam/features/cart/domain/models/cart_item_model.dart';
import 'package:rentcam/features/cart/domain/models/cart_summary_model.dart';
import 'package:rentcam/features/cart/presentation/cart_page.dart';

void main() {
  group('CartItemModel & CartSummaryModel Tests', () {
    test('calculates line total and deposit correctly', () {
      final item = CartItemModel(
        id: '1',
        branchId: 'CN1',
        branchName: 'Chi nhánh 1',
        modelId: 'M1',
        modelName: 'Sony A7 IV',
        imageUrl: 'camera.png',
        dailyPrice: 850000,
        depositPrice: 3500000,
        startDate: DateTime(2026, 9, 18),
        endDate: DateTime(2026, 9, 21),
        rentalDays: 3,
        quantity: 2,
      );

      expect(item.itemTotalPrice, 850000 * 3 * 2);
      expect(item.itemTotalDeposit, 3500000 * 2);
    });

    test(
      'CartSummaryModel calculates total rent and deposit from selected items',
      () {
        final item1 = CartItemModel(
          id: '1',
          branchId: 'CN1',
          branchName: 'Chi nhánh 1',
          modelId: 'M1',
          modelName: 'Sony A7 IV',
          imageUrl: 'camera.png',
          dailyPrice: 850000,
          depositPrice: 3500000,
          startDate: DateTime(2026, 9, 18),
          endDate: DateTime(2026, 9, 21),
          rentalDays: 3,
          quantity: 1,
          isSelected: true,
        );

        final item2 = CartItemModel(
          id: '2',
          branchId: 'CN1',
          branchName: 'Chi nhánh 1',
          modelId: 'M2',
          modelName: 'Lens 24-70mm',
          imageUrl: 'lens.png',
          dailyPrice: 300000,
          depositPrice: 1500000,
          startDate: DateTime(2026, 9, 18),
          endDate: DateTime(2026, 9, 21),
          rentalDays: 3,
          quantity: 1,
          isSelected: true,
        );

        final summary = CartSummaryModel.fromItems([item1, item2]);

        expect(summary.totalRentalPrice, 2550000 + 900000); // 3.450.000đ
        expect(summary.totalDeposit, 3500000 + 1500000); // 5.000.000đ
        expect(summary.selectedLinesCount, 2);
        expect(summary.totalLinesCount, 2);
        expect(summary.canCheckout, true);
      },
    );

    test(
      'CartSummaryModel returns null deposit when an item has null deposit',
      () {
        final item1 = CartItemModel(
          id: '1',
          branchId: 'CN1',
          branchName: 'Chi nhánh 1',
          modelId: 'M1',
          modelName: 'Sony A7 IV',
          imageUrl: 'camera.png',
          dailyPrice: 850000,
          depositPrice: null, // undetermined deposit
          startDate: DateTime(2026, 9, 18),
          endDate: DateTime(2026, 9, 21),
          rentalDays: 3,
          quantity: 1,
          isSelected: true,
        );

        final summary = CartSummaryModel.fromItems([item1]);
        expect(summary.totalDeposit, isNull);
      },
    );

    test(
      'CartSummaryModel sets total = 0 and canCheckout = false when nothing is selected',
      () {
        final item1 = CartItemModel(
          id: '1',
          branchId: 'CN1',
          branchName: 'Chi nhánh 1',
          modelId: 'M1',
          modelName: 'Sony A7 IV',
          imageUrl: 'camera.png',
          dailyPrice: 850000,
          depositPrice: 3500000,
          startDate: DateTime(2026, 9, 18),
          endDate: DateTime(2026, 9, 21),
          rentalDays: 3,
          quantity: 1,
          isSelected: false,
        );

        final summary = CartSummaryModel.fromItems([item1]);
        expect(summary.totalRentalPrice, 0);
        expect(summary.totalDeposit, 0);
        expect(summary.selectedLinesCount, 0);
        expect(summary.canCheckout, false);
      },
    );
  });

  group('MockCartRepository Tests', () {
    late MockCartRepository repository;

    setUp(() {
      repository = MockCartRepository(networkDelay: Duration.zero);
    });

    test('initializes with default fixture data', () async {
      final items = await repository.getCartItems();
      expect(items.length, 2);
      expect(items[0].modelName, 'Sony Alpha A7 IV');
      expect(items[0].dailyPrice, 850000);
      expect(items[0].depositPrice, 3500000);
      expect(items[1].modelName, 'Sony FE 24-70mm F2.8 GM');
      expect(items[1].dailyPrice, 300000);
      expect(items[1].depositPrice, 1500000);
    });

    test('updates quantity within valid bounds', () async {
      final updated = await repository.updateQuantity(
        cartItemId: 'mock_cart_item_1',
        quantity: 3,
      );
      expect(updated.quantity, 3);

      // Minimum is 1, cannot reduce to 0
      final updatedMin = await repository.updateQuantity(
        cartItemId: 'mock_cart_item_1',
        quantity: 0,
      );
      expect(updatedMin.quantity, 1);

      // Maximum is capped by maxAvailable (5)
      final updatedMax = await repository.updateQuantity(
        cartItemId: 'mock_cart_item_1',
        quantity: 99,
      );
      expect(updatedMax.quantity, 5);
    });

    test('toggles selection and removes item', () async {
      await repository.toggleItemSelection(
        cartItemId: 'mock_cart_item_1',
        isSelected: false,
      );
      var items = await repository.getCartItems();
      expect(items[0].isSelected, false);

      await repository.removeItem(cartItemId: 'mock_cart_item_1');
      items = await repository.getCartItems();
      expect(items.length, 1);
      expect(items[0].id, 'mock_cart_item_2');

      await repository.clearCart();
      items = await repository.getCartItems();
      expect(items.isEmpty, true);
    });
  });

  group('CartBloc Tests', () {
    late MockCartRepository repository;
    late CartBloc bloc;

    setUp(() {
      repository = MockCartRepository(networkDelay: Duration.zero);
      bloc = CartBloc(repository: repository);
    });

    tearDown(() {
      bloc.close();
    });

    test('CartStarted loads items and computes summary', () async {
      bloc.add(const CartStarted());
      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<CartState>((s) => s.status == CartStatus.loading),
          predicate<CartState>((s) {
            return s.status == CartStatus.loaded &&
                s.totalLinesCount == 2 &&
                s.summary.totalRentalPrice == 3450000 &&
                s.summary.totalDeposit == 5000000;
          }),
        ]),
      );
    });

    test('CartItemQuantityChanged updates price correctly', () async {
      bloc.add(const CartStarted());
      await bloc.stream.firstWhere((s) => s.status == CartStatus.loaded);

      bloc.add(
        const CartItemQuantityChanged(
          cartItemId: 'mock_cart_item_1',
          quantity: 2,
        ),
      );

      await expectLater(
        bloc.stream,
        emitsInOrder([
          predicate<CartState>(
            (s) => s.updatingItemIds.contains('mock_cart_item_1'),
          ),
          predicate<CartState>((s) {
            final item1 = s.items.firstWhere((i) => i.id == 'mock_cart_item_1');
            return item1.quantity == 2 &&
                item1.itemTotalPrice == 850000 * 3 * 2 &&
                s.summary.totalRentalPrice == (850000 * 3 * 2) + 900000 &&
                !s.updatingItemIds.contains('mock_cart_item_1');
          }),
        ]),
      );
    });

    test(
      'CartItemSelectionToggled recalculates total and canCheckout',
      () async {
        bloc.add(const CartStarted());
        await bloc.stream.firstWhere((s) => s.status == CartStatus.loaded);

        // Uncheck line 1
        bloc.add(
          const CartItemSelectionToggled(
            cartItemId: 'mock_cart_item_1',
            isSelected: false,
          ),
        );

        await expectLater(
          bloc.stream,
          emits(
            predicate<CartState>((s) {
              return s.selectedLinesCount == 1 &&
                  s.summary.totalRentalPrice == 900000 &&
                  s.summary.totalDeposit == 1500000;
            }),
          ),
        );

        // Uncheck line 2
        bloc.add(
          const CartItemSelectionToggled(
            cartItemId: 'mock_cart_item_2',
            isSelected: false,
          ),
        );

        await expectLater(
          bloc.stream,
          emits(
            predicate<CartState>((s) {
              return s.selectedLinesCount == 0 &&
                  s.summary.totalRentalPrice == 0 &&
                  s.summary.canCheckout == false;
            }),
          ),
        );
      },
    );

    test('CartEditModeToggled toggles isEditMode', () async {
      expect(bloc.state.isEditMode, false);
      bloc.add(const CartEditModeToggled());
      await expectLater(
        bloc.stream,
        emits(predicate<CartState>((s) => s.isEditMode == true)),
      );
    });

    test(
      'CartItemRemoveRequested removes line and updates totalLinesCount',
      () async {
        bloc.add(const CartStarted());
        await bloc.stream.firstWhere((s) => s.status == CartStatus.loaded);

        bloc.add(const CartItemRemoveRequested(cartItemId: 'mock_cart_item_1'));
        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<CartState>(
              (s) => s.updatingItemIds.contains('mock_cart_item_1'),
            ),
            predicate<CartState>((s) {
              return s.totalLinesCount == 1 &&
                  s.items[0].id == 'mock_cart_item_2';
            }),
          ]),
        );

        // Remove last line -> isEmpty == true
        bloc.add(const CartItemRemoveRequested(cartItemId: 'mock_cart_item_2'));
        await expectLater(
          bloc.stream,
          emitsInOrder([
            predicate<CartState>(
              (s) => s.updatingItemIds.contains('mock_cart_item_2'),
            ),
            predicate<CartState>((s) {
              return s.isEmpty == true && s.totalLinesCount == 0;
            }),
          ]),
        );
      },
    );
  });

  group('CartPage Widget Tests', () {
    late MockCartRepository repository;
    late CartBloc bloc;
    late List<CartItemModel> defaultItems;

    setUp(() {
      repository = MockCartRepository(networkDelay: Duration.zero);
      defaultItems = [
        CartItemModel(
          id: 'mock_cart_item_1',
          branchId: 'CN_THU_DUC',
          branchName: 'LensGo Thủ Đức',
          modelId: 'sony-alpha-a7-iv',
          modelName: 'Sony Alpha A7 IV',
          imageUrl: 'assets/images/camera.png',
          dailyPrice: 850000,
          depositPrice: 3500000,
          startDate: DateTime(2026, 9, 18, 9, 0),
          endDate: DateTime(2026, 9, 21, 18, 0),
          rentalDays: 3,
          quantity: 1,
          maxAvailable: 5,
          isSelected: true,
          isAvailable: true,
        ),
        CartItemModel(
          id: 'mock_cart_item_2',
          branchId: 'CN_THU_DUC',
          branchName: 'LensGo Thủ Đức',
          modelId: 'sony-fe-24-70mm-f2-8-gm',
          modelName: 'Sony FE 24-70mm F2.8 GM',
          imageUrl: 'assets/images/lens.png',
          dailyPrice: 300000,
          depositPrice: 1500000,
          startDate: DateTime(2026, 9, 18, 9, 0),
          endDate: DateTime(2026, 9, 21, 18, 0),
          rentalDays: 3,
          quantity: 1,
          maxAvailable: 4,
          isSelected: true,
          isAvailable: true,
        ),
      ];
    });

    tearDown(() {
      bloc.close();
    });

    Widget createWidgetUnderTest() {
      // Construct stream controllers inside the widget test's fake clock zone.
      bloc = CartBloc(
        repository: repository,
        initialState: CartState(status: CartStatus.loaded, items: defaultItems),
      );
      return BlocProvider<CartBloc>.value(
        value: bloc,
        child: const MaterialApp(home: CartPage(isPreview: true)),
      );
    }

    testWidgets(
      'renders CartPage with fixture data, branch header and summary footer',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 1200 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(createWidgetUnderTest());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        await tester.pumpAndSettle();

        // App bar
        expect(find.text('Giỏ hàng (2)'), findsOneWidget);
        expect(find.text('Sửa'), findsOneWidget);

        // Branch header
        expect(find.text('LensGo Thủ Đức'), findsOneWidget);

        // Item cards
        expect(find.text('Sony Alpha A7 IV'), findsOneWidget);
        expect(find.text('Sony FE 24-70mm F2.8 GM'), findsOneWidget);

        // Footer
        expect(find.text('Tiền thuê tạm tính'), findsOneWidget);
        expect(find.text('Cọc dự kiến'), findsOneWidget);
        expect(find.text('Tiếp tục thuê (2)'), findsOneWidget);

        // Note
        expect(
          find.text('Dữ liệu minh họa — chưa đồng bộ với hệ thống.'),
          findsOneWidget,
        );
      },
    );

    testWidgets('toggles Sửa/Xong and shows delete icons in edit mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 1200 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
      expect(find.text('Sửa'), findsOneWidget);

      // Tap Sửa
      final observed = <CartState>[];
      final subscription = bloc.stream.listen(observed.add);
      addTearDown(subscription.cancel);
      await tester.tap(find.widgetWithText(TextButton, 'Sửa'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(
        bloc.state.isEditMode,
        isTrue,
        reason: 'Edit event must reach the cart Bloc',
      );
      expect(
        observed.any((s) => s.isEditMode),
        isTrue,
        reason: 'Edit state must be published to subscribers',
      );
      await tester.pump();

      expect(find.text('Xong'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNWidgets(2));

      // Tap Xong
      await tester.tap(find.widgetWithText(TextButton, 'Xong'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();

      expect(find.text('Sửa'), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline_rounded), findsNothing);
    });

    testWidgets('tapping Tiếp tục thuê shows mock data notice dialog', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390 * 2, 1200 * 2);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tiếp tục thuê (2)'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Giỏ hàng đang sử dụng dữ liệu minh họa. Chưa tạo yêu cầu thuê.',
        ),
        findsOneWidget,
      );

      // Close dialog
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Giỏ hàng đang sử dụng dữ liệu minh họa. Chưa tạo yêu cầu thuê.',
        ),
        findsNothing,
      );
    });
  });
}
