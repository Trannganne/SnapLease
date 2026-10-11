import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rentcam/core/widgets/reservation_timer.dart';

void main() {
  testWidgets('ReservationTimer counts down monotonically', (WidgetTester tester) async {
    bool expiredFired = false;
    final stopwatch = Stopwatch()..start();
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReservationTimer(
          initialTimeRemaining: const Duration(seconds: 3),
          stopwatch: stopwatch,
          onExpired: () => expiredFired = true,
        ),
      ),
    ));

    // Since stopwatch is running, remaining might be 2.999 seconds, showing as 00:02
    expect(find.textContaining('00:02'), findsOneWidget);
    
    // Simulate 1 second passing
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('00:01'), findsOneWidget);
    expect(expiredFired, isFalse);

    // Simulate 2 more seconds passing
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('00:00'), findsOneWidget);
    expect(expiredFired, isTrue); // Should have fired

    // Pumping more doesn't fire it again
    expiredFired = false;
    await tester.pump(const Duration(seconds: 1));
    expect(expiredFired, isFalse); // Should only fire once
  });

  testWidgets('ReservationTimer shows syncing state', (WidgetTester tester) async {
    final stopwatch = Stopwatch()..start();
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReservationTimer(
          initialTimeRemaining: const Duration(seconds: 60),
          stopwatch: stopwatch,
          isSyncing: true,
          onExpired: () {},
        ),
      ),
    ));

    expect(find.text('Đang đồng bộ'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ReservationTimer handles AppLifecycle resume', (WidgetTester tester) async {
    bool resumeFired = false;
    final stopwatch = Stopwatch()..start();
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReservationTimer(
          initialTimeRemaining: const Duration(seconds: 60),
          stopwatch: stopwatch,
          onExpired: () {},
          onResume: () => resumeFired = true,
        ),
      ),
    ));

    // Simulate app going to background and foreground
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    
    expect(resumeFired, isTrue);
  });
  
  testWidgets('ReservationTimer ignores elapsed time while syncing', (WidgetTester tester) async {
    bool expiredFired = false;
    final stopwatch = Stopwatch()..start();
    
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReservationTimer(
          initialTimeRemaining: const Duration(seconds: 1),
          stopwatch: stopwatch,
          isSyncing: true,
          onExpired: () => expiredFired = true,
        ),
      ),
    ));

    await tester.pump(const Duration(seconds: 2));
    expect(expiredFired, isFalse); // Should not fire while syncing
  });
}
