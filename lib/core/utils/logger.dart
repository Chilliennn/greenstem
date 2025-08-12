import 'dart:developer' as developer;

class Logger {
  static void log(String message, {String? name}) {
    developer.log(message, name: name ?? 'GreenStem');
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    developer.log(
      message,
      name: 'GreenStem Error',
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void info(String message) {
    log(message, name: 'Info');
  }

  static void debug(String message) {
    log(message, name: 'Debug');
  }
}
