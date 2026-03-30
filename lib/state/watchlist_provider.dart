import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/stock_symbols.dart';

class WatchlistProvider extends ChangeNotifier {
  WatchlistProvider() {
    _loadFromStorage();
  }

  static const String _storageKey = 'watchlist_symbols';
  static const int _defaultCount = 8;

  final List<String> _symbols = <String>[];
  bool _isLoading = true;

  bool get isLoading => _isLoading;

  List<StockSymbol> get trackedSymbols {
    return _symbols
        .map((String code) => kStockSymbolLookup[code] ??
            kTrackedStockSymbols.firstWhere((StockSymbol symbol) => symbol.displaySymbol == code,
                orElse: () => StockSymbol(
                      displaySymbol: code,
                      apiSymbol: code,
                      companyName: code,
                      exchange: 'HOSE',
                    )))
        .toList(growable: false);
  }

  bool containsSymbol(String displaySymbol) {
    return _symbols.contains(displaySymbol.toUpperCase());
  }

  Future<void> addSymbol(String displaySymbol) async {
    final String code = displaySymbol.toUpperCase();
    if (_symbols.contains(code)) {
      return;
    }
    _symbols.add(code);
    await _save();
    notifyListeners();
  }

  Future<void> removeSymbol(String displaySymbol) async {
    if (_symbols.remove(displaySymbol.toUpperCase())) {
      await _save();
      notifyListeners();
    }
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final String item = _symbols.removeAt(oldIndex);
    _symbols.insert(newIndex, item);
    await _save();
    notifyListeners();
  }

  Future<void> resetToDefault() async {
    _symbols
      ..clear()
      ..addAll(
        kTrackedStockSymbols.take(_defaultCount).map((StockSymbol e) => e.displaySymbol),
      );
    await _save();
    notifyListeners();
  }

  Future<void> _loadFromStorage() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? stored = prefs.getStringList(_storageKey);
      if (stored != null && stored.isNotEmpty) {
        _symbols
          ..clear()
          ..addAll(stored.map((String code) => code.toUpperCase()));
      } else {
        _symbols
          ..clear()
          ..addAll(
            kTrackedStockSymbols.take(_defaultCount).map((StockSymbol e) => e.displaySymbol),
          );
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, List<String>.from(_symbols));
  }
}
