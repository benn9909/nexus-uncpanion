import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'browser_support.dart';
import 'telemetry.dart';
import 'transport.dart';

enum WatchStatus {
  disconnected,
  disconnecting,
  scanning,
  connecting,
  connected,
  unsupported,
  error,
}

class WatchController extends ChangeNotifier {
  WatchController({
    WatchTransport? transport,
    DateTime Function()? clock,
    bool? supported,
    bool autoTick = true,
  }) : _transport = transport ?? UniversalWatchTransport(),
       _clock = clock ?? DateTime.now {
    if (!(supported ?? browserSupportsBle)) status = WatchStatus.unsupported;
    if (autoTick)
      _expiry = Timer.periodic(const Duration(seconds: 1), (_) => expire());
  }
  final WatchTransport _transport;
  final DateTime Function() _clock;
  Timer? _scanTimeout, _expiry;
  StreamSubscription<WatchDevice>? _scan;
  int _generation = 0;
  bool _disposed = false;
  bool hasConnected = false;
  bool _fresh = false;
  WatchStatus status = WatchStatus.disconnected;
  String? error, deviceName;
  final List<WatchDevice> devices = [];
  WatchReading? _reading;
  DateTime? lastReceived;
  double? _baseline;
  final List<double> _pulse = [];
  bool get connected => status == WatchStatus.connected;
  bool get busy =>
      status == WatchStatus.scanning ||
      status == WatchStatus.connecting ||
      status == WatchStatus.disconnecting;
  WatchReading? get reading => connected && _fresh ? _reading : null;
  String get label => switch (status) {
    WatchStatus.disconnected => 'Not connected',
    WatchStatus.disconnecting => 'Disconnecting…',
    WatchStatus.scanning => 'Looking for your watch',
    WatchStatus.connecting => 'Connecting…',
    WatchStatus.connected => _fresh ? 'Connected' : 'Waiting for data',
    WatchStatus.unsupported => 'Bluetooth unavailable here',
    WatchStatus.error => 'Connection failed',
  };
  String get guidance => status == WatchStatus.unsupported
      ? 'This browser does not expose Web Bluetooth. Open this preview in a Bluetooth-capable Chrome or Edge browser on your Mac, or use the native phone app. USB alone does not connect the app.'
      : 'Keep the watch powered and nearby. Select Uncpanion Watch when prompted. USB powers the watch; app data travels over Bluetooth.';
  List<double> get pulse {
    if (reading == null || _pulse.length < 2) return [];
    final sorted = [..._pulse]..sort();
    final trim = sorted.length ~/ 10;
    final low = sorted[trim], high = sorted[sorted.length - 1 - trim];
    final span = math.max(80.0, (high - low) * 1.1);
    final center = (high + low) / 2;
    // Invert falling IR so pulse peaks match the OLED.
    return _pulse
        .map((v) => (.5 - (v - center) / span).clamp(0.0, 1.0))
        .toList();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _clear() {
    _reading = null;
    lastReceived = null;
    _fresh = false;
    _pulse.clear();
    _baseline = null;
  }

  Future<void> scan() async {
    if (busy || connected || status == WatchStatus.unsupported || _disposed)
      return;
    final generation = ++_generation;
    devices.clear();
    error = null;
    status = WatchStatus.scanning;
    _notify();
    _scan = _transport.discoveries.listen((d) {
      if (generation != _generation || status != WatchStatus.scanning) return;
      if (!devices.any((item) => item.id == d.id)) {
        devices.add(d);
        _notify();
      }
      // Web Bluetooth emits the selected chooser item before startScan()
      // completes. Connect here so the user does not need a second tap.
      if (kIsWeb) unawaited(_connectBrowserSelection(d, generation));
    });
    if (!kIsWeb)
      _scanTimeout = Timer(const Duration(seconds: 15), () => stopScan());
    try {
      // Called directly by the button to preserve the browser user gesture.
      await _transport.scan();
    } catch (e) {
      if (generation != _generation || _disposed) return;
      await stopScan();
      error =
          'Could not find a watch. Check Bluetooth and permissions, then try Find my watch again.';
      status = WatchStatus.error;
      _notify();
    }
  }

  Future<void> _connectBrowserSelection(WatchDevice device, int generation) async {
    if (_disposed || generation != _generation || status != WatchStatus.scanning) {
      return;
    }
    await connect(device);
  }

  Future<void> stopScan() async {
    _scanTimeout?.cancel();
    _scanTimeout = null;
    await _scan?.cancel();
    _scan = null;
    try {
      await _transport.stopScan();
    } catch (_) {
      /* Already stopped or chooser cancelled. */
    }
    if (status == WatchStatus.scanning) {
      status = WatchStatus.disconnected;
      _notify();
    }
  }

  Future<void> connect(WatchDevice device) async {
    if (status == WatchStatus.connecting ||
        status == WatchStatus.disconnecting ||
        connected ||
        _disposed)
      return;
    final generation = ++_generation;
    status = WatchStatus.connecting;
    _notify();
    await stopScan();
    if (_disposed || generation != _generation) return;
    _clear();
    error = null;
    deviceName = device.name;
    status = WatchStatus.connecting;
    _notify();
    try {
      await _transport.disconnect();
      await _transport.connect(
        device.id,
        (bytes) {
          if (generation == _generation && !_disposed) accept(bytes);
        },
        () {
          if (generation != _generation || _disposed) return;
          unawaited(disconnect());
        },
      );
      if (_disposed || generation != _generation) {
        await _transport.disconnect();
        return;
      }
      hasConnected = true;
      status = WatchStatus.connected;
      _notify();
    } catch (e) {
      if (generation != _generation || _disposed) return;
      ++_generation;
      await _transport.disconnect().catchError((_) {});
      _clear();
      devices.clear();
      status = WatchStatus.error;
      error =
          'Could not connect. Use Find my watch to select it again. Keep the watch nearby and close any other app using it.';
      _notify();
    }
  }

  @visibleForTesting
  void accept(List<int> bytes) {
    if (status != WatchStatus.connecting && !connected) return;
    try {
      final next = WatchReading.parse(bytes);
      if (_reading?.sequence == next.sequence) return;
      _reading = next;
      lastReceived = _clock();
      _fresh = true;
      error = null;
      if (!next.sensorOK || !next.finger) {
        _pulse.clear();
        _baseline = null;
      } else {
        _baseline ??= next.ir.toDouble();
        _baseline = _baseline! + .08 * (next.ir - _baseline!);
        _pulse.add(next.ir - _baseline!);
        if (_pulse.length > 64) _pulse.removeAt(0);
      }
      _notify();
    } on FormatException {
      error =
          'Unsupported watch data. App and firmware need matching protocol versions.';
      _clear();
      _notify();
    }
  }

  void expire() {
    if (_fresh &&
        lastReceived != null &&
        _clock().difference(lastReceived!) >= const Duration(seconds: 3)) {
      _fresh = false;
      _pulse.clear();
      _baseline = null;
      _notify();
    }
  }

  Future<void> disconnect() async {
    if (status == WatchStatus.disconnecting) return;
    final generation = ++_generation;
    _clear();
    devices.clear();
    status = WatchStatus.disconnecting;
    _notify();
    await stopScan();
    await _transport.disconnect().catchError((_) {});
    if (!_disposed && generation == _generation) {
      status = WatchStatus.disconnected;
      _notify();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _expiry?.cancel();
    _scanTimeout?.cancel();
    unawaited(_scan?.cancel());
    unawaited(_transport.disconnect().catchError((_) {}));
    super.dispose();
  }
}
