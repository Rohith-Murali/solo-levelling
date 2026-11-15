import 'dart:developer' as developer;

abstract final class AppLogger {
  static void unexpected(
    String operation,
    Object error,
    StackTrace stackTrace,
  ) {
    developer.log(
      'Unexpected error during $operation.',
      name: 'solo_levelling',
      level: 1000,
      error: error.runtimeType,
      stackTrace: stackTrace,
    );
  }
}
