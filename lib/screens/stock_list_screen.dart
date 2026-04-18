import 'package:flutter/material.dart';

import '../models/stock.dart';
import '../services/yahoo_finance_service.dart';
import 'stock_detail_screen.dart';

// =============================================================================
// StockListScreen — Màn hình Danh sách & Tìm kiếm Cổ phiếu
// =============================================================================
//
// Tính năng:
//   - Hiển thị danh sách mặc định (fetchWatchlist() = 30 mã hardcoded)
//   - Tìm kiếm real-time theo mã hoặc tên công ty (client-side filter)
//   - Bấm vào mã → navigate StockDetailScreen
//
// LUỒNG DỮ LIỆU:
//   initState → _loadStocks() → fetchWatchlist() → setState(_stocks)
//   TextEditingController → listener → setState → _filteredStocks getter tính lại
//   → ListView rebuild với danh sách đã lọc
//
// LƯU Ý: Tìm kiếm hiện tại là CLIENT-SIDE (lọc từ danh sách 30 mã đã load).
//   Nếu cần tìm kiếm toàn bộ sàn → gọi searchSymbols() từ Yahoo Search API.
// =============================================================================

/// Màn hình hiển thị + tìm kiếm danh sách mã cổ phiếu.
class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  /// Named route để navigate tới màn hình này
  static const String routeName = '/stocks';

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final YahooFinanceService _apiService = YahooFinanceService.instance;

  /// Controller quản lý TextField tìm kiếm.
  /// Phải dispose() khi widget bị destroy để giải phóng bộ nhớ.
  final TextEditingController _searchController = TextEditingController();

  /// Future loading lần đầu — giữ nguyên sau đó để FutureBuilder không reload.
  late Future<void> _loadFuture;

  /// Danh sách đầy đủ (không lọc) từ API
  List<Stock> _stocks = <Stock>[];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadStocks();

    /// Lắng nghe thay đổi nội dung TextField → setState → _filteredStocks rebuild.
    /// addListener nhận VoidCallback — gọi mỗi khi text thay đổi.
    _searchController.addListener(() => setState(() {}));
  }

  /// Tải danh sách mã mặc định từ API (fetchWatchlist = 30 mã hardcoded).
  ///
  /// Dùng !mounted check để tránh gọi setState sau khi widget bị dispose.
  Future<void> _loadStocks() async {
    final List<Stock> stocks = await _apiService.fetchWatchlist();
    if (!mounted) return;
    setState(() {
      _stocks = stocks;
    });
  }

  @override
  void dispose() {
    /// QUAN TRỌNG: Dispose TextEditingController để giải phóng resources.
    /// Nếu không → memory leak vì Controller giữ listener reference.
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Computed Getter — Lọc danh sách theo từ khóa tìm kiếm
  // ---------------------------------------------------------------------------

  /// Trả về danh sách đã lọc theo nội dung TextField.
  ///
  /// Được gọi mỗi lần build() chạy (khi setState từ listener TextField).
  /// Lọc cả mã cổ phiếu (symbol) và tên công ty (name), không phân biệt hoa/thường.
  List<Stock> get _filteredStocks {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _stocks; // Không filter → trả về toàn bộ
    }
    /// String.contains() = tìm substring (không cần exact match)
    /// toLowerCase() đảm bảo không phân biệt hoa thường
    return _stocks
        .where(
          (Stock stock) =>
              stock.symbol.toLowerCase().contains(query) ||
              stock.name.toLowerCase().contains(query),
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Build UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách mã cổ phiếu')),
      body: FutureBuilder<void>(
        future: _loadFuture, // Chỉ theo dõi lần load đầu
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải dữ liệu: ${snapshot.error}'));
          }

          final List<Stock> stocks = _filteredStocks; // Lấy list đã lọc

          return Column(
            children: <Widget>[
              // ── Thanh tìm kiếm ──────────────────────────
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo mã hoặc tên doanh nghiệp',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

              // ── Danh sách mã ────────────────────────────
              Expanded(
                // Expanded: chiếm phần còn lại của Column sau thanh tìm kiếm
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadStocks(); // Pull-to-refresh: load lại từ API
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(), // Cho phép pull dù list ngắn
                    itemBuilder: (BuildContext context, int index) {
                      final Stock stock = stocks[index];
                      final bool isPositive = stock.changePercent >= 0;
                      final Color changeColor = isPositive ? Colors.green : Colors.red;

                      return ListTile(
                        title: Row(
                          children: <Widget>[
                            // Mã cổ phiếu in đậm
                            Text(stock.symbol,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            // Tên công ty co rút nếu quá dài
                            Expanded(
                                child: Text(stock.name,
                                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
                        // Khối lượng: ternary để handle volume = 0
                        subtitle: Text('KL: ${stock.volume > 0 ? stock.volume : '-'}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Text('${stock.price.toStringAsFixed(0)} đ'),
                            Text(
                              '${stock.changePercent.toStringAsFixed(2)}%',
                              style: TextStyle(color: changeColor),
                            ),
                          ],
                        ),
                        // Navigate sang màn hình chi tiết với arguments
                        onTap: () => Navigator.of(context).pushNamed(
                          StockDetailScreen.routeName,
                          arguments: StockDetailArgs(stock: stock),
                        ),
                      );
                    },
                    // separatorBuilder: widget giữa các item (đường kẻ mỏng)
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemCount: stocks.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
