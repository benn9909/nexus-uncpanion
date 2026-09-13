import 'package:flutter_test/flutter_test.dart';
import 'package:uncpanion/app_state.dart';

void main() {
  test('full two-session sequence catches up after suspension', () {
    var now = DateTime(2026, 9, 11, 9);
    final app = AppState(clock: () => now, autoTick: false);
    addTearDown(app.dispose);
    app.selectSessions(2);
    app.startOrToggle();
    now = now.add(const Duration(minutes: 25));
    app.tick();
    expect(app.phase, FocusPhase.shortBreak);
    expect(app.records.length, 1);
    now = now.add(const Duration(minutes: 5));
    app.tick();
    expect(app.phase, FocusPhase.focus);
    expect(app.session, 2);
    now = now.add(const Duration(minutes: 40));
    app.tick();
    expect(app.phase, FocusPhase.setup);
    expect(app.running, false);
    expect(app.focusMinutes, 50);
  });
  test('paused time is excluded and reset does not record partial focus', () {
    var now = DateTime(2026, 9, 11, 9);
    final app = AppState(clock: () => now, autoTick: false);
    addTearDown(app.dispose);
    app.startOrToggle();
    now = now.add(const Duration(minutes: 10));
    app.startOrToggle();
    now = now.add(const Duration(hours: 1));
    expect(app.remaining, const Duration(minutes: 15));
    app.startOrToggle();
    now = now.add(const Duration(minutes: 5));
    app.tick();
    expect(app.remaining, const Duration(minutes: 10));
    app.reset();
    expect(app.records, isEmpty);
    expect(app.remaining, const Duration(minutes: 25));
  });
  test('session bounds and final long break for one session', () {
    var now = DateTime(2026, 9, 11, 9);
    final app = AppState(clock: () => now, autoTick: false);
    addTearDown(app.dispose);
    app.selectSessions(20);
    expect(app.selectedSessions, 8);
    app.selectSessions(0);
    expect(app.selectedSessions, 1);
    app.startOrToggle();
    app.selectSessions(4);
    expect(app.selectedSessions, 1);
    now = now.add(const Duration(minutes: 25));
    app.tick();
    expect(app.phase, FocusPhase.longBreak);
  });
}
