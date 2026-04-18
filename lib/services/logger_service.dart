import 'package:talker_flutter/talker_flutter.dart';

/// Thể hiện (instance) chung duy nhất (Singleton) của thư viện Talker.
final talker = Talker();

/// Lớp dịch vụ (Service layer) bao bọc thư viện Talker.
/// Nhiệm vụ: Ghi chép (log) hệ thống, quản lý lỗi (error log) và theo dõi luồng gọi API.
class LoggerService {
  LoggerService._internal();

  static final LoggerService _instance = LoggerService._internal();

  factory LoggerService() {
    return _instance;
  }

  /// Ghi chép (log) thông tin thông thường.
  void info(String message, [dynamic data]) {
    talker.info(message, data);
  }

  /// Ghi chép cảnh báo lỗi (đỏ) kèm theo dấu vết (StackTrace) để dễ debug.
  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (error is Exception) {
      talker.error(message, error, stackTrace);
    } else {
      talker.error(message, Exception(error.toString()), stackTrace);
    }
  }

  /// Ghi chép cảnh báo (warning) cho các trường hợp không mong muốn nhưng chưa gây sập ứng dụng.
  void warning(String message, [dynamic data]) {
    talker.warning(message, data);
  }

  /// Theo dõi ghi chép (debug) dùng cho lập trình viên theo dõi biến số.
  void debug(String message, [dynamic data]) {
    talker.debug(message, data);
  }

  /// Lưu vết một chiều gọi mạng (API Request) với thông tin Method và URL kèm params nếu có.
  void logApiCall(String method, String url, {Map<String, dynamic>? params}) {
    talker.debug('API: $method $url', {'params': params});
  }

  /// Lưu vết dữ liệu máy chủ trả về (API Response), bao gồm mã kết quả và độ dài gói tin.
  void logApiResponse(String url, {required int statusCode, required dynamic body}) {
    talker.debug('API Response: $statusCode - $url', body);
  }

  /// Ghi chép chi tiết của một response lỗi lúc gọi API.
  void logApiError(String url, {required dynamic error, StackTrace? stackTrace}) {
    talker.error('API Error: $url', error, stackTrace);
  }
}

