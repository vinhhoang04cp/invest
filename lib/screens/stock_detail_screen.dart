import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models/market_news.dart';
import '../models/stock.dart';
import '../services/api_service.dart';
import '../widgets/section_header.dart';
import '../widgets/stock_line_chart.dart';

class StockDetailArgs {
  const StockDetailArgs({required this.stock});

  final Stock stock;
}

class StockDetailScreen extends StatefulWidget {
  const StockDetailScreen({super.key});

  static const String routeName = '/stock-detail';

  @override
  State<StockDetailScreen> createState() => _StockDetailScreenState();
}

class _StockDetailScreenState extends State<StockDetailScreen> {
  final ApiService _apiService = ApiService.instance;
  late Future<_StockDetailData> _detailFuture;
  late Stock _stock;
  bool _isInitialized = false;
  _ChartRange _selectedRange = _ChartRange.oneDay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInitialized) return;
    final StockDetailArgs args = ModalRoute.of(context)!.settings.arguments as StockDetailArgs;
    _stock = args.stock;
    _detailFuture = _loadStockDetail();
    _isInitialized = true;
  }

  Future<_StockDetailData> _loadStockDetail() async {
    final List<StockPricePoint> intraday = await _apiService.fetchIntradayPrices(
      _stock.symbol,
      apiSymbol: _stock.apiSymbol,
    );
    final List<StockPricePoint> historical = await _apiService.fetchHistoricalPrices(
      _stock.symbol,
      apiSymbol: _stock.apiSymbol,
    );
    final List<MarketNews> relatedNews = (await _apiService.fetchMarketNews())
        .where((MarketNews news) =>
            news.title.toUpperCase().contains(_stock.symbol.toUpperCase()) ||
            news.title.toUpperCase().contains(_stock.name.toUpperCase()))
        .toList();
    return _StockDetailData(
      intraday: intraday,
      historical: historical,
      relatedNews: relatedNews.isEmpty ? await _apiService.fetchMarketNews() : relatedNews,
    );
  }

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
            Text(_stock.name, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey)),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () {
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải dữ liệu: ${snapshot.error}'));
          }
          final _StockDetailData data = snapshot.data!;
          final bool positive = _stock.changePercent >= 0;
          final List<StockPricePoint> chartPoints =
              _selectedRange == _ChartRange.oneDay ? data.intraday : data.historical;
          final double dayHigh = data.intraday.isEmpty
              ? _stock.price
              : data.intraday.map((StockPricePoint p) => p.price).reduce((double a, double b) => a > b ? a : b);
          final double dayLow = data.intraday.isEmpty
              ? _stock.price
              : data.intraday.map((StockPricePoint p) => p.price).reduce((double a, double b) => a < b ? a : b);
          final double rangeHigh = chartPoints.isEmpty
              ? _stock.price
              : chartPoints.map((StockPricePoint p) => p.price).reduce((double a, double b) => a > b ? a : b);
          final double rangeLow = chartPoints.isEmpty
              ? _stock.price
              : chartPoints.map((StockPricePoint p) => p.price).reduce((double a, double b) => a < b ? a : b);

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _detailFuture = _loadStockDetail();
              });
              await _detailFuture;
            },
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: <Widget>[
                _buildOverviewCard(context, positive),
                const SizedBox(height: 20),
                _buildSegmentControl(context),
                const SizedBox(height: 16),
                StockLineChart(points: chartPoints, positive: positive),
                const SizedBox(height: 16),
                _buildStatsCard(context, dayHigh, dayLow, rangeHigh, rangeLow),
                const SizedBox(height: 24),
                const SectionHeader(title: 'Tin tức liên quan'),
                if (data.relatedNews.isEmpty)
                  const ListTile(title: Text('Chưa có tin tức liên quan.'))
                else
                  ...data.relatedNews.map(
                    (MarketNews news) => Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: Text(news.title),
                        subtitle: Text('${news.source} • ${news.timeAgo}'),
                        onTap: () {
                          // TODO(thanhvien3): Mở chi tiết bài viết.
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

  Widget _buildOverviewCard(BuildContext context, bool positive) {
    final ThemeData theme = Theme.of(context);
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
          BoxShadow(color: endColor.withOpacity(.3), offset: const Offset(0, 14), blurRadius: 22),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(_stock.symbol, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
          const SizedBox(height: 8),
          Text(
            '${_stock.price.toStringAsFixed(0)} đ',
            style: theme.textTheme.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Icon(positive ? Icons.trending_up : Icons.trending_down, color: Colors.white),
              const SizedBox(width: 4),
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

  Widget _buildSegmentControl(BuildContext context) {
    return CupertinoSlidingSegmentedControl<_ChartRange>(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.4),
      thumbColor: Theme.of(context).colorScheme.primary,
      groupValue: _selectedRange,
      children: const <_ChartRange, Widget>{
        _ChartRange.oneDay: Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16), child: Text('1D')),
        _ChartRange.tenDays: Padding(padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16), child: Text('10D')),
      },
      onValueChanged: (_ChartRange? value) {
        if (value != null) {
          setState(() {
            _selectedRange = value;
          });
        }
      },
    );
  }

  Widget _buildStatsCard(
    BuildContext context,
    double dayHigh,
    double dayLow,
    double rangeHigh,
    double rangeLow,
  ) {
    final ThemeData theme = Theme.of(context);
    final String rangeLabel = _selectedRange == _ChartRange.oneDay ? 'Biểu đồ 1D' : 'Biểu đồ 10D';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Số liệu nhanh', style: theme.textTheme.titleMedium),
            const SizedBox(height: 16),
            Wrap(
              spacing: 20,
              runSpacing: 16,
              children: <Widget>[
                _StatTile(title: 'Cao (1D)', value: '${dayHigh.toStringAsFixed(0)} đ'),
                _StatTile(title: 'Thấp (1D)', value: '${dayLow.toStringAsFixed(0)} đ'),
                _StatTile(title: 'Cao ($rangeLabel)', value: '${rangeHigh.toStringAsFixed(0)} đ'),
                _StatTile(title: 'Thấp ($rangeLabel)', value: '${rangeLow.toStringAsFixed(0)} đ'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChartRange { oneDay, tenDays }

class _StatTile extends StatelessWidget {
  const _StatTile({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 148,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor)),
          const SizedBox(height: 4),
          Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StockDetailData {
  const _StockDetailData({
    required this.intraday,
    required this.historical,
    required this.relatedNews,
  });

  final List<StockPricePoint> intraday;
  final List<StockPricePoint> historical;
  final List<MarketNews> relatedNews;
}
