import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'demo_data.dart';
import 'ble/watch_controller.dart';

void main() => runApp(const UncpanionApp());
const ink = Color(0xFF202820);
const muted = Color(0xFF70786B);
const paper = Color(0xFFF7F8F2);
const lime = Color(0xFFDDF3A0);
const green = Color(0xFF47633A);
const line = Color(0xFFE4E8DB);

class UncpanionApp extends StatelessWidget {
  const UncpanionApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Uncpanion',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: paper,
      colorScheme: ColorScheme.fromSeed(seedColor: green, surface: paper),
      fontFamily: 'Arial',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.3,
          color: ink,
        ),
        headlineMedium: TextStyle(
          fontSize: 27,
          fontWeight: FontWeight.w700,
          letterSpacing: -.8,
          color: ink,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: ink),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(0, 48),
          side: const BorderSide(color: line),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    ),
    home: const AppShell(),
  );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WidgetsBindingObserver {
  final state = AppState();
  final watch = WatchController();
  int tab = 0;
  bool demoMode = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed) state.tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    state.dispose();
    watch.dispose();
    super.dispose();
  }

  void navigate(int value) => setState(() => tab = value);
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([state, watch]),
    builder: (context, _) => Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              reverseDuration: const Duration(milliseconds: 140),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position:
                      Tween<Offset>(
                        begin: const Offset(.035, 0),
                        end: Offset.zero,
                      ).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                      ),
                  child: child,
                ),
              ),
              child: KeyedSubtree(
                key: ValueKey(tab),
                child: [
                  HomePage(state: state, watch: watch, navigate: navigate),
                  FocusPage(state: state, watch: watch),
                  HealthPage(watch: watch),
                  ActivityPage(watch: watch),
                  DevicePage(
                    watch: watch,
                    demoMode: demoMode && !watch.connected,
                    onDemoModeChanged: (value) =>
                        setState(() => demoMode = value),
                  ),
                ][tab],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 430),
          child: NavigationBar(
            selectedIndex: tab,
            onDestinationSelected: navigate,
            backgroundColor: paper,
            indicatorColor: lime,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer),
                label: 'Focus',
              ),
              NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite),
                label: 'Health',
              ),
              NavigationDestination(
                icon: Icon(Icons.directions_walk),
                label: 'Activity',
              ),
              NavigationDestination(
                icon: Icon(Icons.watch_outlined),
                selectedIcon: Icon(Icons.watch),
                label: 'Device',
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
    children: children
        .expand((widget) => [widget, const SizedBox(height: 20)])
        .toList(),
  );
}

class PageTitle extends StatelessWidget {
  const PageTitle(this.title, this.subtitle, {super.key, this.action});
  final String title, subtitle;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineLarge,
            ),
          ),
          ?action,
        ],
      ),
      const SizedBox(height: 6),
      Text(subtitle, style: const TextStyle(color: muted, height: 1.4)),
    ],
  );
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = 20,
  });
  final Widget child;
  final Color color;
  final double padding;
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOutCubic,
    alignment: Alignment.topCenter,
    child: Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: line),
      ),
      child: child,
    ),
  );
}

class Tag extends StatelessWidget {
  const Tag(this.text, {super.key, this.color = lime});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleLarge),
      ),
      ?trailing,
    ],
  );
}

class Metric extends StatelessWidget {
  const Metric(this.icon, this.value, this.label, {super.key});
  final IconData icon;
  final String value, label;
  @override
  Widget build(BuildContext context) => Panel(
    padding: 16,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: green),
        const SizedBox(height: 14),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        Text(label, style: const TextStyle(fontSize: 12, color: muted)),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.state,
    required this.watch,
    required this.navigate,
  });
  final AppState state;
  final ValueChanged<int> navigate;
  final WatchController watch;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int dialogue = 0;

  void _showOverloadAndBreathingDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: green),
            SizedBox(width: 8),
            Text('Task Overload Alert', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'You have 5 or more tasks coming up! Take a moment to pause and avoid feeling overwhelmed.',
              style: TextStyle(fontSize: 14, height: 1.4),
            ),
            SizedBox(height: 16),
            Text(
              'Would you like to take a 10-second breathing break with Unc?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: green,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const BreathingDialog(),
              );
            },
            child: const Text('Breathe with Unc'),
          ),
        ],
      ),
    );
  } //int dialogue// @overrride 
  @override
  Widget build(BuildContext context) {
    final active = widget.state.phase != FocusPhase.setup;
    final messages = active
        ? [
            '${widget.state.label}. I’m right here.',
            'One thing at a time. You’ve got this.',
            'A little focus, a little rest.',
          ]
        : [
            'Hey, I’m Unc. What’s the move?',
            'Small steps count. Ready for one?',
            'Your next break is part of the plan.',
          ];
    return PageBody(
      children: [
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.spa_outlined, color: green),
            const Text(
              'uncpanion',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 21,
                letterSpacing: -.6,
              ),
            ),
            TextButton.icon(
              onPressed: () => widget.navigate(4),
              icon: const Icon(Icons.bluetooth_disabled, size: 16),
              label: Text(widget.watch.label),
            ),
          ],
        ),
        const PageTitle(
          'Make room for you.',
          'A little focus. A little movement. Your own pace.',
        ),
        Panel(
          color: lime,
          padding: 24,
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Tag('YOUR STUDY SIDEKICK', color: Color(0xFFEDF8D3)),
                  Text(
                    active ? 'WITH YOU' : 'READY',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Semantics(
                button: true,
                label: 'Talk to Unc',
                child: InkWell(
                  borderRadius: BorderRadius.circular(90),
                  onTap: () => setState(() => dialogue++),
                  child: UncAvatar(
                    face: widget.watch.reading?.face ?? widget.state.face,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  messages[dialogue % messages.length],
                  key: ValueKey('${widget.state.phase}-$dialogue'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Tap Unc for a little encouragement',
                style: TextStyle(fontSize: 12, color: green),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => widget.navigate(1),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(
                    active ? 'Return to your session' : 'Find your focus',
                  ),
                ),
              ),
            ],
          ),
        ),

        SectionTitle(
  'My To-Do List',
  trailing: const Tooltip(
    message: 'When you have too many upcoming tasks, Unc will alert you and help you pace yourself.',
    triggerMode: TooltipTriggerMode.tap,
    child: Icon(
      Icons.help_outline_rounded,
      size: 18,
      color: muted,
    ),
  ),
),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.state.reminders.isEmpty)
                const Text('No tasks added yet.', style: TextStyle(color: muted))
              else
                ...widget.state.reminders.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var r = entry.value;
                  return CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      r.title,
                      style: TextStyle(
                        decoration: r.isDone ? TextDecoration.lineThrough : null,
                        color: r.isDone ? muted : ink,
                      ),
                    ),
                    subtitle: Text('Due: ${r.deadline.month}/${r.deadline.day}'),
                    value: r.isDone,
                    onChanged: (bool? val) {
                      widget.state.toggleReminder(idx);
                    },
                  );
                }).toList(),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      widget.state.addReminder(
                        'New task ${widget.state.reminders.length + 1}',
                        DateTime.now().add(const Duration(days: 2)),
                      );
                    });
                    if (widget.state.reminders.length >= 5) {
                      _showOverloadAndBreathingDialog();
                    }
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Task (Test)'),
                ),
              ),
            ],
          ),
        ),
        const SectionTitle(
          'Your rhythm so far',
          trailing: Tag('APP SESSION', color: Color(0xFFEBEDE5)),
        ),
        Row(
          children: [
            Expanded(
              child: Metric(
                Icons.hourglass_bottom,
                '${widget.state.focusMinutes} min',
                'focused in this app',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Metric(
                Icons.check_circle_outline,
                '${widget.state.records.length}',
                'sessions completed',
              ),
            ),
          ],
        ),
        Panel(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.wb_sunny_outlined, color: green),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'A small idea for your next break',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Look away from your screen. Stretch, get some water, or simply take a moment.',
                      style: TextStyle(color: muted),
                    ),
                    TextButton(
                      onPressed: () => widget.navigate(3),
                      child: const Text('Explore movement →'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class UncAvatar extends StatefulWidget {
  const UncAvatar({super.key, required this.face});
  final String face;
  @override
  State<UncAvatar> createState() => _UncAvatarState();
}

class _UncAvatarState extends State<UncAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();
  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    builder: (context, _) {
      final reduced = MediaQuery.disableAnimationsOf(context);
      final value = reduced ? 0.0 : animation.value;
      return SizedBox(
        width: 200,
        height: 170,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              bottom: 6,
              child: Container(
                width: 94,
                height: 13,
                decoration: BoxDecoration(
                  color: green.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
            ),
            Transform.translate(
              offset: Offset(0, math.sin(value * math.pi * 2) * 4),
              child: Container(
                width: 130,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFFF4FBCF),
                  borderRadius: BorderRadius.circular(38),
                  border: Border.all(color: ink, width: 3),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFB7D180), offset: Offset(5, 7)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  value > .94 ? '-_-' : widget.face,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    fontSize: 39,
                    color: ink,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

class FocusPage extends StatelessWidget {
  const FocusPage({super.key, required this.state, required this.watch});
  final AppState state;
  final WatchController watch;
  
  @override
  Widget build(BuildContext context) {
    final setup = state.phase == FocusPhase.setup;
    final seconds = (state.remaining.inMilliseconds / 1000).ceil();
    final time =
        '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return PageBody(
      children: [
        PageTitle(
  'One thing at a time.',
  'A place to begin, pause, and begin again.',
  action: const Tooltip(
    message: 'If high stress is detected, focus time automatically adjusts to 15 minutes with a 10-minute break.',
    triggerMode: TooltipTriggerMode.tap,
    child: Icon(
      Icons.help_outline_rounded,
      size: 20,
      color: muted,
    ),
  ),
),
        if (watch.hasConnected) WatchFocusPanel(watch: watch),
        const Row(
          children: [
            Tag('APP TIMER'),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Independent of your watch',
                style: TextStyle(fontSize: 12, color: muted),
              ),
            ),
          ],
        ),
        Panel(
          child: Column(
            children: [
              Text(state.label, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(26),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: lime,
                ),
                child: Column(
                  children: [
                    const Icon(Icons.spa_outlined, color: green),
                    const SizedBox(height: 12),
                    FittedBox(
                      child: Text(
                        time,
                        style: const TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -2,
                        ),
                      ),
                    ),
                    Text(
                      setup
                          ? '25 MINUTES TO YOURSELF'
                          : '${state.running ? 'IN PROGRESS' : 'PAUSED'} · ${state.session}/${state.selectedSessions}',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (setup)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      tooltip: 'Fewer sessions',
                      onPressed: state.selectedSessions > 1
                          ? () =>
                                state.selectSessions(state.selectedSessions - 1)
                          : null,
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    Expanded(
                      child: Text(
                        '${state.selectedSessions} sessions',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    IconButton(
                      tooltip: 'More sessions',
                      onPressed: state.selectedSessions < 8
                          ? () =>
                                state.selectSessions(state.selectedSessions + 1)
                          : null,
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.startOrToggle,
                  icon: Icon(state.running ? Icons.pause : Icons.play_arrow),
                  label: Text(
                    setup
                        ? 'Start focus'
                        : state.running
                        ? 'Pause session'
                        : 'Resume session',
                  ),
                ),
              ),
              if (!setup)
                TextButton(
                  onPressed: state.reset,
                  child: const Text('End this round'),
                ),
            ],
          ),
        ),
        const Panel(
          color: Color(0xFFEEF0E7),
          child: Text(
            '25 min focus → 5 min break → repeat\nFinish your round with a 15 min break.',
            style: TextStyle(height: 1.8),
          ),
        ),
        const SectionTitle('Completed here'),
        if (state.records.isEmpty)
          const Panel(
            child: Text(
              'Your first session starts with one small step. Completed focus sessions will appear here.',
            ),
          )
        else
          ...state.records
              .take(8)
              .map(
                (record) => Panel(
                  padding: 16,
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${record.minutes} minutes of focus',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        TimeOfDay.fromDateTime(
                          record.completedAt,
                        ).format(context),
                        style: const TextStyle(color: muted),
                      ),
                    ],
                  ),
                ),
              ),
        const Text(
          'This first prototype keeps app sessions in memory. Closing or reloading the app clears them. No background alerts yet.',
          style: TextStyle(fontSize: 12, color: muted),
        ),
      ],
    );
  }
}

class HealthPage extends StatefulWidget {
  const HealthPage({super.key, required this.watch});
  final WatchController watch;
  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  bool week = false;
  bool showDemo = true;
  @override
  Widget build(BuildContext context) => widget.watch.hasConnected
      ? LiveHealthPage(watch: widget.watch)
      : PageBody(
          children: [
            const PageTitle(
              'A moment to check in.',
              'Heart rate, with room for context.',
            ),
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tag(
                  showDemo ? 'DEMO DATA' : 'NO DEVICE DATA',
                  color: const Color(0xFFF5E7CE),
                ),
                TextButton(
                  onPressed: () => setState(() => showDemo = !showDemo),
                  child: Text(showDemo ? 'Hide example' : 'Show example'),
                ),
              ],
            ),
            const Text(
              'Examples below are not readings from your wearable.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.favorite, color: Color(0xFFA76155), size: 20),
                      SizedBox(width: 9),
                      Text(
                        'Heart rate',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        showDemo ? '71' : '—',
                        style: const TextStyle(
                          fontSize: 62,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text('BPM', style: TextStyle(color: muted)),
                    ],
                  ),
                  Text(
                    showDemo
                        ? 'Illustrative reading · no live connection'
                        : 'Connect a compatible wearable to receive readings',
                    style: const TextStyle(color: muted, fontSize: 12),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 100,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: TrendPainter(
                        showDemo ? DemoData.pulse : [],
                        color: const Color(0xFFA76155),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'OPTICAL PULSE · EXAMPLE',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            SectionTitle(
              'A wider view',
              trailing: RangeToggle(
                week: week,
                onChanged: (value) => setState(() => week = value),
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    week ? 'Example week' : 'Example day',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 90,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: TrendPainter(
                        showDemo
                            ? (week
                                  ? DemoData.weeklyBpm
                                  : DemoData.pulse.sublist(0, 18))
                            : [],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:
                        (week
                                ? ['MON', 'WED', 'FRI', 'SUN']
                                : ['08:00', '12:00', '16:00', '20:00'])
                            .map(
                              (s) => Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
            const Panel(
              color: Color(0xFFEEF0E7),
              child: Text(
                'Heart rate is a physiological measurement. This prototype does not estimate stress or produce a wellness score.',
              ),
            ),
          ],
        );
}

class ActivityPage extends StatefulWidget {
  const ActivityPage({super.key, required this.watch});
  final WatchController watch;
  @override
  State<ActivityPage> createState() => _ActivityPageState();
}

class _ActivityPageState extends State<ActivityPage> {
  bool week = false;
  int idea = 0;
  static const ideas = [
    'Stand up and stretch if that feels comfortable.',
    'Relax your shoulders and take a moment away from the screen.',
    'Refill your water, or enjoy a quiet pause.',
  ];
  @override
  Widget build(BuildContext context) => widget.watch.hasConnected
      ? LiveActivityPage(watch: widget.watch)
      : PageBody(
          children: [
            const PageTitle(
              'Make space to move.',
              'Breaks belong in your routine, too.',
            ),
            const Align(
              alignment: Alignment.centerLeft,
              child: Tag('DEMO DATA', color: Color(0xFFF5E7CE)),
            ),
            const Text(
              'Illustrative movement patterns, not recorded activity.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
            Panel(
              color: lime,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.self_improvement, size: 36, color: green),
                  const SizedBox(height: 16),
                  Text(
                    'A little reset?',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(ideas[idea], style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 14),
                  OutlinedButton(
                    onPressed: () =>
                        setState(() => idea = (idea + 1) % ideas.length),
                    child: const Text('Another break idea'),
                  ),
                ],
              ),
            ),
            SectionTitle(
              'Movement pattern',
              trailing: RangeToggle(
                week: week,
                onChanged: (value) => setState(() => week = value),
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Relative movement · example',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 130,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children:
                          (week
                                  ? DemoData.weeklyMovement
                                  : DemoData.dailyMovement)
                              .map(
                                (value) => Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: FractionallySizedBox(
                                      heightFactor: value,
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: value > .6 ? green : lime,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children:
                        (week
                                ? ['MON', 'WED', 'FRI', 'SUN']
                                : ['MORNING', 'AFTERNOON', 'EVENING'])
                            .map(
                              (s) => Text(
                                s,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: muted,
                                ),
                              ),
                            )
                            .toList(),
                  ),
                ],
              ),
            ),
            const SectionTitle('What your watch can notice'),
            const Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Moving · Still · Inactive',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'The wearable estimates movement from its motion sensor. Step counts, sleep tracking, and historical activity totals are not implemented.',
                    style: TextStyle(color: muted),
                  ),
                ],
              ),
            ),
          ],
        );
}

class DevicePage extends StatelessWidget {
  const DevicePage({
    super.key,
    required this.watch,
    required this.demoMode,
    required this.onDemoModeChanged,
  });
  final WatchController watch;
  final bool demoMode;
  final ValueChanged<bool> onDemoModeChanged;
  @override
  Widget build(BuildContext context) => PageBody(
    children: [
      const PageTitle(
        'Your little companion.',
        'The watch leads. The app helps you look back.',
      ),
      Panel(
        color: demoMode ? lime : Colors.white,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    demoMode ? 'Demo Mode' : 'Live Mode',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    demoMode
                        ? 'Explore every tab without a physical watch.'
                        : 'Connect a watch for live sensor readings.',
                    style: const TextStyle(color: muted),
                  ),
                ],
              ),
            ),
            Switch(value: demoMode, onChanged: onDemoModeChanged),
          ],
        ),
      ),
      Panel(
        child: Column(
          children: [
            const Icon(Icons.watch_outlined, size: 64, color: green),
            const SizedBox(height: 16),
            Text(
              watch.deviceName ?? 'Uncpanion Watch',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Tag(watch.label.toUpperCase()),
            const SizedBox(height: 16),
            Text(
              watch.guidance,
              textAlign: TextAlign.center,
              style: const TextStyle(color: muted),
            ),
            if (watch.error != null) ...[
              const SizedBox(height: 12),
              Text(
                watch.error!,
                style: const TextStyle(color: Color(0xFFA76155)),
              ),
            ],
            const SizedBox(height: 20),
            if (watch.connected)
              FilledButton.icon(
                onPressed: watch.disconnect,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect watch'),
              )
            else if (watch.status == WatchStatus.scanning)
              OutlinedButton(
                onPressed: watch.stopScan,
                child: const Text('Stop looking'),
              )
            else
              FilledButton.icon(
                onPressed: watch.busy || watch.status == WatchStatus.unsupported
                    ? null
                    : watch.scan,
                icon: const Icon(Icons.bluetooth_searching),
                label: Text(watch.busy ? watch.label : 'Find my watch'),
              ),
            if (watch.busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
      if (!watch.connected && watch.devices.isNotEmpty) ...[
        const SectionTitle('Choose your watch'),
        ...watch.devices.map(
          (device) => Panel(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.watch, color: green),
              title: Text(device.name),
              subtitle: const Text('Uncpanion BLE service'),
              trailing: const Icon(Icons.chevron_right),
              onTap: watch.busy && watch.status != WatchStatus.scanning
                  ? null
                  : () => watch.connect(device),
            ),
          ),
        ),
      ],
      if (watch.hasConnected) WatchFocusPanel(watch: watch),
      const Panel(
        child: Column(
          children: [
            DeviceDetail(
              Icons.bluetooth,
              'Live, read-only connection',
              'Heart rate, optical pulse, movement, focus status, and Unc come from the watch. App controls do not change the watch.',
            ),
            Divider(height: 30, color: line),
            DeviceDetail(
              Icons.cloud_off,
              'No cloud or account',
              'Live readings stay in this app session. Reconnecting cannot recover missed history.',
            ),
          ],
        ),
      ),
    ],
  );
}

class WatchFocusPanel extends StatelessWidget {
  const WatchFocusPanel({super.key, required this.watch});
  final WatchController watch;
  @override
  Widget build(BuildContext context) {
    final r = watch.reading;
    return Panel(
      color: lime,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Tag('WATCH FOCUS'),
          const SizedBox(height: 12),
          Text(
            r == null
                ? (watch.connected
                      ? 'Waiting for fresh watch data'
                      : 'Watch disconnected')
                : '${r.phaseLabel} · session ${r.session}/${r.sessions}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (r != null && r.phase != 0) ...[
            const SizedBox(height: 8),
            Text(
              '${r.running ? "Running" : "Paused"} · ${(r.remainingMs / 1000).ceil()} seconds remaining',
            ),
            const Text(
              'Watch uses compressed test durations.',
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

class LiveHealthPage extends StatelessWidget {
  const LiveHealthPage({super.key, required this.watch});
  final WatchController watch;
  @override
  Widget build(BuildContext context) {
    final r = watch.reading;
    return PageBody(
      children: [
        const PageTitle(
          'A moment to check in.',
          'Readings directly from your Uncpanion Watch.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Tag(r != null ? 'LIVE WATCH DATA' : 'NO FRESH DATA'),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.favorite, color: Color(0xFFA76155)),
              const SizedBox(height: 12),
              Text(
                r?.bpm?.toString() ?? '—',
                style: const TextStyle(
                  fontSize: 62,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Text('BPM', style: TextStyle(color: muted)),
              const SizedBox(height: 12),
              Text(
                r?.heartStatus ??
                    (watch.connected
                        ? 'Waiting for fresh readings…'
                        : 'Watch disconnected'),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 120,
                width: double.infinity,
                child: CustomPaint(
                  painter: TrendPainter(
                    watch.pulse,
                    color: const Color(0xFFA76155),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'LIVE OPTICAL PULSE · AUTO-SCALED',
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
        const Panel(
          child: Text(
            'The trace shows recent optical sensor changes. Heart rate is not a stress measurement. Live readings are cleared when the connection is lost or data stops arriving.',
          ),
        ),
      ],
    );
  }
}

class LiveActivityPage extends StatelessWidget {
  const LiveActivityPage({super.key, required this.watch});
  final WatchController watch;
  @override
  Widget build(BuildContext context) {
    final r = watch.reading;
    return PageBody(
      children: [
        const PageTitle(
          'Make space to move.',
          'Movement estimated by your watch.',
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Tag(r != null ? 'LIVE WATCH DATA' : 'NO FRESH DATA'),
        ),
        Panel(
          color: lime,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.directions_walk, size: 36, color: green),
              const SizedBox(height: 16),
              Text(
                r?.movementLabel ?? 'Waiting for your watch',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text(
                r?.acceleration == null
                    ? 'Acceleration unavailable'
                    : '${r!.acceleration!.toStringAsFixed(2)} m/s² acceleration magnitude',
              ),
            ],
          ),
        ),
        const Panel(
          child: Text(
            'A little reset? Relax your shoulders, stretch if comfortable, or take a moment away from the screen.',
          ),
        ),
        const Panel(
          child: Text(
            'The current watch uses a 20-second inactivity test threshold. Movement is an estimate, not a step count. Day/week history is not recorded yet.',
          ),
        ),
      ],
    );
  }
}

class DeviceDetail extends StatelessWidget {
  const DeviceDetail(this.icon, this.title, this.detail, {super.key});
  final IconData icon;
  final String title, detail;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: green, size: 23),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(detail, style: const TextStyle(color: muted, fontSize: 13)),
          ],
        ),
      ),
    ],
  );
}

class RangeToggle extends StatelessWidget {
  const RangeToggle({super.key, required this.week, required this.onChanged});
  final bool week;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ChoiceChip(
        label: const Text('Day'),
        selected: !week,
        onSelected: (_) => onChanged(false),
        showCheckmark: false,
      ),
      const SizedBox(width: 6),
      ChoiceChip(
        label: const Text('Week'),
        selected: week,
        onSelected: (_) => onChanged(true),
        showCheckmark: false,
      ),
    ],
  );
}

class TrendPainter extends CustomPainter {
  TrendPainter(this.values, {this.color = green});
  final List<double> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (int i = 0; i < 3; i++) {
      final y = size.height * (i / 2);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    if (values.length < 2) return;
    final path = Path();
    for (int i = 0; i < values.length; i++) {
      final x = size.width * i / (values.length - 1);
      final y = size.height * (1 - values[i]);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: .17), color.withValues(alpha: .01)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant TrendPainter old) =>
      old.values != values || old.color != color;
}
class BreathingDialog extends StatefulWidget {
  const BreathingDialog({super.key});

  @override
  State<BreathingDialog> createState() => _BreathingDialogState();
}

class _BreathingDialogState extends State<BreathingDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late Timer _timer;
  int _secondsLeft = 10;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    // 2.5초 들숨, 2.5초 날숨 (1회당 5초, 10초 동안 총 2회 세션)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.88, end: 1.12).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft > 1) {
        setState(() {
          _secondsLeft--;
        });
      } else {
        t.cancel();
        _controller.stop();
        setState(() {
          _secondsLeft = 0;
          _isCompleted = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInhaling = _controller.status == AnimationStatus.forward;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: paper,
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isCompleted ? 'Session Completed!' : 'Breathing with Unc',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: ink,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, color: ink),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // reminder unc breathing design
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 130,
              height: 110,
              decoration: BoxDecoration(
                color: const Color(0xFFF4FBCF),
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: ink, width: 3),
                boxShadow: const [
                  BoxShadow(color: Color(0xFFB7D180), offset: Offset(4, 6)),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                _isCompleted
                    ? '^_^'
                    : (isInhaling ? '^_^' : 'U_U'),
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                  fontSize: 39,
                  color: ink,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // texts when breathing
          if (!_isCompleted) ...[
            Text(
              isInhaling ? 'Inhale slowly...' : 'Exhale gently...',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_secondsLeft seconds remaining',
              style: const TextStyle(fontSize: 12, color: muted),
            ),
          ] else ...[
            const Text(
              'Great job taking a moment for yourself! 🌿',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: green,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}