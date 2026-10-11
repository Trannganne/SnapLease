import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/app/app.dart';

void main() {
  testWidgets('Login form remains usable at 360 px and shows validation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const RentCamApp());
    await tester.pumpAndSettle();
    expect(find.text('Hợp đồng thuê'), findsNothing);
    await tester.ensureVisible(find.text('Đăng nhập').last);
    await tester.tap(find.text('Đăng nhập').last);
    await tester.pump();
    expect(find.text('Vui lòng nhập email hoặc số điện thoại'), findsOneWidget);
    expect(find.text('Vui lòng nhập mật khẩu'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
