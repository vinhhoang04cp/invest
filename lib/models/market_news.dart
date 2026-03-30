class MarketNews {
  const MarketNews({
    required this.title,
    required this.source,
    required this.publishedAt,
    this.url,
  });

  final String title;
  final String source;
  final DateTime publishedAt;
  final String? url;

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
