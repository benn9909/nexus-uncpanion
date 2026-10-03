import 'dart:async';

import 'package:flutter/foundation.dart';

import 'models/reminder.dart';

enum FocusPhase { setup, focus, shortBreak, longBreak }

class FocusRecord {
  final DateTime completedAt;
  final int minutes;
  const FocusRecord(this.completedAt, this.minutes);
}

/// App-local timer only. It never claims to control the watch.
/// The clock is injectable so phase transitions can be tested without waiting.
class AppState extends ChangeNotifier {
  AppState({DateTime Function()? clock, bool autoTick = true})
    : _clock = clock ?? DateTime.now {
    if (autoTick)
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }
  final DateTime Function() _clock;
  Timer? _timer;
  int selectedSessions = 4;
  int session = 1;
  FocusPhase phase = FocusPhase.setup;
  bool running = false;
  Duration _remaining = const Duration(minutes: 25);
  DateTime? _deadline;
  final List<FocusRecord> records = [];

  Duration get remaining {
    if (!running || _deadline == null) return _remaining;
    final delta = _deadline!.difference(_clock());
    return delta.isNegative ? Duration.zero : delta;
  }

  int get focusMinutes =>
      records.fold(0, (sum, record) => sum + record.minutes);
  String get label => switch (phase) {
    FocusPhase.setup => 'Ready when you are',
    FocusPhase.focus => 'Focus time',
    FocusPhase.shortBreak => 'A little breathing room',
    FocusPhase.longBreak => 'You earned a longer break',
  };
  String get face => switch (phase) {
    FocusPhase.focus => 'o_o',
    FocusPhase.shortBreak || FocusPhase.longBreak => '-_-',
    _ => '^_^',
  };
  void selectSessions(int value) {
    if (phase != FocusPhase.setup) return;
    selectedSessions = value.clamp(1, 8);
    notifyListeners();
  }

  void startOrToggle() {
    if (phase == FocusPhase.setup) {
      phase = FocusPhase.focus;
      session = 1;
      _remaining = const Duration(minutes: 25);
    } else if (running) {
      tick();
      if (phase == FocusPhase.setup) return;
      _remaining = remaining;
      running = false;
      _deadline = null;
      notifyListeners();
      return;
    }
    running = true;
    _deadline = _clock().add(_remaining);
    notifyListeners();
  }

  void reset() {
    phase = FocusPhase.setup;
    running = false;
    session = 1;
    _deadline = null;
    _remaining = const Duration(minutes: 25);
    notifyListeners();
  }

  void tick() {
    if (!running || _deadline == null) return;
    while (running && !_clock().isBefore(_deadline!)) {
      final boundary = _deadline!;
      switch (phase) {
        case FocusPhase.focus:
          records.insert(0, FocusRecord(boundary, 25));
          phase = session == selectedSessions
              ? FocusPhase.longBreak
              : FocusPhase.shortBreak;
          _remaining = Duration(
            minutes: phase == FocusPhase.longBreak ? 15 : 5,
          );
        case FocusPhase.shortBreak:
          session++;
          phase = FocusPhase.focus;
          _remaining = const Duration(minutes: 25);
        case FocusPhase.longBreak:
          reset();
          return;
        case FocusPhase.setup:
          return;
      }
      _deadline = boundary.add(_remaining);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  final List<Reminder> reminders = [];

  void addReminder(String title, DateTime deadline) {
    reminders.add(Reminder(title: title, deadline: deadline));
    notifyListeners();
  }

  void toggleReminder(int index) {
    reminders[index].isDone = !reminders[index].isDone;
    notifyListeners();
  }

  // Count unfinished reminders due from now through the next 72 hours.
  bool get isOverloaded {
    final now = _clock();
    final cutoff = now.add(const Duration(days: 3));
    final urgentCount = reminders.where((r) {
      if (r.isDone) return false;
      return !r.deadline.isBefore(now) && !r.deadline.isAfter(cutoff);
    }).length;
    return urgentCount >= 5;
  }
}
