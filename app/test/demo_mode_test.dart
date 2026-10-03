import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uncpanion/ble/transport.dart';
import 'package:uncpanion/ble/watch_controller.dart';
import 'package:uncpanion/main.dart';

import 'ble_test.dart' show FakeTransport;

void main() {
  Future<void> tab(WidgetTester tester, String name) async {
    await tester.tap(find.text(name).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('one demo preference controls Health and Activity without BLE', (
    tester,
  ) async {
    final watch = WatchController(supported: false, autoTick: false);
    addTearDown(watch.dispose);
    await tester.pumpWidget(MaterialApp(home: AppShell(watch: watch)));
    await tab(tester, 'Health');
    expect(find.text('DEMO DATA'), findsOneWidget);
    await tester.tap(find.text('Hide example'));
    await tester.pump();
    await tab(tester, 'Activity');
    expect(find.text('DEMO DATA'), findsNothing);
    expect(find.text('Waiting for your watch'), findsOneWidget);
    await tab(tester, 'Device');
    expect(find.text('Live Mode'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Demo Mode'), findsOneWidget);
    await tab(tester, 'Activity');
    expect(find.text('DEMO DATA'), findsOneWidget);
    await tab(tester, 'Health');
    expect(find.text('71'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });

  testWidgets('live readings take priority and demo returns after disconnect', (
    tester,
  ) async {
    final transport = FakeTransport();
    final watch = WatchController(
      transport: transport,
      supported: true,
      autoTick: false,
    );
    addTearDown(watch.dispose);
    addTearDown(transport.results.close);
    await tester.pumpWidget(MaterialApp(home: AppShell(watch: watch)));
    await watch.connect(const WatchDevice('test', 'Watch'));
    await tab(tester, 'Health');
    expect(find.text('LIVE WATCH DATA'), findsOneWidget);
    expect(find.text('DEMO DATA'), findsNothing);
    await tab(tester, 'Device');
    expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    await watch.disconnect();
    await tester.pump(const Duration(milliseconds: 300));
    expect(watch.hasConnected, isTrue);
    await tab(tester, 'Health');
    expect(find.text('DEMO DATA'), findsOneWidget);
    await tab(tester, 'Activity');
    expect(find.text('DEMO DATA'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
