import 'models/reminder.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';

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
      _remaining = Duration(minutes: sessionFocusTime);
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
    _remaining = Duration(minutes: sessionFocusTime);
    notifyListeners();
  }

  void tick() {
    if (!running || _deadline == null) return;
    while (running && !_clock().isBefore(_deadline!)) {
      final boundary = _deadline!;
      switch (phase) {
        case FocusPhase.focus:
          records.insert(0, FocusRecord(boundary, sessionFocusTime));
          phase = session == selectedSessions
              ? FocusPhase.longBreak
              : FocusPhase.shortBreak;
          _remaining = Duration(
            minutes: phase == FocusPhase.longBreak ? 15 : sessionBreakTime,
          );
        case FocusPhase.shortBreak:
          session++;
          phase = FocusPhase.focus;
          _remaining = Duration(minutes: sessionFocusTime);
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

  int sessionFocusTime = 25;
  int sessionBreakTime = 5;
  
  int currentBpm = 80; 
  bool isLowActivity = true; 

  // check if highstress (BPM higher than 100 & low activity)
  bool get isHighStress => currentBpm >= 100 && isLowActivity;

  //adjust timer for stress (15 min focus, 10 min break)
  void adjustTimerForStress() {
    sessionFocusTime = 15;
    sessionBreakTime = 10;
    
  
    if (phase == FocusPhase.setup) {
      _remaining = Duration(minutes: sessionFocusTime);
    }
    notifyListeners();
  }

  // if stress returns to normal state, timer also returns to 25/5 session
  void resetTimerIfRelaxed() {
    if (!isHighStress) {
      sessionFocusTime = 25;
      sessionBreakTime = 5;
      notifyListeners();
    }
  }

  //reminder
  List<Reminder> reminders = [];

  void addReminder(String title, DateTime deadline) {
    reminders.add(Reminder(title: title, deadline: deadline));
    notifyListeners();
  }

  void toggleReminder(int index) {
    reminders[index].isDone = !reminders[index].isDone;
    notifyListeners();
  }

  // check if there are more than 5 urgent reminder in 3 days
  bool get isOverloaded {
    final now = DateTime.now();
    int urgentCount = reminders.where((r) {
      if (r.isDone) return false;
      final daysLeft = r.deadline.difference(now).inDays;
      return daysLeft >= 0 && daysLeft <= 3;
    }).length;
    return urgentCount >= 5;
  }
}