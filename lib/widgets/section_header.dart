import 'package:flutter/material.dart';

// =============================================================================
// SectionHeader — Widget tiêu đề section tái sử dụng
// =============================================================================
//
// Dùng để đánh dấu ranh giới giữa các phần nội dung trong màn hình:
//   Ví dụ: "Watchlist" [Xem tất cả]   hoặc   "Tin tức mới nhất"
//
// API:
//   - title (required): Text tiêu đề phía bên trái
//   - onSeeAll (optional): Callback nút "Xem tất cả" — nếu null → ẩn nút
// =============================================================================

/// Widget tiêu đề section tái sử dụng.
///
/// Hiển thị tiêu đề bên trái + nút "Xem tất cả" bên phải (nếu có callback).
/// StatelessWidget vì không có state nội bộ.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll, // null = ẩn nút "Xem tất cả"
  });

  final String title;
  final VoidCallback? onSeeAll; // VoidCallback? = nullable void Function()

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        // spaceBetween: tiêu đề bên trái, nút "Xem tất cả" bên phải
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          // Tiêu đề in đậm
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          // Collection-if: chỉ thêm TextButton nếu onSeeAll != null
          // Tránh phải dùng ternary phức tạp hơn
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll, // Gọi callback được truyền từ ngoài
              child: const Text('Xem tất cả'),
            ),
        ],
      ),
    );
  }
}
