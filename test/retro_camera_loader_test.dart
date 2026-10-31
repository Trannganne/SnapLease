import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/core/theme/app_theme.dart';
import 'package:rentcam/core/widgets/retro_camera_loader.dart';
import 'package:rentcam/core/widgets/snap_loading_view.dart';
import 'package:rentcam/loading_preview.dart';

Widget host(
  Widget child, {
  bool reduced = false,
  bool dark = false,
  bool active = true,
}) => MaterialApp(
  theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduced),
    child: TickerMode(enabled: active, child: Scaffold(body: child)),
  ),
);

void main() {
  setUpAll(() async {
    // Optional real fonts for review captures. Normal tests retain test fonts.
    const directory = String.fromEnvironment('SNAP_LOADING_FONT_DIR');
    if (directory.isEmpty) return;
    final font =
        FontLoader('Roboto')
          ..addFont(
            File(
              '$directory/roboto-regular.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          )
          ..addFont(
            File(
              '$directory/roboto-bold.ttf',
            ).readAsBytes().then(ByteData.sublistView),
          );
    await font.load();
  });
  testWidgets(
    'Mobile comparison uses identical dimensions and Focus timestamp',
    (tester) async {
      tester.view.physicalSize = LoadingPreview.mobileSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final dark in [false, true]) {
        final key = GlobalKey();
        await tester.pumpWidget(
          host(
            RepaintBoundary(
              key: key,
              child: ColoredBox(
                color:
                    (dark ? AppTheme.darkTheme : AppTheme.lightTheme)
                        .scaffoldBackgroundColor,
                child: const SizedBox(
                  width: 390,
                  height: 844,
                  child: SnapLoadingView(size: RetroCameraLoader.large),
                ),
              ),
            ),
            dark: dark,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 900));
        final paint =
            tester
                .widgetList<CustomPaint>(find.byType(CustomPaint))
                .map((widget) => widget.painter)
                .whereType<RetroCameraPainter>()
                .single;
        expect(paint.progress.value, closeTo(.3, .0001));
        expect(tester.getSize(find.byKey(key)), LoadingPreview.mobileSize);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('SNAP_LOADING_CAPTURE')) {
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final directory = Directory('build/loading-preview');
            await directory.create(recursive: true);
            final image = await boundary.toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${directory.path}/mobile_${dark ? 'dark' : 'light'}_900.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
      }
    },
  );

  testWidgets(
    'Debug preview renders and toggles reduced motion and dark theme',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const LoadingPreview());
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(RetroCameraLoader), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('loading-mobile-canvas'))),
        LoadingPreview.mobileSize,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('loading-mobile-canvas')),
          matching: find.byType(SwitchListTile),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Reduced motion'));
      await tester.pump();
      // Material 3 InkSparkle lasts 617 ms (Flutter SDK ink_sparkle.dart).
      // Finish this finite tap effect before counting repeating loading tickers.
      await tester.pump(const Duration(milliseconds: 617));
      // Sample the next display frame after InkSparkle's fractional endpoint.
      await tester.pump(const Duration(milliseconds: 16));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.tap(find.text('Dark theme'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 617));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        Theme.of(tester.element(find.byType(Scaffold))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Five phases paint distinct frames and reset without a jump', (
    tester,
  ) async {
    final clock = ValueNotifier<double>(0);
    final animation = _ValueAnimation(clock);
    final key = GlobalKey();
    await tester.pumpWidget(
      host(
        Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: 240,
              height: 240,
              child: CustomPaint(
                painter: RetroCameraPainter(
                  progress: animation,
                  primary: Colors.blue,
                  ink: Colors.black,
                  cream: const Color(0xFFFFEBCB),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Future<List<int>> frame(double ms) async {
      clock.value = ms / 3000;
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      return (await tester.runAsync(() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final result = bytes!.buffer.asUint8List().toList();
        if (const bool.fromEnvironment('SNAP_LOADING_CAPTURE')) {
          final directory = Directory('build/loading-preview');
          await directory.create(recursive: true);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${directory.path}/camera_${ms.toInt()}.png',
          ).writeAsBytes(png!.buffer.asUint8List());
        }
        image.dispose();
        return result;
      }))!;
    }

    final start = await frame(0);
    final frames = <List<int>>[];
    for (final ms in [300.0, 900.0, 1320.0, 2200.0, 2750.0]) {
      frames.add(await frame(ms));
    }
    for (var i = 0; i < frames.length; i++) {
      expect(frames[i], isNot(orderedEquals(start)));
      if (i > 0) expect(frames[i], isNot(orderedEquals(frames[i - 1])));
    }
    expect(await frame(3000), orderedEquals(start));
    await tester.pumpWidget(const SizedBox());
    clock.dispose();
  });

  testWidgets('Small screen, light/dark, large text and repeated disposal', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 480);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final dark in [false, true]) {
      for (final size in [96.0, 180.0, 240.0]) {
        await tester.pumpWidget(
          host(
            MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: SnapLoadingView(size: size, subtitle: 'Đang tải dữ liệu'),
            ),
            dark: dark,
          ),
        );
        for (final ms in [600, 600, 400, 900, 500, 3000]) {
          await tester.pump(Duration(milliseconds: ms));
          expect(tester.takeException(), isNull);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(tester.binding.transientCallbackCount, 0);
      }
    }
  });

  testWidgets(
    'Reduced motion, TickerMode and lifecycle stop and resume clocks',
    (tester) async {
      await tester.pumpWidget(host(const RetroCameraLoader(), reduced: true));
      await tester.pump(const Duration(seconds: 4));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(host(const RetroCameraLoader(), active: false));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpWidget(host(const RetroCameraLoader()));
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, 0);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(tester.binding.transientCallbackCount, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'One semantic message, then content/success/error removes loading',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        host(const SnapLoadingView(message: 'Đang tải thiết bị')),
      );
      expect(find.bySemanticsLabel('Đang tải thiết bị'), findsOneWidget);
      for (final result in ['Nội dung', 'Thành công', 'Lỗi · Thử lại']) {
        await tester.pumpWidget(host(Text(result)));
        await tester.pump();
        expect(find.byType(RetroCameraLoader), findsNothing);
        expect(find.text(result), findsOneWidget);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(host(const SnapLoadingView()));
      }
      await tester.pumpWidget(const SizedBox());
      semantics.dispose();
    },
  );
}

class _ValueAnimation extends Animation<double>
    with AnimationLocalListenersMixin, AnimationLocalStatusListenersMixin {
  final ValueNotifier<double> notifier;
  _ValueAnimation(this.notifier) {
    notifier.addListener(notifyListeners);
  }
  @override
  double get value => notifier.value;
  @override
  AnimationStatus get status => AnimationStatus.forward;
  @override
  void didRegisterListener() {}
  @override
  void didUnregisterListener() {}
}
