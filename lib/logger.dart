import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

/// A logging utility that allows variable logging methods by replacing the core
/// 'log' function. Output goes to [debugPrint] so it appears in the Flutter
/// debug console, and to [dev.log] for DevTools.
class Logger {
  /// If this is false, no logs will be processed.
  static bool shouldLog = true;

  static Function log = (tag, str) {
    if (shouldLog) {
      final message = "[$tag] $str";
      debugPrint(message);
      dev.log(message, name: tag.toString());
    }
  };

  static void logMethod(newLogMethod) {
    Logger.log = (tag, str) {
      if (Logger.shouldLog) {
        newLogMethod(tag, str);
      }
    };
  }

  static void logT(s) {
    Logger.log("Testing", s);
  }

  static void logD(s) {
    Logger.log("Debug", s);
  }

  // general logging / tracking for debugging application history
  static void logG(s) {
    Logger.log("General", s);
  }

  /// Formats [bytes] as space-separated lowercase hex pairs.
  /// When [maxBytes] is set, truncates with a trailing byte count.
  static String formatBytesHex(Uint8List bytes, {int? maxBytes}) {
    final int limit = maxBytes != null && bytes.length > maxBytes ? maxBytes : bytes.length;
    final hex = bytes.take(limit).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    if (maxBytes != null && bytes.length > maxBytes) {
      return '$hex ... (+${bytes.length - maxBytes} bytes)';
    }
    return hex;
  }

  static String packetTypeLabel(int typeId) {
    switch (typeId) {
      case 0xD5:
        return 'Step';
      case 0xE0:
        return 'FSR';
      case 0xD0:
        return 'IMU';
      default:
        return 'unknown';
    }
  }

  /// Logs raw bytes received from an insole (live stream or file chunk).
  static void logInsoleRx(
    String deviceId,
    String foot,
    Uint8List bytes, {
    String source = 'live_stream',
    int? maxBytes,
  }) {
    if (!shouldLog || bytes.isEmpty) return;

    final typeId = bytes[0];
    final typeHex = '0x${typeId.toRadixString(16).padLeft(2, '0')}';
    log(
      'INSOLE_RX',
      'source=$source device=$deviceId foot=$foot '
      'type=$typeHex (${packetTypeLabel(typeId)}) '
      'len=${bytes.length} hex=${formatBytesHex(bytes, maxBytes: maxBytes)}',
    );
  }
}
