import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart'; // Mở URL trong browser ngoài

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

// =============================================================================
// HomeScreen — Màn hình Trang Chủ (Dashboard)
// =============================================================================
//
// Đây là màn hình phức tạp nhất, kết hợp 2 luồng dữ liệu:
//
// 1. SYNC (ChangeNotifier): WatchlistProvider — danh sách mã theo dõi
//    Lắng nghe bằng addListener → khi watchlist thay đổi → reload data
//
// 2. ASYNC (FutureBuilder): _homeDataFuture — dữ liệu thị trường từ API
//    Gọi 3 API song song (indices + watchlist prices + news)
//
// CÁCH UI BUILD:
//   Scaffold
//   └─ FutureBuilder<_HomeScreenData>
//       └─ RefreshIndicator (pull-to-refresh)
//           └─ CustomScrollView (Sliver-based scroll)
//               ├─ SliverAppBar (cuộn ẩn/hiện)
//               ├─ Chỉ số thị trường (ngang scroll)
//               ├─ Header "Watchlist"
//               ├─ Danh sách Watchlist (dọc)
//               ├─ Header "Tin tức"
//               └─ Danh sách tin tức
// =============================================================================

/// Màn hình Trang Chủ — Hiển thị tổng quan thị trường và danh mục theo dõi.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final YahooFinanceService _apiService = YahooFinanceService.instance;

  // Future chứa tất cả data cần thiết cho HomeScreen
  // late: sẽ gán giá trị ngay trong initState (trước khi dùng)
  late Future<_HomeScreenData> _homeDataFuture;

  // Tham chiếu đến WatchlistProvider để add/remove listener
  late WatchlistProvider _watchlistProvider;

  // Cờ ngăn setup provider nhiều lần (didChangeDependencies gọi nhiều lần)
  bool _didSetupProvider = false;

  @override
  void initState() {
    super.initState();
    // Khởi tạo với dữ liệu rỗng (placeholder) để FutureBuilder không bị null
    // Future.value() = tạo Future đã completed với giá trị sẵn
    _homeDataFuture = Future<_HomeScreenData>.value(
      const _HomeScreenData(
        indices: <MarketIndex>[],
        watchlist: <Stock>[],
        news: <MarketNews>[],
        trackedSymbols: <StockSymbolModel>[],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // didChangeDependencies — Lắng nghe WatchlistProvider
  // ---------------------------------------------------------------------------

  /// Gọi mỗi khi InheritedWidget (Provider) trên widget tree thay đổi.
  ///
  /// Khác với initState (chỉ gọi 1 lần):
  /// - didChangeDependencies gọi sau initState LẦN ĐẦU
  /// - Gọi lại khi Provider instance thay đổi (hot reload, provider re-created)
  ///
  /// Dùng _didSetupProvider để chỉ setup listener 1 lần, tránh leak listener.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Lấy WatchlistProvider hiện tại từ context
    final WatchlistProvider provider = Provider.of<WatchlistProvider>(context);

    if (!_didSetupProvider) {
      // Lần đầu: setup listener và load data
      _watchlistProvider = provider;
      if (!provider.isLoading) {
        // Chỉ load data khi provider đã xong khởi tạo (isLoading = false)
        _homeDataFuture = _loadData(provider.trackedSymbols);
      }
      provider.addListener(_onWatchlistChanged); // Đăng ký lắng nghe thay đổi
      _didSetupProvider = true;
    } else if (!identical(_watchlistProvider, provider)) {
      // Provider instance bị thay (thường khi hot reload):
      // Xóa listener cũ, đăng ký listener mới
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
    // QUAN TRỌNG: Phải xóa listener khi widget bị destroy
    // Không làm → memory leak (provider giữ reference đến widget đã chết)
    if (_didSetupProvider) {
      _watchlistProvider.removeListener(_onWatchlistChanged);
    }
    super.dispose();
  }

  /// Callback khi WatchlistProvider thay đổi (add/remove/reorder mã).
  void _onWatchlistChanged() {
    if (!mounted) return; // Widget đã bị dispose → bỏ qua

    if (_watchlistProvider.isLoading) {
      setState(() {}); // Chỉ trigger rebuild để show/hide loading indicator
      return;
    }

    // Xóa cache sparkline để biểu đồ miniature cập nhật theo watchlist mới
    MiniSparkline.invalidateCache();

    setState(() {
      // Gán Future mới → FutureBuilder sẽ rebuild với data mới
      _homeDataFuture = _loadData(_watchlistProvider.trackedSymbols);
    });
  }

  // ---------------------------------------------------------------------------
  // _loadData() — Tải toàn bộ dữ liệu màn hình
  // ---------------------------------------------------------------------------

  /// Tải dữ liệu từ 3 nguồn API riêng biệt và gộp vào [_HomeScreenData].
  ///
  /// Chạy SONG SONG (Future.wait) để giảm thời gian tải tổng thể.
  /// Mỗi nguồn có try/catch riêng: nếu 1 API lỗi thì 2 cái kia
  /// vẫn hiển thị bình thường (graceful degradation).
  Future<_HomeScreenData> _loadData(List<StockSymbolModel> trackedSymbols) async {
    // Chạy 3 API song song — thời gian tải = max(3 API) thay vì tổng(3 API)
    final List<Object?> results = await Future.wait(<Future<Object?>>[
      _apiService.fetchMarketIndices().catchError((Object e) {
        debugPrint('Failed to load indices: $e');
        return <MarketIndex>[];
      }),
      trackedSymbols.isNotEmpty
          ? _apiService.fetchWatchlist(symbolModels: trackedSymbols).catchError((Object e) {
              debugPrint('Failed to load watchlist: $e');
              return <Stock>[];
            })
          : Future<List<Stock>>.value(<Stock>[]),
      _apiService.fetchMarketNews().catchError((Object e) {
        debugPrint('Failed to load news: $e');
        return <MarketNews>[];
      }),
    ]);

    return _HomeScreenData(
      indices: results[0] as List<MarketIndex>? ?? <MarketIndex>[],
      watchlist: results[1] as List<Stock>? ?? <Stock>[],
      news: results[2] as List<MarketNews>? ?? <MarketNews>[],
      trackedSymbols: trackedSymbols,
    );
  }

  // ---------------------------------------------------------------------------
  // build() — Xây dựng toàn bộ UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: FutureBuilder<_HomeScreenData>(
        future: _homeDataFuture,
        builder: (BuildContext context, AsyncSnapshot<_HomeScreenData> snapshot) {
          // Case 1: Provider chưa sẵn sàng hoặc đang loading
          if (!_didSetupProvider || (_didSetupProvider && _watchlistProvider.isLoading)) {
            return const Center(child: CircularProgressIndicator());
          }
          // Case 2: API đang fetch
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Case 3: Lỗi nghiêm trọng
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Không thể tải dữ liệu: ${snapshot.error}'),
              ),
            );
          }
          // Case 4: Thành công → Render UI
          final _HomeScreenData data = snapshot.data!; // `!` vì ta đã check hasError
          return RefreshIndicator(
            onRefresh: () async {
              MiniSparkline.invalidateCache(); // Xóa cache biểu đồ miniature
              _apiService.invalidateQuoteCache(); // Xóa cache giá → force fetch mới
              setState(() {
                _homeDataFuture = _loadData(_watchlistProvider.trackedSymbols);
              });
              await _homeDataFuture; // Chờ load xong rồi mới dismiss indicator
            },
            // CustomScrollView + Slivers: tối ưu hiệu năng scroll cho list dài
            // BouncingScrollPhysics: hiệu ứng bounce khi scroll hết trang (iOS style)
            // AlwaysScrollableScrollPhysics: cho phép pull-to-refresh dù nội dung ngắn
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              slivers: <Widget>[
                _buildAppBar(context),
                _buildIndicesSliver(context, data.indices),
                _buildWatchlistHeader(context),
                _buildWatchlistSliver(context, data),
                _buildNewsHeader(context),
                _buildNewsSliver(context, data.news),
                const SliverPadding(padding: EdgeInsets.only(bottom: 32)), // Safe area bottom
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Builder methods — Mỗi hàm build 1 phần UI
  // ---------------------------------------------------------------------------

  /// AppBar cuộn theo với tiêu đề + 2 action button (edit watchlist, search).
  ///
  /// [pinned: true]: AppBar dính trên cùng khi scroll → không bị cuộn mất
  /// [floating: true]: AppBar xuất hiện ngay khi bắt đầu scroll lên
  /// [snap: true]: AppBar trượt vào/ra hoàn toàn (không dừng giữa chừng)
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

  /// Danh sách chỉ số thị trường cuộn NGANG (VN-Index, HNX...).
  ///
  /// SliverToBoxAdapter: bọc widget thông thường để dùng được trong CustomScrollView.
  /// ListView.horizontal bên trong = scroll ngang độc lập với scroll dọc bên ngoài.
  SliverToBoxAdapter _buildIndicesSliver(BuildContext context, List<MarketIndex> indices) {
    final ThemeData theme = Theme.of(context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: SizedBox(
          height: 160, // Chiều cao cố định cho horizontal list
          child: ListView.separated(
            scrollDirection: Axis.horizontal, // Scroll ngang
            itemCount: indices.length,
            separatorBuilder: (_, _) => const SizedBox(width: 16), // Khoảng cách giữa card
            itemBuilder: (BuildContext context, int index) {
              final MarketIndex marketIndex = indices[index];
              final bool positive = marketIndex.isPositive;
              // Màu xanh nếu tăng, đỏ nếu giảm
              final Color changeColor = positive ? Colors.greenAccent : Colors.redAccent;
              return Container(
                width: 220,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  // Gradient xanh hoặc đỏ tùy theo chiều thị trường
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
                    // Tên chỉ số
                    Text(marketIndex.name,
                        style: theme.textTheme.titleMedium?.copyWith(color: Colors.white70)),
                    // Giá trị điểm số
                    Text(
                      marketIndex.value.toStringAsFixed(2),
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    // Icon trend + % thay đổi
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

  /// Header "Watchlist" với nút "Xem tất cả" → navigate sang StockListScreen.
  SliverToBoxAdapter _buildWatchlistHeader(BuildContext context) {
    return SliverToBoxAdapter(
      child: SectionHeader(
        title: 'Watchlist',
        onSeeAll: () => Navigator.of(context).pushNamed(StockListScreen.routeName),
      ),
    );
  }

  /// Danh sách card watchlist (hiển thị tối đa 8 mã).
  ///
  /// Logic đảm bảo THỨ TỰ HIỂN THỊ đúng theo thứ tự người dùng cài:
  /// 1. Tạo Map<symbol, Stock> để lookup O(1)
  /// 2. Duyệt qua trackedSymbols (theo thứ tự người dùng)
  /// 3. Lookup Stock tương ứng → giữ nguyên thứ tự
  ///
  /// Vấn đề nếu không làm vậy: API trả về thứ tự ngẫu nhiên → UI nhảy loạn.
  Widget _buildWatchlistSliver(BuildContext context, _HomeScreenData data) {
    // Tạo Map để tra nhanh: "FPT" → Stock object
    final Map<String, Stock> stockMap = <String, Stock>{
      for (final Stock stock in data.watchlist) stock.symbol.toUpperCase(): stock,
    };

    // Sắp xếp theo thứ tự trackedSymbols (thứ tự người dùng đặt)
    final List<Stock> ordered = <Stock>[];
    for (final StockSymbolModel symbol in data.trackedSymbols) {
      final Stock? stock = stockMap[symbol.displaySymbol.toUpperCase()];
      if (stock != null) {
        ordered.add(stock);
      }
    }

    final List<Stock> watchlist = ordered.take(8).toList(); // Tối đa 8 mã

    if (watchlist.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Đang cập nhật dữ liệu watchlist...'),
        ),
      );
    }

    // Tạo list widget card + SizedBox khoảng cách
    final List<Widget> children = <Widget>[];
    for (int i = 0; i < watchlist.length; i++) {
      final Stock stock = watchlist[i];
      children.add(
        _WatchlistCard(
          stock: stock,
          onTap: () => Navigator.of(context).pushNamed(
            StockDetailScreen.routeName,
            arguments: StockDetailArgs(stock: stock), // Truyền dữ liệu qua arguments
          ),
        ),
      );
      if (i < watchlist.length - 1) {
        children.add(const SizedBox(height: 12)); // Khoảng cách giữa card
      }
    }

    // SliverPadding + SliverList: cách đúng để render List trong CustomScrollView
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverList(
        delegate: SliverChildListDelegate(children), // Fixed list (không lazy load)
      ),
    );
  }

  /// Header "Tin tức mới nhất" (không có nút Xem tất cả).
  SliverToBoxAdapter _buildNewsHeader(BuildContext context) {
    return const SliverToBoxAdapter(
      child: SectionHeader(title: 'Tin tức mới nhất'),
    );
  }

  /// Danh sách card tin tức.
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
            subtitle: Text('${item.source} • ${item.timeAgo}'), // timeAgo từ getter
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _openNewsUrl(item.url), // Mở URL trong browser ngoài
          ),
        ),
      );
      if (i < news.length - 1) {
        tiles.add(const SizedBox(height: 8));
      }
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      sliver: SliverList(delegate: SliverChildListDelegate(tiles)),
    );
  }

  /// Mở URL tin tức trong trình duyệt ngoài.
  ///
  /// canLaunchUrl: kiểm tra thiết bị có app nào handle URL không
  /// launchUrl + LaunchMode.externalApplication: mở trong browser ngoài (không WebView)
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
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Không thể mở link')));
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $error')));
      }
    }
  }
}

// =============================================================================
// _WatchlistCard — Widget Card hiển thị 1 mã cổ phiếu trong Watchlist
// =============================================================================

/// Card watchlist: hiển thị symbol, tên, giá + biểu đồ sparkline + % thay đổi.
///
/// Private class (prefix `_`): chỉ dùng nội bộ trong file này.
/// StatelessWidget vì không có state riêng (nhận data từ parent qua constructor).
class _WatchlistCard extends StatelessWidget {
  const _WatchlistCard({required this.stock, required this.onTap});

  final Stock stock;
  final VoidCallback onTap; // VoidCallback = void Function() — không tham số không trả về

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isPositive = stock.changePercent >= 0;
    final Color changeColor = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFE53935);

    // InkWell: hiệu ứng ripple khi nhấn (Material Design)
    // Ink: layer để InkWell ripple đúng trên nền container có decoration
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20), // Phải khớp với Ink để ripple đúng形
      child: Ink(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // surfaceContainerHighest: màu surface nổi nhẹ (Material 3)
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(.4),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(.3)),
        ),
        child: Row(
          children: <Widget>[
            // Cột trái: symbol, tên, giá
            Expanded( // Expanded: chiếm hết không gian còn lại trong Row
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
                    overflow: TextOverflow.ellipsis, // "..." khi tên quá dài
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${stock.price.toStringAsFixed(0)} đ', // Làm tròn: 125000.5 → "125001 đ"
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Cột phải: sparkline + % thay đổi
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                SizedBox(
                  height: 52,
                  width: 110,
                  // MiniSparkline: widget tự fetch intraday data và vẽ biểu đồ mini
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
                      style: theme.textTheme.titleMedium
                          ?.copyWith(color: changeColor, fontWeight: FontWeight.bold),
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

// =============================================================================
// _HomeScreenData — Container gom dữ liệu màn hình (Internal DTO)
// =============================================================================

/// Data Transfer Object (DTO) nội bộ: gom tất cả dữ liệu HomeScreen cần.
///
/// Dùng class riêng (thay vì Map hay tuple) để:
/// - Type-safe: compiler kiểm tra kiểu dữ liệu
/// - Tự document: tên field rõ ràng hơn Map<String, dynamic>
/// - const constructor: immutable sau khi tạo
class _HomeScreenData {
  const _HomeScreenData({
    required this.indices,
    required this.watchlist,
    required this.news,
    required this.trackedSymbols,
  });

  final List<MarketIndex> indices;           // Chỉ số thị trường (VN-Index, HNX...)
  final List<Stock> watchlist;               // Giá thực của các mã watchlist
  final List<MarketNews> news;               // Tin tức thị trường
  final List<StockSymbolModel> trackedSymbols; // Thứ tự user đặt (để sắp xếp watchlist)
}
