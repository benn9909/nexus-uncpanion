import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uncpanion/app_state.dart';
import 'package:uncpanion/ble/watch_controller.dart';
import 'package:uncpanion/main.dart';

void main() {
  test('overload requires five unfinished upcoming reminders', () {
    final now = DateTime(2026, 10, 4, 9);
    final state = AppState(clock: () => now, autoTick: false);
    addTearDown(state.dispose);
    for (var i = 0; i < 4; i++) {
      state.addReminder('Task $i', now.add(const Duration(days: 2)));
    }
    expect(state.isOverloaded, isFalse);
    state.addReminder('Fifth task', now.add(const Duration(days: 2)));
    expect(state.isOverloaded, isTrue);
    state.toggleReminder(0);
    expect(state.isOverloaded, isFalse);
    state.toggleReminder(0);
    expect(state.isOverloaded, isTrue);
  });

  test('overload uses exact upcoming deadline boundaries', () {
    var now = DateTime(2026, 10, 4, 9);
    final state = AppState(clock: () => now, autoTick: false);
    addTearDown(state.dispose);
    for (var i = 0; i < 4; i++) {
      state.addReminder('Task $i', now.add(const Duration(days: 2)));
    }
    state.addReminder('Overdue', now.subtract(const Duration(seconds: 1)));
    state.addReminder(
      'Too far away',
      now.add(const Duration(days: 3, seconds: 1)),
    );
    expect(state.isOverloaded, isFalse);
    state.addReminder('At cutoff', now.add(const Duration(days: 3)));
    expect(state.isOverloaded, isTrue);
    state.toggleReminder(6);
    state.addReminder('Due now', now);
    expect(state.isOverloaded, isTrue);
    now = now.add(const Duration(milliseconds: 1));
    expect(state.isOverloaded, isFalse);
  });

  Future<void> showHome(WidgetTester tester, AppState state) async {
    final watch = WatchController(supported: false, autoTick: false);
    addTearDown(watch.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AnimatedBuilder(
            animation: state,
            builder: (context, child) =>
                HomePage(state: state, watch: watch, navigate: (_) {}),
          ),
        ),
      ),
    );
  }

  Future<void> addTask(WidgetTester tester) async {
    final button = find.text('Add Task (Test)');
    await tester.scrollUntilVisible(
      button,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    // Home's avatar animates continuously, so do not pumpAndSettle.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('completed tasks do not trigger the overload dialog', (
    tester,
  ) async {
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    for (var i = 0; i < 4; i++) {
      state.addReminder('Done $i', DateTime.now().add(const Duration(days: 2)));
      state.toggleReminder(i);
    }
    await showHome(tester, state);
    await addTask(tester);
    expect(state.reminders.length, 5);
    expect(find.text('Task Overload Alert'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('overload prompts once when crossing the threshold', (
    tester,
  ) async {
    final state = AppState(autoTick: false);
    addTearDown(state.dispose);
    for (var i = 0; i < 4; i++) {
      state.addReminder('Task $i', DateTime.now().add(const Duration(days: 2)));
    }
    await showHome(tester, state);
    await addTask(tester);
    expect(find.text('Task Overload Alert'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pump(const Duration(milliseconds: 300));
    await addTask(tester);
    expect(find.text('Task Overload Alert'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('breathing cues change at animation reversals', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BreathingDialog())),
    );
    await tester.pump();
    expect(find.text('Inhale slowly...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2499));
    expect(find.text('Inhale slowly...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2));
    expect(find.text('Exhale gently...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Inhale slowly...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Exhale gently...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 2500));
    expect(find.text('Session Completed!'), findsOneWidget);
    expect(find.text('Inhale slowly...'), findsNothing);
    expect(find.text('Exhale gently...'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'reminder and breathing dialogs fit a narrow phone with large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final state = AppState(autoTick: false);
      addTearDown(state.dispose);
      for (var i = 0; i < 4; i++) {
        state.addReminder(
          'Task $i',
          DateTime.now().add(const Duration(days: 2)),
        );
      }
      await showHome(tester, state);
      await addTask(tester);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Breathe with Unc'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Breathing with Unc'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(BreathingDialog), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
