import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:uncpanion/ble/telemetry.dart';
import 'package:uncpanion/ble/transport.dart';
import 'package:uncpanion/ble/watch_controller.dart';

List<int> packet({int sequence = 1, bool finger = true}) {
  final b = ByteData(20);
  b.setUint8(0, 1);
  b.setUint8(1, finger ? 63 : 3);
  b.setUint8(2, finger ? 71 : 255);
  b.setUint8(3, 0);
  b.setUint8(4, 1);
  b.setUint8(5, 1);
  b.setUint8(6, 4);
  b.setUint8(7, 1);
  b.setUint32(8, 4500, Endian.little);
  b.setUint16(12, 980, Endian.little);
  b.setUint32(14, finger ? 100000 : 0, Endian.little);
  b.setUint16(18, sequence, Endian.little);
  return b.buffer.asUint8List();
}

class FakeTransport implements WatchTransport {
  final results = StreamController<WatchDevice>.broadcast();
  void Function(List<int>)? data;
  void Function()? lost;
  bool fail = false;
  Completer<void>? closing;
  int connects = 0;
  @override
  Stream<WatchDevice> get discoveries => results.stream;
  @override
  Future<void> scan() async {}
  @override
  Future<void> stopScan() async {}
  @override
  Future<void> connect(
    String id,
    void Function(List<int>) onData,
    void Function() onLost,
  ) async {
    connects++;
    if (fail) throw StateError('connection failed');
    data = onData;
    lost = onLost;
    onData(packet());
  }

  @override
  Future<void> disconnect() async {
    await closing?.future;
  }
}

void main() {
  test('versioned packet decodes little-endian fields and absent finger', () {
    final r = WatchReading.parse(packet());
    expect(r.bpm, 71);
    expect(r.acceleration, 9.8);
    expect(r.remainingMs, 4500);
    expect(r.ir, 100000);
    expect(r.face, 'o_o');
    expect(r.running, true);
    expect(WatchReading.parse(packet(finger: false)).bpm, isNull);
    expect(() => WatchReading.parse([1, 2]), throwsFormatException);
    final bad = packet();
    bad[0] = 2;
    expect(() => WatchReading.parse(bad), throwsFormatException);
    bad[0] = 1;
    bad[7] = 8;
    expect(() => WatchReading.parse(bad), throwsFormatException);
  });
  test(
    'fresh data expires, resumes, clears on removal and disconnect',
    () async {
      var now = DateTime(2026, 9, 11);
      final transport = FakeTransport();
      final watch = WatchController(
        transport: transport,
        clock: () => now,
        autoTick: false,
        supported: true,
      );
      addTearDown(watch.dispose);
      addTearDown(transport.results.close);
      await watch.connect(const WatchDevice('test', 'Watch'));
      expect(watch.connected, true);
      expect(watch.reading?.bpm, 71);
      now = now.add(const Duration(seconds: 4));
      watch.expire();
      expect(watch.reading, isNull);
      expect(watch.pulse, isEmpty);
      transport.data!(packet(sequence: 2));
      expect(watch.reading?.bpm, 71);
      transport.data!(packet(sequence: 3, finger: false));
      expect(watch.reading?.bpm, isNull);
      expect(watch.pulse, isEmpty);
      transport.lost!();
      expect(watch.connected, false);
      expect(watch.reading, isNull);
      transport.data!(packet(sequence: 4));
      expect(watch.reading, isNull); // late events from old connection ignored
    },
  );
  test(
    'malformed data clears live values and failed connection is not connected',
    () async {
      final transport = FakeTransport();
      final watch = WatchController(
        transport: transport,
        autoTick: false,
        supported: true,
      );
      addTearDown(watch.dispose);
      addTearDown(transport.results.close);
      await watch.connect(const WatchDevice('test', 'Watch'));
      transport.data!([1]);
      expect(watch.reading, isNull);
      expect(watch.error, contains('Unsupported'));
      await watch.disconnect();
      transport.fail = true;
      await watch.connect(const WatchDevice('test', 'Watch'));
      expect(watch.status, WatchStatus.error);
      expect(watch.reading, isNull);
    },
  );
  test(
    'reconnect waits for disconnect cleanup and discards old discovery entries',
    () async {
      final transport = FakeTransport();
      final watch = WatchController(
        transport: transport,
        autoTick: false,
        supported: true,
      );
      addTearDown(watch.dispose);
      addTearDown(transport.results.close);
      await watch.connect(const WatchDevice('test', 'Watch'));
      watch.devices.add(const WatchDevice('test', 'Watch'));
      transport.closing = Completer<void>();
      final close = watch.disconnect();
      expect(watch.status, WatchStatus.disconnecting);
      expect(watch.devices, isEmpty);
      await watch.connect(const WatchDevice('test', 'Watch'));
      expect(transport.connects, 1);
      transport.closing!.complete();
      await close;
      expect(watch.status, WatchStatus.disconnected);
    },
  );
  test('unsupported browser never scans or reports a connection', () async {
    final watch = WatchController(
      supported: false,
      autoTick: false,
      transport: FakeTransport(),
    );
    addTearDown(watch.dispose);
    await watch.scan();
    expect(watch.status, WatchStatus.unsupported);
    expect(watch.connected, false);
  });
}
