import 'dart:developer' as developer;

enum LogLevel { debug, info, warning, error }

class AppLogger {
  final String tag;
  final bool enableVerbose;

  const AppLogger({this.tag = 'App', this.enableVerbose = true});

  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    if (!enableVerbose) return;
    _log(LogLevel.debug, message, error, stackTrace);
  }

  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.info, message, error, stackTrace);
  }

  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.warning, message, error, stackTrace);
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _log(LogLevel.error, message, error, stackTrace);
  }

  void _log(LogLevel level, String message, Object? error, StackTrace? stackTrace) {
    final prefix = '[${level.name.toUpperCase()}][$tag]';
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final formatted = '$timestamp $prefix $message';

    developer.log(
      formatted,
      time: DateTime.now(),
      level: _levelToInt(level),
      name: tag,
      error: error,
      stackTrace: stackTrace,
    );
  }

  int _levelToInt(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
