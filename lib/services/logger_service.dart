import 'package:talker_flutter/talker_flutter.dart';

/// Singleton logger instance
final talker = Talker();

/// Logger service wrapper
class LoggerService {
  LoggerService._internal();

  static final LoggerService _instance = LoggerService._internal();

  factory LoggerService() {
    return _instance;
  }

  /// Log info message
  void info(String message, [dynamic data]) {
    talker.info(message, data);
  }

  /// Log error message
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error is Exception) {
      talker.error(message, error, stackTrace);
    } else {
      talker.error(message, Exception(error.toString()), stackTrace);
    }
  }

  /// Log warning message
  void warning(String message, [dynamic data]) {
    talker.warning(message, data);
  }

  /// Log debug message
  void debug(String message, [dynamic data]) {
    talker.debug(message, data);
  }

  /// Log API request
  void logApiCall(String method, String url, {Map<String, dynamic>? params}) {
    talker.debug('API: $method $url', {'params': params});
  }

  /// Log API response
  void logApiResponse(String url, {required int statusCode, required dynamic body}) {
    talker.debug('API Response: $statusCode - $url', body);
  }

  /// Log API error
  void logApiError(String url, {required dynamic error, StackTrace? stackTrace}) {
    talker.error('API Error: $url', error, stackTrace);
  }
}

