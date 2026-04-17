/// Mô hình dữ liệu đại diện cho một chỉ số thị trường (Ví dụ: VN-INDEX, HNX-INDEX, UPCOM).
class MarketIndex {
  const MarketIndex({
    required this.name,
    required this.value,
    required this.changePercent,
    this.previousClose,
    this.change,
  });

  final String name;           // Tên của chỉ số (vd: VN-INDEX)
  final double value;          // Giá trị điểm số hiện tại
  final double changePercent;  // Phần trăm thay đổi so với phiên trước (%)
  final double? previousClose; // Điểm số đóng cửa phiên trước
  final double? change;        // Mức điểm tăng/giảm tuyệt đối

  /// Trả về true nếu chỉ số tăng điểm (lớn hơn hoặc bằng 0).
  bool get isPositive => changePercent >= 0;
}
