import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/stock_symbols.dart';
import '../models/stock_symbol_model.dart';
import '../services/stock_symbol_repository.dart';

class WatchlistProvider extends ChangeNotifier {
  WatchlistProvider() {
    unawaited(_initialize());
  }

  static const String _storageKey = 'watchlist_symbols';
  static const int _defaultCount = 8;

  final List<String> _symbols = <String>[];
  final List<StockSymbolModel> _allSymbols = <StockSymbolModel>[];
  Map<String, StockSymbolModel> _symbolLookup = <String, StockSymbolModel>{};
  bool _isLoading = true;

  bool get isLoading => _isLoading;
  List<StockSymbolModel> get availableSymbols => _allSymbols;

  List<StockSymbolModel> get trackedSymbols {
    if (_symbols.isEmpty && _allSymbols.isEmpty) {
      return StockSymbolRepository.instance.getDefaultWatchlist();
    }
    return _symbols
        .map(
          (String code) => _symbolLookup[code] ??
              StockSymbolModel(
                displaySymbol: code,
                apiSymbol: code,
                companyName: code,
                exchange: 'VN',
              ),
        )
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
    _ensureSymbolInLookup(code);
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
    final List<StockSymbolModel> defaults = StockSymbolRepository.instance.getDefaultWatchlist();
    _symbols
      ..clear()
      ..addAll(defaults.map((StockSymbolModel symbol) => symbol.displaySymbol));
    await _save();
    notifyListeners();
  }

  Future<void> refreshSymbolCatalog() async {
    try {
      final List<StockSymbolModel> fetched = await StockSymbolRepository.instance.refresh();
      _allSymbols
        ..clear()
        ..addAll(fetched);
      _symbolLookup = <String, StockSymbolModel>{
        for (final StockSymbolModel symbol in _allSymbols) symbol.displaySymbol.toUpperCase(): symbol,
      };
      for (final String code in _symbols) {
        _ensureSymbolInLookup(code);
      }
      notifyListeners();
    } catch (error) {
      debugPrint('WatchlistProvider refreshSymbolCatalog error: $error');
    }
  }

  Future<void> _initialize() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? stored = prefs.getStringList(_storageKey);

      final List<StockSymbolModel> fetched = await StockSymbolRepository.instance.getAllSymbols();
      _allSymbols
        ..clear()
        ..addAll(fetched);
      _symbolLookup = <String, StockSymbolModel>{
        for (final StockSymbolModel symbol in _allSymbols) symbol.displaySymbol.toUpperCase(): symbol,
      };

      if (stored != null && stored.isNotEmpty) {
        _symbols
          ..clear()
          ..addAll(stored.map((String code) => code.toUpperCase()));
      } else {
        final List<StockSymbolModel> defaults = StockSymbolRepository.instance.getDefaultWatchlist();
        _symbols
          ..clear()
          ..addAll(defaults.map((StockSymbolModel symbol) => symbol.displaySymbol));
      }
      for (final String code in _symbols) {
        _ensureSymbolInLookup(code);
      }
    } catch (error) {
      debugPrint('WatchlistProvider initialization error: $error');
      if (_symbols.isEmpty) {
        _symbols
          ..clear()
          ..addAll(
            kTrackedStockSymbols.take(_defaultCount).map((StockSymbol e) => e.displaySymbol),
          );
      }
      if (_allSymbols.isEmpty) {
        final List<StockSymbolModel> defaults = StockSymbolRepository.instance.getDefaultWatchlist();
        _allSymbols
          ..clear()
          ..addAll(defaults);
        _symbolLookup = <String, StockSymbolModel>{
          for (final StockSymbolModel symbol in _allSymbols) symbol.displaySymbol.toUpperCase(): symbol,
        };
      }
      for (final String code in _symbols) {
        _ensureSymbolInLookup(code);
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _ensureSymbolInLookup(String code) {
    if (_symbolLookup.containsKey(code)) {
      return;
    }
    for (final StockSymbolModel symbol in _allSymbols) {
      if (symbol.displaySymbol.toUpperCase() == code) {
        _symbolLookup[code] = symbol;
        return;
      }
    }
    _symbolLookup[code] = StockSymbolModel(
      displaySymbol: code,
      apiSymbol: code,
      companyName: code,
      exchange: 'VN',
    );
  }

  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_storageKey, List<String>.from(_symbols));
  }
}
