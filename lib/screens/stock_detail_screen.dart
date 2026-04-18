import 'package:flutter/cupertino.dart'; // CupertinoSlidingSegmentedControl (iOS style picker)
import 'package:flutter/material.dart';

import '../models/market_news.dart';
import '../models/stock.dart';
import '../services/yahoo_finance_service.dart';
import '../widgets/section_header.dart';
import '../widgets/stock_line_chart.dart';

// =============================================================================
// StockDetailScreen — Màn hình Chi tiết Cổ phiếu
// =============================================================================
//
// Nhận dữ liệu từ navigation arguments (StockDetailArgs):
//   Navigator.pushNamed('/stock-detail', arguments: StockDetailArgs(stock: stock))
//
// LUỒNG DỮ LIỆU:
//   didChangeDependencies() → lấy args từ ModalRoute
//   → _loadStockDetail() → gọi 3 API song song
//     1. fetchIntradayPrices → biểu đồ trong ngày (1D)
//     2. fetchHistoricalPrices → biểu đồ 1 tháng (1M)
//     3. fetchMarketNews → lọc tin liên quan đến mã này
//
// CÁCH CHYỂN BIỂU ĐỒ:
//   CupertinoSlidingSegmentedControl (_ChartRange enum: oneDay/tenDays)
//   → setState → FutureBuilder rebuild → StockLineChart nhận points mới
// =============================================================================

/// Wrapper arguments cho navigation đến StockDetailScreen.
///
/// Dùng class wrapper (thay vì truyền Map hay Stock thẳng) vì:
/// - Type-safe: Navigator.pushNamed nhận `Object?`, không type-check tự động
/// - Extensible: dễ thêm field sau (apiSymbol, từ màn hình nào navigate v.v.)
class StockDetailArgs {
  const StockDetailArgs({required this.stock});

  final Stock stock;
}

/// Màn hình chi tiết mã chứng khoán — biểu đồ giá, thống kê, tin tức liên quan.
class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({super.key});

  /// Named route để navigate: `/stock-detail`
  static const String routeName = '/stock-detail';

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final YahooFinanceService _apiService = YahooFinanceService.instance;

  // Future chứa data biểu đồ + tin tức
  late Future<_StockDetailData> _detailFuture;
  late Stock _stock; // Dữ liệu cổ phiếu cơ bản (giá, tên) nhận từ navigation args

  bool _isInitialized = false; // Cờ tránh re-init khi didChangeDependencies gọi lại

  // Trạng thái tab biểu đồ: 1D hoặc 1M
  _ChartRange _selectedRange = _ChartRange.oneDay;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// Lấy navigation arguments và khởi động load data.
  ///
  /// Dùng didChangeDependencies (không dùng initState) vì:
  /// `ModalRoute.of(context)` cần context đã được kết nối vào widget tree.
  /// initState chạy trước khi context được fully initialized → crash.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return; // Chỉ chạy 1 lần

    // Lấy arguments từ navigation route và cast về StockDetailArgs
    final StockDetailArgs args =
        ModalRoute.of(context)!.settings.arguments as StockDetailArgs;
    _stock = args.stock;
    _detailFuture = _loadStockDetail();
    _isInitialized = true;
  }

  // ---------------------------------------------------------------------------
  // Data Loading
  // ---------------------------------------------------------------------------

  /// Load tất cả data Chi tiết: intraday chart, historical chart, và tin tức.
  ///
  /// Gọi tuần tự (không song song) vì cùng dùng auth manager → tránh race condition.
  Future<_StockDetailData> _loadStockDetail() async {
    // Biểu đồ trong ngày: range=1d, interval=30m → nến 30 phút
    final List<StockPricePoint> intraday = await _apiService.fetchIntradayPrices(
      _stock.symbol,
      apiSymbol: _stock.apiSymbol,
    );

    // Biểu đồ lịch sử 1 tháng: range=1mo, interval=1d → nến ngày
    final List<StockPricePoint> historical = await _apiService.fetchHistoricalPrices(
      _stock.symbol,
      apiSymbol: _stock.apiSymbol,
    );

    // Lọc tin tức liên quan đến mã này (trùng tên mã hoặc tên công ty trong tiêu đề)
    final List<MarketNews> relatedNews = (await _apiService.fetchMarketNews())
        .where((MarketNews news) =>
            news.title.toUpperCase().contains(_stock.symbol.toUpperCase()) ||
            news.title.toUpperCase().contains(_stock.name.toUpperCase()))
        .toList();

    return _StockDetailData(
      intraday: intraday,
      historical: historical,
      // Nếu không có tin liên quan → lấy toàn bộ tin tức thị trường làm fallback
      relatedNews: relatedNews.isEmpty ? await _apiService.fetchMarketNews() : relatedNews,
    );
  }

  // ---------------------------------------------------------------------------
  // Build UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        elevation: 0,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(_stock.symbol, style: Theme.of(context).textTheme.titleMedium),
            Text(
              _stock.name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey),
            ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              // Gán Future mới → FutureBuilder rebuild toàn bộ body
              setState(() {
                _detailFuture = _loadStockDetail();
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_StockDetailData>(
        future: _detailFuture,
        builder: (BuildContext context, AsyncSnapshot<_StockDetailData> snapshot) {
          // Đang load
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Lỗi
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải dữ liệu: ${snapshot.error}'));
          }

          final _StockDetailData data = snapshot.data!;
          final bool positive = _stock.changePercent >= 0;

          // Chọn points biểu đồ theo tab đang chọn
          final List<StockPricePoint> chartPoints =
              _selectedRange == _ChartRange.oneDay ? data.intraday : data.historical;

          // Tính giá cao/thấp trong ngày từ model hoặc tính từ data intraday
          // `??` operator: dùng giá trị sau nếu trước là null
          final double dayHigh = _stock.dayHigh ??
              (data.intraday.isEmpty
                  ? _stock.price
                  : data.intraday
                      .map((StockPricePoint p) => p.price)
                      .reduce((double a, double b) => a > b ? a : b)); // max

          final double dayLow = _stock.dayLow ??
              (data.intraday.isEmpty
                  ? _stock.price
                  : data.intraday
                      .map((StockPricePoint p) => p.price)
                      .reduce((double a, double b) => a < b ? a : b)); // min

          // Tính giá cao/thấp trong biểu đồ đang hiện (1D hoặc 1M)
          final double rangeHigh = chartPoints.isEmpty
              ? _stock.price
              : chartPoints.map((StockPricePoint p) => p.price).reduce((a, b) => a > b ? a : b);

          final double rangeLow = chartPoints.isEmpty
              ? _stock.price
              : chartPoints.map((StockPricePoint p) => p.price).reduce((a, b) => a < b ? a : b);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _detailFuture = _loadStockDetail());
              await _detailFuture;
            },
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: <Widget>[
                // 1. Card tổng quan (giá, % thay đổi, tên)
                _buildOverviewCard(context, positive),
                const SizedBox(height: 20),
                // 2. Segment control chuyển 1D/1M
                _buildSegmentControl(context),
                const SizedBox(height: 16),
                // 3. Biểu đồ giá (dùng fl_chart)
                StockLineChart(points: chartPoints, positive: positive),
                const SizedBox(height: 16),
                // 4. Card số liệu nhanh (giá cao/thấp)
                _buildStatsCard(context, dayHigh, dayLow, rangeHigh, rangeLow),
                const SizedBox(height: 24),
                // 5. Tin tức liên quan
                const SectionHeader(title: 'Tin tức liên quan'),
                if (data.relatedNews.isEmpty)
                  const ListTile(title: Text('Chưa có tin tức liên quan.'))
                else
                  // spread operator `...`: đặt nhiều widget trực tiếp vào children list
                  ...data.relatedNews.map(
                    (MarketNews news) => Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: Text(news.title),
                        subtitle: Text('${news.source} • ${news.timeAgo}'),
                        onTap: () {
                          // TODO: Thêm url_launcher để mở link tin tức (như HomeScreen đã có)
                        },
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

  // ---------------------------------------------------------------------------
  // Builder helpers
  // ---------------------------------------------------------------------------

  /// Card tổng quan: hiển thị giá, % thay đổi với gradient màu xanh/đỏ.
  Widget _buildOverviewCard(BuildContext context, bool positive) {
    final ThemeData theme = Theme.of(context);
    // Màu gradient tùy thuộc chiều tăng/giảm
    final Color startColor = positive ? const Color(0xFF1B5E20) : const Color(0xFFB71C1C);
    final Color endColor = positive ? const Color(0xFF66BB6A) : const Color(0xFFEF5350);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: <Color>[startColor, endColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: endColor.withOpacity(.3),
            offset: const Offset(0, 14),
            blurRadius: 22,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_stock.symbol,
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          // Giá: toStringAsFixed(0) = không có thập phân (giá VND thường là số nguyên)
          Text(
            '${_stock.price.toStringAsFixed(0)} đ',
            style: theme.textTheme.displaySmall
                ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(positive ? Icons.trending_up : Icons.trending_down, color: Colors.white),
              const SizedBox(width: 4),
              // changeValue: computed getter từ Stock model (price * changePercent / 100)
              Text(
                '${_stock.changePercent.toStringAsFixed(2)}% (${_stock.changeValue.toStringAsFixed(0)} đ)',
                style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _stock.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  /// Slider chuyển đổi biểu đồ 1D / 1M (iOS-style segmented control).
  ///
  /// CupertinoSlidingSegmentedControl:
  /// - Generic type `<_ChartRange>`: ràng buộc kiểu giá trị cho type-safety
  /// - groupValue: giá trị đang được chọn
  /// - children: Map từ giá trị → widget hiển thị label
  /// - onValueChanged: callback khi user chọn tab khác → setState rebuild biểu đồ
  Widget _buildSegmentControl(BuildContext context) {
    return CupertinoSlidingSegmentedControl<_ChartRange>(
      backgroundColor:
          Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.4),
      thumbColor: Theme.of(context).colorScheme.primary,
      groupValue: _selectedRange,
      children: const <_ChartRange, Widget>{
        _ChartRange.oneDay: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text('1D'),
        ),
        _ChartRange.tenDays: Padding(
          padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Text('1M'),
        ),
      },
      onValueChanged: (_ChartRange? value) {
        if (value != null) {
          setState(() {
            _selectedRange = value; // Rebuild: StockLineChart dùng points mới
          });
        }
      },
    );
  }

  /// Card số liệu nhanh: giá cao/thấp trong ngày và trong biểu đồ đang xem.
  ///
  /// Wrap tự động ngắt dòng khi không đủ chỗ (thay vì Row bị overflow).
  Widget _buildStatsCard(
    BuildContext context,
    double dayHigh,
    double dayLow,
    double rangeHigh,
    double rangeLow,
  ) {
    final ThemeData theme = Theme.of(context);
    final String rangeLabel = _selectedRange == _ChartRange.oneDay ? 'Biểu đồ 1D' : 'Biểu đồ 1M';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Số liệu nhanh', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            // Wrap: tự ngắt dòng khi row đầy (adaptive grid)
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: <Widget>[
                _StatTile(title: 'Cao (1D)', value: '${dayHigh.toStringAsFixed(0)} đ'),
                _StatTile(title: 'Thấp (1D)', value: '${dayLow.toStringAsFixed(0)} đ'),
                _StatTile(title: 'Cao ($rangeLabel)', value: '${rangeHigh.toStringAsFixed(0)} đ'),
                _StatTile(title: 'Thấp ($rangeLabel)', value: '${rangeLow.toStringAsFixed(0)} đ'),
                // Dùng null-check với `if` trong collection literals (collection-if)
                if (_stock.open != null)
                  _StatTile(title: 'Mở cửa', value: '${_stock.open!.toStringAsFixed(0)} đ'),
                if (_stock.previousClose != null)
                  _StatTile(
                      title: 'Đóng cửa hôm qua',
                      value: '${_stock.previousClose!.toStringAsFixed(0)} đ'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// _ChartRange — Enum điều khiển tab biểu đồ
// =============================================================================

/// Enum đại diện cho khoảng thời gian biểu đồ.
///
/// Dùng enum thay vì int/String vì:
/// - Type-safe: compiler cảnh báo nếu thiếu case
/// - Tự document: `_ChartRange.oneDay` rõ ràng hơn `0` hay `"1d"`
enum _ChartRange {
  oneDay,  // Tab "1D": range=1d, interval=30m (biểu đồ trong ngày)
  tenDays, // Tab "1M": range=1mo, interval=1d (biểu đồ 1 tháng)
}

// =============================================================================
// _StatTile — Widget hiển thị 1 ô số liệu (tiêu đề + giá trị)
// =============================================================================

/// Widget nhỏ hiển thị: tiêu đề mờ + giá trị in đậm bên dưới.
/// Tái sử dụng trong Wrap grid số liệu nhanh.
class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 148, // Cố định chiều rộng để Wrap sắp xếp đều
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title,
              style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)), // Tiêu đề mờ
          const SizedBox(height: 4),
          Text(value,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)), // Giá trị đậm
        ],
      ),
    );
  }
}

// =============================================================================
// _StockDetailData — Container dữ liệu nội bộ màn hình
// =============================================================================

/// Gom 3 loại data cần thiết cho màn hình Chi tiết vào 1 class.
class _StockDetailData {
  const _StockDetailData({
    required this.intraday,
    required this.historical,
    required this.relatedNews,
  });

  final List<StockPricePoint> intraday;  // Điểm giá hôm nay (mỗi 30 phút)
  final List<StockPricePoint> historical; // Điểm giá 1 tháng (mỗi ngày)
  final List<MarketNews> relatedNews;    // Tin tức liên quan đến mã này
}
