import 'package:fl_chart/fl_chart.dart'; // Thư viện biểu đồ fl_chart
import 'package:flutter/material.dart';

import '../models/stock.dart'; // StockPricePoint

// =============================================================================
// MiniSparkline — Biểu đồ thu nhỏ trong mỗi card Watchlist
// =============================================================================
//
// "Smart Widget": khác với widget thụ động, MiniSparkline TỰ:
//   1. Gọi API fetchIntradayPrices cho symbol của nó
//   2. Cache kết quả để tránh gọi trùng
//   3. Hiển thị skeleton loading khi đang fetch
//
// CACHE MECHANISM:
//   Static Map `_cache` chia sẻ giữa TẤT CẢ instances MiniSparkline.
//   Key: "FPT|FPT.VN" — unique cho mỗi symbol
//   Value: Future<List<StockPricePoint>> — kết quả đã fetch
//
//   Quan trọng: Cache lưu Future (không phải kết quả).
//   → Nếu 2 Sparkline cùng symbol build gần nhau → chỉ 1 API call được thực hiện.
//   → FutureBuilder của cả 2 share cùng 1 Future → không gọi API 2 lần.
//
// INVALIDATE CACHE:
//   Gọi MiniSparkline.invalidateCache() khi cần force refresh
//   (ví dụ: khi pull-to-refresh ở HomeScreen).
// =============================================================================

import '../services/yahoo_finance_service.dart';

/// Widget biểu đồ thu nhỏ (Sparkline) — hiển thị xu hướng giá trong ngày.
///
/// Dùng trong: [_WatchlistCard] ở HomeScreen — 1 widget/mã cổ phiếu.
class MiniSparkline extends StatefulWidget {
  const MiniSparkline({
    required this.symbol,    // Mã hiển thị: "FPT"
    this.apiSymbol,          // Mã API Yahoo: "FPT.VN" (tùy chọn, tự tính nếu null)
    this.height = 48,        // Chiều cao biểu đồ (pixels)
    this.lineColor,          // Màu đường (null = dùng primary color của theme)
    super.key,
  });

  final String symbol;
  final String? apiSymbol;
  final double height;
  final Color? lineColor;

  // ---------------------------------------------------------------------------
  // Static Cache — Chia sẻ giữa tất cả instances
  // ---------------------------------------------------------------------------

  /// Cache map: key → Future<List<StockPricePoint>>
  ///
  /// `static`: thuộc về CLASS, không phải instance.
  /// Khi widget rebuild (setState ở parent), instance mới được tạo nhưng cache giữ nguyên.
  static final Map<String, Future<List<StockPricePoint>>> _cache =
      <String, Future<List<StockPricePoint>>>{};

  /// Xóa cache để buộc fetch lại data mới.
  ///
  /// [symbol] null → xóa toàn bộ cache
  /// [symbol] có giá trị → chỉ xóa cache của symbol đó
  static void invalidateCache([String? symbol]) {
    if (symbol == null) {
      _cache.clear(); // Xóa hết
    } else {
      final String upper = symbol.toUpperCase();
      // removeWhere: xóa tất cả entries có key bắt đầu bằng "SYMBOL|"
      _cache.removeWhere(
          (String key, Future<List<StockPricePoint>> value) => key.startsWith('$upper|'));
    }
  }

  @override
  State<MiniSparkline> createState() => _MiniSparklineState();
}

class _MiniSparklineState extends State<MiniSparkline> {
  late final String _cacheKey; // Key duy nhất cho cache của sparkline này
  late Future<List<StockPricePoint>> _future;
  final YahooFinanceService _apiService = YahooFinanceService.instance;

  @override
  void initState() {
    super.initState();
    // Key format: "FPT|FPT.VN" — đảm bảo unique cho mỗi cặp symbol/apiSymbol
    _cacheKey = '${widget.symbol.toUpperCase()}|${widget.apiSymbol ?? ''}';

    // ??= operator: chỉ gán/call API nếu _cache[_cacheKey] đang null
    // Nếu đã có trong cache → dùng lại Future đó (không gọi API lần 2)
    _future = MiniSparkline._cache[_cacheKey] ??=
        _apiService.fetchIntradayPrices(widget.symbol, apiSymbol: widget.apiSymbol);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: FutureBuilder<List<StockPricePoint>>(
        // Luôn dùng cache (nếu có) thay vì _future cũ (phòng trường hợp cache được invalidate)
        future: MiniSparkline._cache[_cacheKey] ?? _future,
        builder: (BuildContext context, AsyncSnapshot<List<StockPricePoint>> snapshot) {
          // Đang fetch → hiển thị skeleton (không phải spinner vì quá nhỏ)
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SparklineSkeleton();
          }

          // Không có dữ liệu (API lỗi hoặc trả về rỗng) → hiển thị dấu gạch
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                '—',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            );
          }

          final List<StockPricePoint> points = snapshot.data!;

          // Chuyển StockPricePoint → FlSpot cho fl_chart
          // FlSpot(x, y): x = index (0, 1, 2...), y = giá
          // fl_chart không nhận DateTime trực tiếp → dùng index làm trục x
          final List<FlSpot> spots = <FlSpot>[
            for (int i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i].price),
          ];

          // Tính min/max để fit biểu đồ với data
          double minY = spots.first.y;
          double maxY = spots.first.y;
          for (final FlSpot spot in spots.skip(1)) {
            if (spot.y < minY) minY = spot.y;
            if (spot.y > maxY) maxY = spot.y;
          }
          // Guard: nếu dải giá quá hẹp (< 1đ) → mở rộng ±1 để biểu đồ không phẳng
          if ((maxY - minY).abs() < 1) {
            maxY = maxY + 1;
            minY = minY - 1;
          }

          final Color lineColor = widget.lineColor ?? Theme.of(context).colorScheme.primary;

          return LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),           // Ẩn grid lines
              titlesData: const FlTitlesData(show: false),       // Ẩn trục tọa độ
              borderData: FlBorderData(show: false),             // Ẩn border
              lineTouchData: const LineTouchData(enabled: false),// Tắt touch (sparkline không cần)
              minX: 0,
              maxX: (spots.length - 1).toDouble(),
              minY: minY,
              maxY: maxY,
              lineBarsData: <LineChartBarData>[
                LineChartBarData(
                  spots: spots,
                  isCurved: true,        // Đường cong mượt
                  color: lineColor,
                  barWidth: 2,           // Độ dày đường (nhỏ vì là miniature)
                  dotData: const FlDotData(show: false), // Ẩn các điểm dot
                  // Vùng tô màu dưới đường (gradient từ đậm → trong suốt)
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: <Color>[
                        lineColor.withOpacity(.25), // Đậm hơn ở trên
                        lineColor.withOpacity(.05), // Mờ hơn ở dưới
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// _SparklineSkeleton — Placeholder Loading
// =============================================================================

/// Widget placeholder hiển thị trong khi MiniSparkline đang fetch data.
///
/// Dùng "skeleton loading" pattern (hình dạng đúng, màu xám mờ) thay vì
/// CircularProgressIndicator vì không gian quá nhỏ (48x110 px).
class _SparklineSkeleton extends StatelessWidget {
  const _SparklineSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      // LayoutBuilder: cung cấp BoxConstraints (maxWidth, maxHeight) từ parent
      builder: (BuildContext context, BoxConstraints constraints) {
        return Container(
          height: constraints.maxHeight, // Điền đầy chiều cao nhận được từ parent
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            // surfaceContainerHighest với opacity thấp → màu xám nhẹ của theme
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.3),
          ),
        );
      },
    );
  }
}
