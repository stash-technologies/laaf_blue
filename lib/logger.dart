/// A logging utility that allows variable logging methods by replacing the core
/// 'log' function.  It is sent to 'print' by default.
class Logger {
  /// If this is false, no logs will be processed.
  static bool shouldLog = false;

  static Function log = (tag, str) {
    // the default method is to 'print()'.
    if (shouldLog) {
      print("$tag: $str");
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
