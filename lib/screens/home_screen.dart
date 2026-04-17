import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/market_index.dart';
import '../models/market_news.dart';
import '../models/stock.dart';
import '../models/stock_symbol_model.dart';
import '../services/yahoo_finance_service.dart';
import '../state/watchlist_provider.dart';
import '../widgets/mini_sparkline.dart';
import '../widgets/section_header.dart';
import 'stock_detail_screen.dart';
import 'stock_list_screen.dart';
import 'watchlist_manage_screen.dart';

/// Màn hình Trang Chủ (Dashboard) - Màn hình đầu tiên xuất hiện khi chạy ứng dụng.
/// Chịu trách nhiệm hiển thị Tổng quan thị trường (Chỉ số), Danh sách theo dõi (Watchlist) 
/// và các Tin tức tài chính mới nhất. Lấy liên kết trực tiếp với Service và WatchlistProvider.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final YahooFinanceService _apiService = YahooFinanceService.instance;
  late Future<_HomeScreenData> _homeDataFuture;
  late WatchlistProvider _watchlistProvider;
  bool _didSetupProvider = false;

  @override
  void initState() {
    super.initState();
    _homeDataFuture = Future<_HomeScreenData>.value(
      const _HomeScreenData(
        indices: <MarketIndex>[],
        watchlist: <Stock>[],
        news: <MarketNews>[],
        trackedSymbols: <StockSymbolModel>[],
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final WatchlistProvider provider = Provider.of<WatchlistProvider>(context);
    if (!_didSetupProvider) {
      _watchlistProvider = provider;
      if (!provider.isLoading) {
        _homeDataFuture = _loadData(provider.trackedSymbols);
      }
      provider.addListener(_onWatchlistChanged);
      _didSetupProvider = true;
    } else if (!identical(_watchlistProvider, provider)) {
      _watchlistProvider.removeListener(_onWatchlistChanged);
      _watchlistProvider = provider;
      _watchlistProvider.addListener(_onWatchlistChanged);
      if (!_watchlistProvider.isLoading) {
        _homeDataFuture = _loadData(_watchlistProvider.trackedSymbols);
      }
    }
  }

  @override
  void dispose() {
    if (_didSetupProvider) {
      _watchlistProvider.removeListener(_onWatchlistChanged);
    }
    super.dispose();
  }

  void _onWatchlistChanged() {
    if (!mounted) return;
    if (_watchlistProvider.isLoading) {
      setState(() {});
      return;
    }
    MiniSparkline.invalidateCache();
    setState(() {
      _homeDataFuture = _loadData(_watchlistProvider.trackedSymbols);
    });
  }

  Future<_HomeScreenData> _loadData(List<StockSymbolModel> trackedSymbols) async {
    // Fetch each section independently so one failure doesn't block the rest
    List<MarketIndex> indices = <MarketIndex>[];
    List<Stock> watchlist = <Stock>[];
    List<MarketNews> news = <MarketNews>[];

    try {
      indices = await _apiService.fetchMarketIndices();
    } catch (e) {
      debugPrint('Failed to load indices: $e');
    }

    try {
      if (trackedSymbols.isNotEmpty) {
        watchlist = await _apiService.fetchWatchlist(symbolModels: trackedSymbols);
      }
    } catch (e) {
      debugPrint('Failed to load watchlist: $e');
    }

    try {
      news = await _apiService.fetchMarketNews();
    } catch (e) {
      debugPrint('Failed to load news: $e');
    }

    return _HomeScreenData(
      indices: indices,
      watchlist: watchlist,
      news: news,
      trackedSymbols: trackedSymbols,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: FutureBuilder<_HomeScreenData>(
        future: _homeDataFuture,
        builder: (BuildContext context, AsyncSnapshot<_HomeScreenData> snapshot) {
          if (!_didSetupProvider || (_didSetupProvider && _watchlistProvider.isLoading)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Không thể tải dữ liệu: ${snapshot.error}'),
              ),
            );
          }
          final _HomeScreenData data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async {
              MiniSparkline.invalidateCache();
              setState(() {
                _homeDataFuture = _loadData(_watchlistProvider.trackedSymbols);
              });
              await _homeDataFuture;
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: <Widget>[
                _buildAppBar(context),
                _buildIndicesSliver(context, data.indices),
                _buildWatchlistHeader(context),
                _buildWatchlistSliver(context, data),
                _buildNewsHeader(context),
                _buildNewsSliver(context, data.news),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
              ],
            ),
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SliverAppBar(
      pinned: true,
      floating: true,
      snap: true,
      elevation: 0,
      toolbarHeight: 72,
      backgroundColor: theme.colorScheme.surface,
      titleSpacing: 24,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: const <Widget>[
          Text('Danh mục của tôi', style: TextStyle(fontSize: 14, color: Colors.grey)),
          SizedBox(height: 4),
          Text('Thị trường hôm nay', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
        ],
      ),
      actions: <Widget>[
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Quản lý watchlist',
          onPressed: () => Navigator.of(context).pushNamed(WatchlistManageScreen.routeName),
        ),
        IconButton(
          icon: const Icon(Icons.search),
          tooltip: 'Tìm kiếm & thêm mã',
          onPressed: () => Navigator.of(context).pushNamed(StockListScreen.routeName),
        ),
        const SizedBox(width: 12),
      ],
    );
  }

  SliverToBoxAdapter _buildIndicesSliver(BuildContext context, List<MarketIndex> indices) {
    final ThemeData theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: indices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            itemBuilder: (BuildContext context, int index) {
              final MarketIndex marketIndex = indices[index];
              final bool positive = marketIndex.isPositive;
              final Color changeColor = positive ? Colors.greenAccent : Colors.redAccent;
              return Container(
                width: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: positive
                        ? <Color>[const Color(0xFF0F9B0F), const Color(0xFF5AC994)]
                        : <Color>[const Color(0xFFB31217), const Color(0xFFE52D27)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: changeColor.withOpacity(.25),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(marketIndex.name, style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
                    Text(
                      marketIndex.value.toStringAsFixed(2),
                      style: theme.textTheme.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Row(
                      children: <Widget>[
                        Icon(
                          positive ? Icons.trending_up : Icons.trending_down,
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${marketIndex.changePercent.toStringAsFixed(2)}%',
                          style: theme.textTheme.labelLarge?.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  SliverToBoxAdapter _buildWatchlistHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: SectionHeader(
        title: 'Watchlist',
        onSeeAll: () => Navigator.of(context).pushNamed(StockListScreen.routeName),
      ),
    );
  }

  Widget _buildWatchlistSliver(BuildContext context, _HomeScreenData data) {
    final Map<String, Stock> stockMap = <String, Stock>{
      for (final Stock stock in data.watchlist) stock.symbol.toUpperCase(): stock,
    };
    final List<Stock> ordered = <Stock>[];
    for (final StockSymbolModel symbol in data.trackedSymbols) {
      final Stock? stock = stockMap[symbol.displaySymbol.toUpperCase()];
      if (stock != null) {
        ordered.add(stock);
      }
    }
    final List<Stock> watchlist = ordered.take(8).toList();
    if (watchlist.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Đang cập nhật dữ liệu watchlist...'),
        ),
      );
    }
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < watchlist.length; i++) {
      final Stock stock = watchlist[i];
      children.add(
        _WatchlistCard(
          stock: stock,
          onTap: () => Navigator.of(context).pushNamed(
            StockDetailScreen.routeName,
            arguments: StockDetailArgs(stock: stock),
          ),
        ),
      );
      if (i < watchlist.length - 1) {
        children.add(const SizedBox(height: 12));
      }
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate(children),
      ),
    );
  }

  SliverToBoxAdapter _buildNewsHeader(BuildContext context) {
    return const SliverToBoxAdapter(
      child: SectionHeader(title: 'Tin tức mới nhất'),
    );
  }

  Widget _buildNewsSliver(BuildContext context, List<MarketNews> news) {
    if (news.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Chưa có tin tức mới.'),
        ),
      );
    }
    final List<Widget> tiles = <Widget>[];
    for (int i = 0; i < news.length; i++) {
      final MarketNews item = news[i];
      tiles.add(
        Card(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            title: Text(item.title),
            subtitle: Text('${item.source} • ${item.timeAgo}'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _openNewsUrl(item.url),
          ),
        ),
      );
      if (i < news.length - 1) {
        tiles.add(const SizedBox(height: 8));
      }
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(
        delegate: SliverChildListDelegate(tiles),
      ),
    );
  }

  Future<void> _openNewsUrl(String? url) async {
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có link tin tức')),
        );
      }
      return;
    }

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể mở link')),
          );
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $error')),
        );
      }
    }
  }
}

class _WatchlistCard extends StatelessWidget {
  const _WatchlistCard({required this.stock, required this.onTap});

  final Stock stock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isPositive = stock.changePercent >= 0;
    final Color changeColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(.4),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.3)),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    stock.symbol,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stock.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${stock.price.toStringAsFixed(0)} đ',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                SizedBox(
                  height: 52,
                  width: 110,
                  child: MiniSparkline(
                    symbol: stock.symbol,
                    apiSymbol: stock.apiSymbol,
                    lineColor: isPositive ? const Color(0xFF81C784) : const Color(0xFFEF9A9A),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    Icon(
                      isPositive ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                      color: changeColor,
                      size: 28,
                    ),
                    Text(
                      '${stock.changePercent.toStringAsFixed(2)}%',
                      style: theme.textTheme.titleMedium?.copyWith(color: changeColor, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeScreenData {
  const _HomeScreenData({
    required this.indices,
    required this.watchlist,
    required this.news,
    required this.trackedSymbols,
  });

  final List<MarketIndex> indices;
  final List<Stock> watchlist;
  final List<MarketNews> news;
  final List<StockSymbolModel> trackedSymbols;
}
