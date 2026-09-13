import 'dart:async';
import 'package:universal_ble/universal_ble.dart';
import 'telemetry.dart';

class WatchDevice {
  const WatchDevice(this.id, this.name);
  final String id, name;
}

abstract class WatchTransport {
  Stream<WatchDevice> get discoveries;
  Future<void> scan();
  Future<void> stopScan();
  Future<void> connect(
    String id,
    void Function(List<int>) onData,
    void Function() onLost,
  );
  Future<void> disconnect();
}

class UniversalWatchTransport implements WatchTransport {
  String? _deviceId;
  StreamSubscription<bool>? _connection;
  StreamSubscription<List<int>>? _values;
  @override
  Stream<WatchDevice> get discoveries => UniversalBle.scanStream.map(
    (d) => WatchDevice(d.deviceId, d.name ?? 'Uncpanion Watch'),
  );
  @override
  Future<void> scan() => UniversalBle.startScan(
    scanFilter: ScanFilter(withServices: [watchService]),
  );
  @override
  Future<void> stopScan() => UniversalBle.stopScan();
  @override
  Future<void> connect(
    String id,
    void Function(List<int>) onData,
    void Function() onLost,
  ) async {
    _deviceId = id;
    await UniversalBle.connect(id, timeout: const Duration(seconds: 15));
    _connection = UniversalBle.connectionStream(id).listen((connected) {
      if (!connected) onLost();
    });
    final device = BleDevice(deviceId: id, name: null);
    await device.discoverServices();
    final characteristic = await device.getCharacteristic(
      watchCharacteristic,
      service: watchService,
    );
    _values = characteristic.onValueReceived.listen(
      onData,
      onError: (_) => onLost(),
    );
    await characteristic.notifications.subscribe();
    onData(await characteristic.read());
  }

  @override
  Future<void> disconnect() async {
    await _values?.cancel();
    await _connection?.cancel();
    _values = null;
    _connection = null;
    final id = _deviceId;
    _deviceId = null;
    if (id != null) await UniversalBle.disconnect(id);
  }
}
