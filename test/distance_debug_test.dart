import 'dart:typed_data';
import 'package:blue/step_data_packet.dart';
import 'package:test/test.dart';

void main() {
  group('Distance Calculation Debug', () {
    test('Test all values from sample packet', () {
      // Test packet from StepDataPacket.test()
      final testPacket = StepDataPacket.test();
      print('=== StepDataPacket.test() values ===');
      print('timestamp: ${testPacket.timestamp}');
      print('heelStrikeAngle: ${testPacket.heelStrikeAngle}');
      print('pronationAngle: ${testPacket.pronationAngle}');
      print('cadence: ${testPacket.cadence}');
      print('speed: ${testPacket.speed}');
      print('strideTime: ${testPacket.strideTime}');
      print('strideLength: ${testPacket.strideLength}');
      print('contactTime: ${testPacket.contactTime}');
      print('swingTime: ${testPacket.swingTime}');
      print('stepClearance: ${testPacket.stepClearance}');
      print('totalNumberOfSteps: ${testPacket.totalNumberOfSteps}');
      print('totalDistanceTraveled: ${testPacket.totalDistanceTraveled}');
      
      // Check if values are reasonable
      expect(testPacket.speed, greaterThanOrEqualTo(0));
      expect(testPacket.cadence, greaterThanOrEqualTo(0));
      expect(testPacket.strideTime, greaterThanOrEqualTo(0));
    });
    
    test('Test realistic distance progression', () {
      // Simulate what should happen in first few steps
      List<int> expectedDistances = [0, 1, 2, 3, 4]; // meters
      
      for (int i = 0; i < expectedDistances.length; i++) {
        // Create packet with realistic distance
        final packetBytes = List<int>.filled(24, 0);
        packetBytes[0] = 0xD5; // packet type
        
        // Set distance at bytes 22-23 (big-endian: MSB first)
        final distance = expectedDistances[i];
        packetBytes[22] = (distance >> 8) & 0xFF;
        packetBytes[23] = distance & 0xFF;
        
        final packet = StepDataPacket(Uint8List.fromList(packetBytes));
        print('Step $i: Expected=$distance, Actual=${packet.totalDistanceTraveled}');
        
        expect(packet.totalDistanceTraveled, equals(distance));
      }
    });

    test('Verify Big-Endian byte order for distance values', () {
      // In Big-Endian, MSB is at byte 22 and LSB is at byte 23.
      // E.g., 2 meters is [0x00, 0x02], 4 meters is [0x00, 0x04].
      final testCases = [
        {'bytes': [0x00, 0x02], 'expected': 2},
        {'bytes': [0x00, 0x04], 'expected': 4},
        {'bytes': [0x00, 0x05], 'expected': 5},
        {'bytes': [0x00, 0x06], 'expected': 6},
        {'bytes': [0x00, 0x08], 'expected': 8},
      ];
      
      for (var testCase in testCases) {
        final packetBytes = List<int>.filled(24, 0);
        packetBytes[0] = 0xD5; // packet type
        final bytes = testCase['bytes'] as List<int>;
        packetBytes[22] = bytes[0];
        packetBytes[23] = bytes[1];
        
        final packet = StepDataPacket(Uint8List.fromList(packetBytes));
        print('Bytes [${bytes[0]}, ${bytes[1]}]: Expected=${testCase['expected']}, Actual=${packet.totalDistanceTraveled}');
        
        expect(packet.totalDistanceTraveled, equals(testCase['expected']), 
               reason: 'Should parse $bytes as ${testCase['expected']}');
      }
    });
  });
}
