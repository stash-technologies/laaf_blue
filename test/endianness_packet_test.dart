import 'dart:typed_data';
import 'package:blue/imu_packet.dart';
import 'package:blue/fsr_packet.dart';
import 'package:blue/lf_liner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Endianness & Packet Parsing Tests', () {
    test('IMUPacket parses Big-Endian fields correctly', () {
      final packet = IMUPacket.test();

      // Timestamp: 0x00000065 = 101s, 0x03E8 = 1000ms -> 102.0s
      expect(packet.timestamp, equals(102.0));

      // AccX: 0x4000 = 16384 -> 16384 / 16384.0 = 1.0g
      expect(packet.accX, equals(1.0));
      expect(packet.accY, equals(0.0));
      expect(packet.accZ, equals(0.0));

      // GyroX: 0x1000 = 4096 -> 4096 / 16384.0 = 0.25 deg/s
      expect(packet.gyroX, equals(0.25));
      expect(packet.gyroY, equals(0.0));
      expect(packet.gyroZ, equals(0.0));
    });

    test('IMUPacket with 33-byte live format parses nested FSR as Big-Endian', () {
      final bytes = Uint8List(33);
      bytes[0] = 0xD0; // IMU packet ID
      // FSR1 at bytes 19-20: 0x01F4 = 500
      bytes[19] = 0x01;
      bytes[20] = 0xF4;

      final packet = IMUPacket(bytes);
      expect(packet.hasFSRData(), isTrue);
      expect(packet.fsrs[0], equals(500));
    });

    test('FSRPacket parses live Big-Endian stream correctly', () {
      final bytes = Uint8List(21);
      bytes[0] = 0xE0; // FSR packet ID
      // Timestamp seconds: 0x00000064 = 100
      bytes[1] = 0x00;
      bytes[2] = 0x00;
      bytes[3] = 0x00;
      bytes[4] = 0x64;
      // FSR1 at bytes 7-8: 0x03E8 = 1000
      bytes[7] = 0x03;
      bytes[8] = 0xE8;

      final packet = FSRPacket(bytes);
      expect(packet.timestamp, equals(100.0));
      expect(packet.fsrs[0], equals(1000));
    });

    test('LFLiner parseRawFSRDataPacket parses Big-Endian file data matching live format', () {
      final liner = LFLiner('test-device', 'test-liner');
      final bytes = Uint8List(21);
      bytes[0] = 0xE0;
      // Timestamp seconds: 100
      bytes[4] = 0x64;
      // Timestamp ms: 500 = 0x01F4
      bytes[5] = 0x01;
      bytes[6] = 0xF4;
      // FSR1: 1000 = 0x03E8
      bytes[7] = 0x03;
      bytes[8] = 0xE8;

      final result = liner.parseRawFSRDataPacket(bytes);
      expect(result['timestampSeconds'], equals(100));
      expect(result['timestampMilliseconds'], equals(500));
      expect(result['fsr1'], equals(1000));
    });

    test('LFLiner parseRawIMUDataPacket parses Big-Endian file data', () {
      final liner = LFLiner('test-device', 'test-liner');
      final bytes = Uint8List(19);
      bytes[0] = 0xD0;
      // Timestamp seconds: 100
      bytes[4] = 0x64;
      // Timestamp ms: 500 = 0x01F4
      bytes[5] = 0x01;
      bytes[6] = 0xF4;
      // AccX: 16384 = 0x4000 -> 1.0g
      bytes[7] = 0x40;
      bytes[8] = 0x00;

      final result = liner.parseRawIMUDataPacket(bytes);
      expect(result['timestampSeconds'], equals(100));
      expect(result['timestampMilliseconds'], equals(500));
      expect(result['accX'], equals(1.0));
    });
  });
}
