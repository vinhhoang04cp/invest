import 'package:flutter/material.dart';

import '../models/stock.dart';
import '../services/yahoo_finance_service.dart';
import 'stock_detail_screen.dart';

/// Màn hình Thị trường (Danh sách tất cả mã cổ phiếu).
/// Cung cấp thanh tìm kiếm (Search bar) để tra cứu mã hoặc tên công ty theo thời gian thực.
class StockListScreen extends StatefulWidget {
  const StockListScreen({super.key});

  static const String routeName = '/stocks';

  @override
  State<StockListScreen> createState() => _StockListScreenState();
}

class _StockListScreenState extends State<StockListScreen> {
  final YahooFinanceService _apiService = YahooFinanceService.instance;
  final TextEditingController _searchController = TextEditingController();
  late Future<void> _loadFuture;
  List<Stock> _stocks = <Stock>[];

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadStocks();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _loadStocks() async {
    final List<Stock> stocks = await _apiService.fetchWatchlist();
    if (!mounted) return;
    setState(() {
      _stocks = stocks;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Stock> get _filteredStocks {
    final String query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return _stocks;
    }
    return _stocks
        .where(
          (Stock stock) => stock.symbol.toLowerCase().contains(query) ||
              stock.name.toLowerCase().contains(query),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Danh sách mã cổ phiếu')),
      body: FutureBuilder<void>(
        future: _loadFuture,
        builder: (BuildContext context, AsyncSnapshot<void> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Không thể tải dữ liệu: ${snapshot.error}'));
          }
          final List<Stock> stocks = _filteredStocks;
          return Column(
            children: <Widget>[
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
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    await _loadStocks();
                  },
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemBuilder: (BuildContext context, int index) {
                      final Stock stock = stocks[index];
                      final bool isPositive = stock.changePercent >= 0;
                      final Color changeColor = isPositive ? Colors.green : Colors.red;
                      return ListTile(
                        title: Row(
                          children: <Widget>[
                            Text(stock.symbol, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(stock.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                          ],
                        ),
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
                        onTap: () => Navigator.of(context).pushNamed(
                          StockDetailScreen.routeName,
                          arguments: StockDetailArgs(stock: stock),
                        ),
                      );
                    },
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
