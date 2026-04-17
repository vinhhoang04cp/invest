import 'package:flutter/material.dart';

/// Widget Title dùng chung, hiển thị tiêu đề in đậm kèm theo nút "Xem tất cả" ở góc phải.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.onSeeAll,
  });

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Text(title, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          if (onSeeAll != null)
            TextButton(
              onPressed: onSeeAll,
              child: const Text('Xem tất cả'),
            ),
        ],
      ),
    );
  }
}
