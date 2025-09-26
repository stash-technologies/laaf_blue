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
        
        // Set distance at bytes 22-23 (little-endian)
        final distance = expectedDistances[i];
        packetBytes[22] = distance & 0xFF;
        packetBytes[23] = (distance >> 8) & 0xFF;
        
        final packet = StepDataPacket(Uint8List.fromList(packetBytes));
        print('Step $i: Expected=$distance, Actual=${packet.totalDistanceTraveled}');
        
        expect(packet.totalDistanceTraveled, equals(distance));
      }
    });

    test('Test the problematic values from user data', () {
      // Test the pattern: 512, 1024, 1280, 1536, 2048
      // These should actually be: 2, 4, 5, 6, 8
      
      final testCases = [
        {'bytes': [0x02, 0x00], 'expected': 2, 'wrong_value': 512},
        {'bytes': [0x04, 0x00], 'expected': 4, 'wrong_value': 1024},
        {'bytes': [0x05, 0x00], 'expected': 5, 'wrong_value': 1280},
        {'bytes': [0x06, 0x00], 'expected': 6, 'wrong_value': 1536},
        {'bytes': [0x08, 0x00], 'expected': 8, 'wrong_value': 2048},
      ];
      
      for (var testCase in testCases) {
        final packetBytes = List<int>.filled(24, 0);
        packetBytes[0] = 0xD5; // packet type
        final bytes = testCase['bytes'] as List<int>;
        packetBytes[22] = bytes[0];
        packetBytes[23] = bytes[1];
        
        final packet = StepDataPacket(Uint8List.fromList(packetBytes));
        print('Bytes [${bytes[0]}, ${bytes[1]}]: Expected=${testCase['expected']}, Actual=${packet.totalDistanceTraveled}, Wrong=${testCase['wrong_value']}');
        
        expect(packet.totalDistanceTraveled, equals(testCase['expected']), 
               reason: 'Should parse ${bytes} as ${testCase['expected']}, not ${testCase['wrong_value']}');
      }
    });
  });
}
