import 'dart:async';

/// Lớp tiện ích giúp cản trở việc gọi hàm quá nhanh / liên tục (Debounce).
/// Ví dụ: Gõ tìm kiếm mã cổ phiếu chậm lại 500ms thay vì gõ chữ nào gọi API chữ đó.
class Debouncer {
  Debouncer({required this.delay});

  final Duration delay;
  Timer? _timer;

  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
