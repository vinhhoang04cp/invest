import 'dart:async'; // Timer

// =============================================================================
// Debouncer — Tiện ích chống gọi hàm quá nhanh liên tiếp
// =============================================================================
//
// VẤN ĐỀ: Khi user gõ từ khóa tìm kiếm "VCB":
//   - Gõ "V" → gọi API
//   - Gõ "VC" → gọi API lại (lần đầu chưa xong!)
//   - Gõ "VCB" → gọi API lần 3
//   → Lãng phí tài nguyên, kết quả không đoán được
//
// GIẢI PHÁP với Debounce:
//   - Mỗi lần run() được gọi → hủy Timer cũ, đặt Timer mới
//   - Chỉ thực thi action sau [delay] ms KHÔNG có run() tiếp theo
//   → Gõ "VCB" nhanh → chỉ 1 API call sau 500ms dừng gõ
//
// SỬ DỤNG ĐIỂN HÌNH:
//   final debouncer = Debouncer(delay: Duration(milliseconds: 500));
//   textField.onChanged = (query) => debouncer.run(() => searchSymbols(query));
//
// LƯU Ý: Phải gọi debouncer.dispose() khi widget bị destroy để hủy timer.
// =============================================================================

/// Tiện ích debounce — trì hoãn và gộp nhiều lần gọi thành 1.
class Debouncer {
  Debouncer({required this.delay});

  final Duration delay; // Khoảng thời gian chờ sau lần gọi cuối

  Timer? _timer; // Timer hiện tại (null nếu chưa/đã chạy xong)

  /// Lên lịch chạy [action] sau [delay].
  ///
  /// Nếu được gọi lại trước khi timer expire → hủy timer cũ, đặt timer mới.
  /// Đây chính là cơ chế debounce.
  void run(void Function() action) {
    _timer?.cancel(); // Hủy timer cũ nếu đang chờ (?.cancel() = null-safe call)
    _timer = Timer(delay, action); // Đặt timer mới với action cần chạy
  }

  /// Hủy timer đang pending (nếu có) và giải phóng tài nguyên.
  ///
  /// Gọi trong dispose() của widget để tránh timer chạy sau khi widget bị destroy.
  void dispose() {
    _timer?.cancel();
  }
}
