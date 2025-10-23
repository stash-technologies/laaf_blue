import 'dart:typed_data';

/// The IMU packet containing accelerometer and gyroscope data.
/// Packet format: 19 bytes total, Little-Endian
/// Raw IMU data with Unix timestamp for offline logging validation.
class IMUPacket {
  IMUPacket(this.rawPacket)
      : timestamp = _getTimestamp(rawPacket.sublist(1, 7)),
        accX = _convertRawToG(rawPacket.sublist(7, 9)),
        accY = _convertRawToG(rawPacket.sublist(9, 11)),
        accZ = _convertRawToG(rawPacket.sublist(11, 13)),
        gyroX = _convertRawToDegPerSec(rawPacket.sublist(13, 15)),
        gyroY = _convertRawToDegPerSec(rawPacket.sublist(15, 17)),
        gyroZ = _convertRawToDegPerSec(rawPacket.sublist(17, 19));

  final Uint8List rawPacket;

  /// Timestamp in seconds (with millisecond precision)
  final num timestamp;

  /// Acceleration X-axis in g (gravity units)
  final num accX;

  /// Acceleration Y-axis in g (gravity units)
  final num accY;

  /// Acceleration Z-axis in g (gravity units)
  final num accZ;

  /// Gyroscope X-axis in degrees/second
  final num gyroX;

  /// Gyroscope Y-axis in degrees/second
  final num gyroY;

  /// Gyroscope Z-axis in degrees/second
  final num gyroZ;

  /// Parses timestamp from bytes 1-6 (seconds + milliseconds)
  static num _getTimestamp(Uint8List timestampBytes) {
    final data = ByteData.sublistView(timestampBytes);
    
    // Bytes 0-3: Unix timestamp in seconds (little-endian)
    int seconds = data.getUint32(0, Endian.little);
    
    // Bytes 4-5: milliseconds (little-endian)
    int milliseconds = data.getUint16(4, Endian.little);
    
    // Return timestamp with millisecond precision
    return num.parse((seconds + (milliseconds / 1000.0)).toStringAsFixed(3));
  }

  /// Converts raw accelerometer data to g (gravity units)
  /// Raw units: 16,384 AD/g @ 2g scale
  static num _convertRawToG(Uint8List rawBytes) {
    final data = ByteData.sublistView(rawBytes);
    int rawValue = data.getInt16(0, Endian.little);
    
    // Convert to g: raw / 16384
    return num.parse((rawValue / 16384.0).toStringAsFixed(6));
  }

  /// Converts raw gyroscope data to degrees/second
  /// Raw units: 16,384 AD/g @ 2g scale (per documentation)
  /// Note: Typically gyroscope uses different scaling, but following the docs
  static num _convertRawToDegPerSec(Uint8List rawBytes) {
    final data = ByteData.sublistView(rawBytes);
    int rawValue = data.getInt16(0, Endian.little);
    
    // Convert using the same scale as accelerometer per documentation
    return num.parse((rawValue / 16384.0).toStringAsFixed(6));
  }

  /// Creates an empty IMU packet for initialization
  static IMUPacket empty() {
    return IMUPacket(Uint8List.fromList([0xD0, ...List.filled(18, 0)]));
  }

  /// Creates a test IMU packet with sample data
  static IMUPacket test() {
    return IMUPacket(Uint8List.fromList([
      0xD0, // Packet ID
      0x00, 0x00, 0x00, 0x65, // Timestamp seconds (example)
      0xE8, 0x03, // Timestamp milliseconds (1000ms)
      0x00, 0x40, // AccX (16384 = 1g)
      0x00, 0x00, // AccY (0g)
      0x00, 0x00, // AccZ (0g)
      0x00, 0x10, // GyroX (4096)
      0x00, 0x00, // GyroY (0)
      0x00, 0x00, // GyroZ (0)
    ]));
  }

  /// Converts the packet to JSON format
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp,
      'accX': accX,
      'accY': accY,
      'accZ': accZ,
      'gyroX': gyroX,
      'gyroY': gyroY,
      'gyroZ': gyroZ,
    };
  }

  @override
  String toString() {
    return 'IMUPacket(timestamp: $timestamp, acc: [$accX, $accY, $accZ], gyro: [$gyroX, $gyroY, $gyroZ])';
  }
}
