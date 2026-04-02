import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/stock_symbols.dart';
import '../models/stock_symbol_model.dart';
import 'api_service.dart';

class StockSymbolRepository {
  StockSymbolRepository._internal();

  static final StockSymbolRepository instance = StockSymbolRepository._internal();

  static const String _cacheKey = 'cached_all_symbols_vn';
  static const Duration _cacheTtl = Duration(hours: 12);
  static const String _cacheTimestampKey = 'cached_all_symbols_vn_timestamp';

  final ApiService _apiService = ApiService.instance;

  List<StockSymbolModel>? _cache;
  DateTime? _lastFetched;

  Future<List<StockSymbolModel>> getAllSymbols({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final List<StockSymbolModel>? inMemory = _cache;
      if (inMemory != null && inMemory.isNotEmpty) {
        return inMemory;
      }
    }
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!forceRefresh) {
      final List<StockSymbolModel>? fromStorage = _loadFromPrefs(prefs);
      if (fromStorage != null && fromStorage.isNotEmpty) {
        _cache = fromStorage;
        return fromStorage;
      }
    }

    final List<StockSymbolModel> fetched = await _apiService.fetchAllVietnamSymbols();
    _cache = fetched;
    await _saveToPrefs(prefs, fetched);
    return fetched;
  }

  Future<List<StockSymbolModel>> refresh() async {
    return getAllSymbols(forceRefresh: true);
  }

  List<StockSymbolModel>? _loadFromPrefs(SharedPreferences prefs) {
    final String? raw = prefs.getString(_cacheKey);
    final int? timestamp = prefs.getInt(_cacheTimestampKey);
    if (raw == null || timestamp == null) {
      return null;
    }
    final DateTime savedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    if (DateTime.now().difference(savedTime) > _cacheTtl) {
      return null;
    }
    try {
      final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
      final List<StockSymbolModel> symbols = decoded
          .map((dynamic item) => StockSymbolModel.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((StockSymbolModel a, StockSymbolModel b) => a.displaySymbol.compareTo(b.displaySymbol));
      _cache = symbols;
      _lastFetched = savedTime;
      return symbols;
    } catch (error) {
      debugPrint('Error decoding cached symbols: $error');
      return null;
    }
  }

  Future<void> _saveToPrefs(SharedPreferences prefs, List<StockSymbolModel> symbols) async {
    final String encoded = jsonEncode(symbols.map((StockSymbolModel symbol) => symbol.toJson()).toList());
    await prefs.setString(_cacheKey, encoded);
    await prefs.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
    _lastFetched = DateTime.now();
  }

  List<StockSymbolModel> getDefaultWatchlist() {
    final List<StockSymbol> defaults = kTrackedStockSymbols.take(8).toList();
    return defaults
        .map(
          (StockSymbol symbol) => StockSymbolModel(
            displaySymbol: symbol.displaySymbol,
            apiSymbol: symbol.apiSymbol,
            companyName: symbol.companyName,
            exchange: symbol.exchange,
          ),
        )
        .toList(growable: false);
  }
}
