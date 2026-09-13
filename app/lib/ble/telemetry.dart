import 'dart:typed_data';

const watchService = 'b7d10001-6a2b-4c3d-8e9f-102030405060';
const watchCharacteristic = 'b7d10002-6a2b-4c3d-8e9f-102030405060';

class WatchReading {
  WatchReading._(
    this.flags,
    this.bpm,
    this.movement,
    this.phase,
    this.session,
    this.sessions,
    this.mood,
    this.remainingMs,
    this.acceleration,
    this.ir,
    this.sequence,
  );
  final int flags,
      movement,
      phase,
      session,
      sessions,
      mood,
      remainingMs,
      ir,
      sequence;
  final int? bpm;
  final double? acceleration;
  bool get sensorOK => flags & 1 != 0;
  bool get imuOK => flags & 2 != 0;
  bool get finger => flags & 4 != 0;
  bool get ready => flags & 8 != 0;
  bool get running => flags & 32 != 0;
  String get heartStatus => !sensorOK
      ? 'Sensor error'
      : !finger
      ? 'Place finger on the watch'
      : !ready
      ? 'Reading…'
      : bpm == null
      ? 'Hold still'
      : 'Live heart rate';
  String get movementLabel => switch (movement) {
    0 => 'Still',
    1 => 'Moving',
    2 => 'Inactive',
    _ => 'Sensor unavailable',
  };
  String get phaseLabel => switch (phase) {
    0 => 'Setup',
    1 => 'Focus',
    2 => 'Short break',
    _ => 'Long break',
  };
  String get face => const ['^_^', 'o_o', '-_-', '^o^', 'o_o'][mood];

  factory WatchReading.parse(List<int> bytes) {
    if (bytes.length != 20 || bytes[0] != 1)
      throw const FormatException('Unsupported watch packet');
    final b = ByteData.sublistView(Uint8List.fromList(bytes));
    final flags = bytes[1];
    final bpmValid = flags & 16 != 0;
    if (bytes[4] > 3 ||
        bytes[7] > 4 ||
        bytes[5] < 1 ||
        bytes[6] < 1 ||
        bytes[6] > 8 ||
        bytes[5] > bytes[6] ||
        ![0, 1, 2, 255].contains(bytes[3]) ||
        flags & 192 != 0 ||
        (bpmValid && (bytes[2] < 50 || bytes[2] > 140 || flags & 13 != 13))) {
      throw const FormatException('Invalid watch values');
    }
    return WatchReading._(
      flags,
      bpmValid ? bytes[2] : null,
      bytes[3],
      bytes[4],
      bytes[5],
      bytes[6],
      bytes[7],
      b.getUint32(8, Endian.little),
      flags & 2 != 0 && b.getUint16(12, Endian.little) != 65535
          ? b.getUint16(12, Endian.little) / 100
          : null,
      b.getUint32(14, Endian.little),
      b.getUint16(18, Endian.little),
    );
  }
}
