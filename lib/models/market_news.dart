/// Mô hình dữ liệu đại diện cho một bản tin/bài báo tài chính liên quan đến thị trường.
class MarketNews {
  const MarketNews({
    required this.title,
    required this.source,
    required this.publishedAt,
    this.url,
  });

  final String title;        // Tiêu đề bài báo
  final String source;       // Nguồn báo (Ví dụ: CafeF, VnEconomy)
  final DateTime publishedAt;// Thời gian xuất bản
  final String? url;         // Đường dẫn URL gốc tới bài báo

  /// Hàm tính toán thời gian đăng bài so với hiện tại (Ví dụ: "15 phút trước", "2 giờ trước").
  String get timeAgo {
    final Duration difference = DateTime.now().difference(publishedAt);
    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    }
    if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    }
    return '${difference.inDays} ngày trước';
  }
}
