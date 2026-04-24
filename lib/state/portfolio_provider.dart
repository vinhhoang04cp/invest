import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/portfolio.dart';
import '../models/stock.dart';
import '../services/yahoo_finance_service.dart';

/// Provider quản lý danh mục đầu tư cá nhân.
class PortfolioProvider extends ChangeNotifier {
  PortfolioProvider({String? uid}) : _uid = uid {
    _initialize();
  }

  final String? _uid;

  /// UID của người dùng hiện tại (public getter để ProxyProvider so sánh).
  String? get uid => _uid;

  final List<PortfolioItem> _items = [];
  final Map<String, Stock> _priceCache = {};
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  List<PortfolioItem> get items => List.unmodifiable(_items);

  /// Trả về PortfolioSummary bao gồm cả giá thị trường hiện tại.
  PortfolioSummary get summary {
    final entries = _items.map((item) {
      final stock = _priceCache[item.symbol] ??
          Stock(
            symbol: item.symbol,
            name: item.symbol,
            price: item.averagePrice, // Fallback nếu chưa có giá market
            changePercent: 0,
            volume: 0,
            apiSymbol: '${item.symbol}.VN',
          );
      return PortfolioEntry(
        stock: stock,
        quantity: item.quantity,
        averagePrice: item.averagePrice,
      );
    }).toList();

    return PortfolioSummary(entries: entries);
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_uid != null) {
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(_uid)
            .collection('portfolio')
            .get();

        _items.clear();
        for (var doc in snapshot.docs) {
          _items.add(PortfolioItem.fromMap(doc.data()));
        }
      }

      // Nếu không có dữ liệu thật, tạo data mẫu (chỉ cho lần đầu hoặc guest)
      if (_items.isEmpty) {
        _items.addAll([
          const PortfolioItem(symbol: 'FPT', quantity: 100, averagePrice: 90000),
          const PortfolioItem(symbol: 'VNM', quantity: 50, averagePrice: 70000),
        ]);
      }

      await refreshPrices();
    } catch (e) {
      debugPrint('PortfolioProvider Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cập nhật giá thị trường cho tất cả mã trong danh mục.
  Future<void> refreshPrices() async {
    if (_items.isEmpty) return;

    try {
      final symbols = _items.map((e) => e.symbol).toList();
      final stocks = await YahooFinanceService.instance.fetchQuotes(symbols);
      
      for (var stock in stocks) {
        _priceCache[stock.symbol] = stock;
      }
      notifyListeners();
    } catch (e) {
      debugPrint('RefreshPrices Error: $e');
    }
  }

  /// Thêm hoặc cập nhật một mã trong danh mục.
  Future<void> upsertEntry(String symbol, int quantity, double price) async {
    final index = _items.indexWhere((e) => e.symbol == symbol);
    final newItem = PortfolioItem(
      symbol: symbol,
      quantity: quantity,
      averagePrice: price,
    );

    if (index >= 0) {
      _items[index] = newItem;
    } else {
      _items.add(newItem);
    }

    if (_uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('portfolio')
          .doc(symbol)
          .set(newItem.toMap());
    }

    // Fetch giá ngay lập tức cho mã mới
    final stock = await YahooFinanceService.instance.fetchSingleQuote(symbol);
    if (stock != null) {
      _priceCache[symbol] = stock;
    }

    notifyListeners();
  }

  /// Xóa một mã khỏi danh mục.
  Future<void> removeEntry(String symbol) async {
    _items.removeWhere((e) => e.symbol == symbol);
    
    if (_uid != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(_uid)
          .collection('portfolio')
          .doc(symbol)
          .delete();
    }
    
    notifyListeners();
  }
}
