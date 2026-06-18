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
}
