import 'dart:typed_data';

import 'package:blue/logger.dart';

/// Data from a step packet.
class StepDataPacket {
  StepDataPacket(this.rawPacket)
      : timestamp = _convertSubList(rawPacket, 1, 4),
        heelStrikeAngle = _convertSubList(rawPacket, 5, 6) / 100,
        pronationAngle = _convertSubList(rawPacket, 7, 8, signed: true) / 100,
        cadence = _convertSubList(rawPacket, 9, 9),
        speed = _convertSubList(rawPacket, 10, 11) / 1000,
        strideTime = _convertSubList(rawPacket, 12, 13),
        strideLength = _convertSubList(rawPacket, 14, 14) / 10,
        contactTime = _convertSubList(rawPacket, 15, 16),
        swingTime = _convertSubList(rawPacket, 17, 18),
        stepClearance = _convertSubList(rawPacket, 19, 19),
        totalNumberOfSteps = _convertSubList(rawPacket, 20, 21),
        totalDistanceTraveled = (() {
          final rawDistance = _convertSubListLittleEndian(rawPacket, 22, 23);
          // Filter out invalid values (65535 = 0xFFFF indicates error/uninitialized)
          if (rawDistance >= 65535) {
            // Calculate distance from steps and stride length if insole distance is invalid
            final steps = _convertSubList(rawPacket, 20, 21);
            final stride = _convertSubList(rawPacket, 14, 14) / 10;
            final calculatedDistance = steps * stride;
            Logger.log('STEP_DATA_PACKET DEBUG', 'Using calculated distance: $calculatedDistance (Steps: $steps × Stride: $stride)');
            return calculatedDistance;
          }
          return rawDistance;
        })() {
    // Debug logging for step count and distance correlation
    Logger.log('STEP_DATA_PACKET DEBUG', 'Steps: $totalNumberOfSteps, Distance: $totalDistanceTraveled');
  }

  static num _convertSubList(Uint8List list, int lower, int upper, {bool signed = false}) {
    ByteData data = list.sublist(lower, upper + 1).buffer.asByteData();

    int result = 0;

    switch (upper - lower) {
      case 0:
        result = data.getUint8(0);
      case 1:
        result = data.getInt16(0);

        if (!signed) {
          result = result.toUnsigned(16);
        }
      default:
        result = data.getInt32(0);

        if (!signed) {
          result = result.toUnsigned(32);
        }
    }

    return result;
  }

  static num _convertSubListLittleEndian(Uint8List list, int lower, int upper, {bool signed = false}) {
    ByteData data = list.sublist(lower, upper + 1).buffer.asByteData();

    int result = 0;

    switch (upper - lower) {
      case 0:
        result = data.getUint8(0);
      case 1:
        if (signed) {
          result = data.getInt16(0, Endian.little);
        } else {
          result = data.getUint16(0, Endian.little);
        }

      default:
        if (signed) {
          result = data.getInt32(0, Endian.little);
        } else {
          result = data.getUint32(0, Endian.little);
        }
    }
    
    // Only log for distance field (bytes 22-23)
    if (lower == 22 && upper == 23) {
      Logger.log('STEP_DATA_PACKET DEBUG', 'Distance bytes [${list[22]}, ${list[23]}] -> little-endian: $result');
    }

    return result;
  }

  static num toTwoDecimal(num input) {
    return num.parse(input.toStringAsFixed(2));
  }

  /// Milliseonds since the start of logging.
  final num timestamp;

  /// Degrees
  final num heelStrikeAngle;

  /// Degrees
  final num pronationAngle;

  /// Steps per minute
  final num cadence;

  /// Meters / second
  final num speed;

  /// Milliseconds per step
  final num strideTime;

  /// Meters per step
  final num strideLength;

  /// Milliseconds between heel strike and toe off
  final num contactTime;

  /// Milliseconds
  final num swingTime;

  /// Millimeters.
  final num stepClearance;

  final num totalNumberOfSteps;
  final num totalDistanceTraveled;

  // The below values require multiple steps to calculate, and are therefore
  // only updated after a certain number of steps have occurred.

  // final num Symmmetry
  // final num singleLegSupport
  // final num doubleLegSupport

  /// The unparsed packet.
  final Uint8List rawPacket;

  static StepDataPacket empty() {
    return StepDataPacket(Uint8List.fromList([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]));
  }

  static StepDataPacket test() {
    return StepDataPacket(
      Uint8List.fromList([
        0xD5,
        0x00,
        0x00,
        0x04,
        0xB0,
        0x02,
        0xD3,
        0xFE,
        0x4B,
        0x65,
        0x07,
        0x9B,
        0x02,
        0x4C,
        0x39,
        0x00,
        0x67,
        0x01,
        0xE5,
        0x06,
        0x01,
        0xA4,
        0x02,
        0x58,
      ]),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "timestamp": timestamp.toString(),
      "heelStrikeAngle": heelStrikeAngle,
      "pronationAngle": pronationAngle,
      "cadence": cadence,
      "speed": speed,
      "strideTime": strideTime,
      "strideLength": strideLength,
      "contactTime": contactTime,
      "swingTime": swingTime,
      "stepClearance": stepClearance,
      "totalNumberOfSteps": totalNumberOfSteps,
      "totalDistanceTraveled": totalDistanceTraveled,
    };
  }
}
