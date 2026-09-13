import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uncpanion/main.dart';

void main() {
  testWidgets('navigation, timer, examples and connection disclosure', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previousErrorHandler?.call(details);
    };
    await tester.pumpWidget(const UncpanionApp());
    expect(find.text('Make room for you.'), findsOneWidget);
    await tester.tap(find.text('Focus').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Start focus'));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Pause session'), findsOneWidget);
    await tester.tap(find.text('Home').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Return to your session'), findsOneWidget);
    await tester.tap(find.text('Health').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('DEMO DATA'), findsOneWidget);
    await tester.tap(find.text('Hide example'));
    await tester.pump();
    expect(find.text('NO DEVICE DATA'), findsOneWidget);
    await tester.tap(find.text('Activity').last);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Another break idea'));
    await tester.pump();
    expect(
      find.text('Relax your shoulders and take a moment away from the screen.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Device').last);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Demo Mode'), findsOneWidget);
    expect(
      find.text('Explore every tab without a physical watch.'),
      findsOneWidget,
    );
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Live Mode'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Demo Mode'), findsOneWidget);
    expect(find.text('Find my watch'), findsOneWidget);
    expect(find.text('NOT CONNECTED'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('narrow phone and large text layouts have no overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      previousErrorHandler?.call(details);
    };
    await tester.pumpWidget(const UncpanionApp());
    for (final tab in ['Home', 'Focus', 'Health', 'Activity', 'Device']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '$tab overflow');
    }
    await tester.pumpWidget(const SizedBox());
  });
}
