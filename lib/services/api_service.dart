import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../constants/stock_symbols.dart';
import '../models/market_index.dart';
import '../models/market_news.dart';
import '../models/portfolio.dart';
import '../models/stock.dart';
import '../models/user.dart';
import '../models/stock_symbol_model.dart';

class ApiService {
  ApiService._internal({http.Client? client}) : _client = client ?? http.Client();

  static final ApiService instance = ApiService._internal();

  static const String _baseUrl = 'https://finnhub.io/api/v1';
  final http.Client _client;

  Map<String, String>? _vietnamSymbolMap;

  String get _apiKey => dotenv.env['FINNHUB_API_KEY'] ?? '';

  void _validateApiKey() {
    if (_apiKey.isEmpty) {
      throw StateError(
        'Thiếu FINNHUB_API_KEY. Vui lòng tạo file .env và khai báo FINNHUB_API_KEY=<api_key> trước khi chạy ứng dụng.',
      );
    }
  }

  Future<void> _ensureVietnamSymbolMap() async {
    if (_vietnamSymbolMap != null) {
      return;
    }
    final Uri uri = Uri.parse('$_baseUrl/stock/symbol?exchange=VN&token=$_apiKey');
    try {
      final http.Response response = await _client.get(uri);
      if (response.statusCode == 200) {
        final dynamic data = jsonDecode(response.body);
        if (data is List) {
          final Map<String, String> map = <String, String>{};
          for (final dynamic item in data) {
            if (item is! Map<String, dynamic>) continue;
            final String? symbol = item['symbol'] as String?;
            final String? displaySymbol = item['displaySymbol'] as String?;
            if (symbol == null) continue;
            map[symbol.toUpperCase()] = symbol;
            if (displaySymbol != null) {
              map[displaySymbol.toUpperCase()] = symbol;
            }
          }
          _vietnamSymbolMap = map;
          return;
        }
      }
    } catch (_) {
      // Bỏ qua, sẽ sử dụng fallback.
    }
    _vietnamSymbolMap = <String, String>{};
  }

  Future<List<StockSymbolModel>> fetchAllVietnamSymbols() async {
    _validateApiKey();
    final Uri uri = Uri.parse('$_baseUrl/stock/symbol?exchange=VN&token=$_apiKey');
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Không thể tải danh sách mã cổ phiếu: ${response.statusCode}');
    }
    final dynamic data = jsonDecode(response.body);
    if (data is! List) {
      return <StockSymbolModel>[];
    }
    final List<StockSymbolModel> symbols = data
        .map((dynamic item) => StockSymbolModel.fromJson(item as Map<String, dynamic>))
        .where((StockSymbolModel symbol) => symbol.displaySymbol.isNotEmpty && symbol.apiSymbol.isNotEmpty)
        .toList()
      ..sort((StockSymbolModel a, StockSymbolModel b) => a.displaySymbol.compareTo(b.displaySymbol));
    _vietnamSymbolMap = <String, String>{
      for (final StockSymbolModel symbol in symbols) symbol.displaySymbol.toUpperCase(): symbol.apiSymbol,
      for (final StockSymbolModel symbol in symbols) symbol.apiSymbol.toUpperCase(): symbol.apiSymbol,
    };
    return symbols;
  }

  Future<List<MarketIndex>> fetchMarketIndices() async {
    _validateApiKey();
    final List<Map<String, String>> indexConfigs = <Map<String, String>>[
      <String, String>{'symbol': '^VNINDEX', 'name': 'VN-Index'},
      <String, String>{'symbol': '^HNXI', 'name': 'HNX'},
      <String, String>{'symbol': '^UPCOM', 'name': 'UPCoM'},
    ];
    final List<MarketIndex> results = <MarketIndex>[];
    for (final Map<String, String> config in indexConfigs) {
      final Uri uri = Uri.parse('$_baseUrl/index/quote?symbol=${config['symbol']}&token=$_apiKey');
      try {
        final http.Response response = await _client.get(uri);
        if (response.statusCode == 200) {
          final dynamic data = jsonDecode(response.body);
          if (data is Map<String, dynamic> && data['c'] != null) {
            final double current = (data['c'] as num).toDouble();
            final double prevClose = (data['pc'] as num?)?.toDouble() ?? current;
            final double changePercent = prevClose == 0 ? 0 : (current - prevClose) / prevClose * 100;
            results.add(
              MarketIndex(
                name: config['name']!,
                value: current,
                changePercent: changePercent,
              ),
            );
            continue;
          }
        }
      } catch (_) {
        // Ignored: sẽ thêm giá trị mặc định bên dưới
      }
      results.add(MarketIndex(name: config['name']!, value: 0, changePercent: 0));
    }
    return results;
  }

  Future<List<Stock>> fetchWatchlist({
    List<StockSymbol>? symbols,
    List<StockSymbolModel>? symbolModels,
  }) async {
    _validateApiKey();
    await _ensureVietnamSymbolMap();

    final List<StockSymbolModel> targets;
    if (symbolModels != null && symbolModels.isNotEmpty) {
      targets = symbolModels;
    } else if (symbols != null && symbols.isNotEmpty) {
      targets = symbols
          .map(
            (StockSymbol symbol) => StockSymbolModel(
              displaySymbol: symbol.displaySymbol,
              apiSymbol: symbol.apiSymbol,
              companyName: symbol.companyName,
              exchange: symbol.exchange,
            ),
          )
          .toList(growable: false);
    } else {
      targets = kTrackedStockSymbols
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

    final List<Stock> stocks = <Stock>[];
    const int chunkSize = 10;
    for (int i = 0; i < targets.length; i += chunkSize) {
      final Iterable<StockSymbolModel> chunk = targets.skip(i).take(chunkSize);
      final List<Future<Stock?>> futures = chunk.map(_fetchSingleQuote).toList();
      final List<Stock?> results = await Future.wait(futures);
      stocks.addAll(results.whereType<Stock>());
    }
    return stocks;
  }

  Future<Stock?> _fetchSingleQuote(StockSymbolModel symbol) async {
    final String key = symbol.displaySymbol.toUpperCase();
    final String resolvedSymbol = _vietnamSymbolMap?[key] ?? symbol.apiSymbol;
    final List<String> candidates = <String>{
      resolvedSymbol,
      if (!resolvedSymbol.contains('.')) '${resolvedSymbol}.VN',
      if (!resolvedSymbol.contains(':')) 'HOSE:$resolvedSymbol',
      if (!resolvedSymbol.contains(':')) 'VND:$resolvedSymbol',
    }.where((String candidate) => candidate.isNotEmpty).toList();

    for (final String candidate in candidates) {
      final Stock? result = await _fetchQuoteInternal(candidate, symbol);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  Future<Stock?> _fetchQuoteInternal(String apiSymbol, StockSymbolModel original) async {
    final Uri uri = Uri.parse('$_baseUrl/quote?symbol=$apiSymbol&token=$_apiKey');
    try {
      final http.Response response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }
      final dynamic data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) {
        return null;
      }
      final num? current = data['c'] as num?;
      final num? changePercentRaw = data['dp'] as num?;
      final num? previousClose = data['pc'] as num?;
      if (current == null || current == 0) {
        return null;
      }
      double changePercent;
      if (changePercentRaw != null) {
        changePercent = changePercentRaw.toDouble();
      } else if (previousClose != null && previousClose != 0) {
        changePercent = (current - previousClose) / previousClose * 100;
      } else {
        changePercent = 0;
      }
      return Stock(
        symbol: original.displaySymbol,
        name: (original.companyName.isEmpty ? original.displaySymbol : original.companyName),
        price: current.toDouble(),
        changePercent: changePercent,
        volume: 0,
        apiSymbol: apiSymbol,
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<MarketNews>> fetchMarketNews() async {
    _validateApiKey();
    final DateTime now = DateTime.now();
    final DateTime from = now.subtract(const Duration(days: 3));
    final Uri uri = Uri.parse(
      '$_baseUrl/news?category=general&from=${from.toIso8601String().substring(0, 10)}&token=$_apiKey',
    );
    final http.Response response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Không thể tải tin tức: ${response.statusCode}');
    }
    final dynamic data = jsonDecode(response.body);
    if (data is! List) {
      return <MarketNews>[];
    }
    return data.take(20).map((dynamic item) {
      final Map<String, dynamic> json = item as Map<String, dynamic>;
      final int timestampSeconds = ((json['datetime'] as num?)?.toInt() ?? 0);
      final DateTime published = timestampSeconds == 0
          ? DateTime.now()
          : DateTime.fromMillisecondsSinceEpoch(timestampSeconds * 1000, isUtc: true).toLocal();
      return MarketNews(
        title: json['headline'] as String? ?? 'Tin tức',
        source: json['source'] as String? ?? 'Nguồn khác',
        publishedAt: published,
        url: json['url'] as String?,
      );
    }).toList();
  }

  Future<List<StockPricePoint>> fetchIntradayPrices(
    String displaySymbol, {
    String? apiSymbol,
  }) async {
    _validateApiKey();
    await _ensureVietnamSymbolMap();
    final DateTime now = DateTime.now();
    final DateTime from = now.subtract(const Duration(hours: 8));
    final List<String> candidates = _buildSymbolCandidates(displaySymbol, apiSymbol: apiSymbol);
    for (final String candidate in candidates) {
      final Uri uri = Uri.parse(
        '$_baseUrl/stock/candle?symbol=$candidate&resolution=30&from=${from.millisecondsSinceEpoch ~/ 1000}&to=${now.millisecondsSinceEpoch ~/ 1000}&token=$_apiKey',
      );
      try {
        final http.Response response = await _client.get(uri);
        if (response.statusCode != 200) {
          continue;
        }
        final dynamic data = jsonDecode(response.body);
        final List<StockPricePoint> points = _parseCandles(data, useDateLabel: false);
        if (points.isNotEmpty) {
          return points;
        }
      } catch (_) {
        // ignore and try next candidate
      }
    }
    return <StockPricePoint>[];
  }

  Future<List<StockPricePoint>> fetchHistoricalPrices(
    String displaySymbol, {
    String? apiSymbol,
  }) async {
    _validateApiKey();
    await _ensureVietnamSymbolMap();
    final DateTime now = DateTime.now();
    final DateTime from = now.subtract(const Duration(days: 30));
    final List<String> candidates = _buildSymbolCandidates(displaySymbol, apiSymbol: apiSymbol);
    for (final String candidate in candidates) {
      final Uri uri = Uri.parse(
        '$_baseUrl/stock/candle?symbol=$candidate&resolution=D&from=${from.millisecondsSinceEpoch ~/ 1000}&to=${now.millisecondsSinceEpoch ~/ 1000}&token=$_apiKey',
      );
      try {
        final http.Response response = await _client.get(uri);
        if (response.statusCode != 200) {
          continue;
        }
        final dynamic data = jsonDecode(response.body);
        final List<StockPricePoint> points = _parseCandles(data, useDateLabel: true);
        if (points.isNotEmpty) {
          return points;
        }
      } catch (_) {
        // ignore and try next candidate
      }
    }
    return <StockPricePoint>[];
  }

  List<String> _buildSymbolCandidates(String displaySymbol, {String? apiSymbol}) {
    final String upper = displaySymbol.toUpperCase();
    final String baseSymbol = (apiSymbol != null && apiSymbol.isNotEmpty) ? apiSymbol : upper;
    final String resolved = _vietnamSymbolMap?[upper] ?? baseSymbol;
    final Set<String> candidates = <String>{};
    if (resolved.isNotEmpty) {
      candidates.add(resolved);
      if (!resolved.contains('.')) {
        candidates.add('${resolved}.VN');
      }
      if (!resolved.contains(':')) {
        candidates.add('HOSE:$resolved');
        candidates.add('VND:$resolved');
      }
    }
    return candidates.where((String symbol) => symbol.isNotEmpty).toList();
  }

  List<StockPricePoint> _parseCandles(dynamic data, {required bool useDateLabel}) {
    if (data is! Map<String, dynamic>) {
      return <StockPricePoint>[];
    }
    if (data['s'] != 'ok') {
      return <StockPricePoint>[];
    }
    final List<dynamic> closes = data['c'] as List<dynamic>;
    final List<dynamic> times = data['t'] as List<dynamic>;
    final int length = closes.length < times.length ? closes.length : times.length;
    final List<StockPricePoint> points = <StockPricePoint>[];
    for (int i = 0; i < length; i++) {
      final double price = (closes[i] as num).toDouble();
      final int timestamp = (times[i] as num).toInt();
      final DateTime time = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true).toLocal();
      final String label = useDateLabel
          ? '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}'
          : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      points.add(StockPricePoint(timeLabel: label, price: price));
    }
    return points;
  }

  Future<PortfolioSummary> fetchPortfolio() async {
    // TODO(thanhvien4): Đồng bộ dữ liệu danh mục với backend hoặc local DB.
    final List<Stock> trackedStocks = await fetchWatchlist();
    final List<PortfolioEntry> entries = <PortfolioEntry>[
      if (trackedStocks.isNotEmpty)
        PortfolioEntry(stock: trackedStocks[0], quantity: 120, averagePrice: trackedStocks[0].price * 0.95),
      if (trackedStocks.length > 1)
        PortfolioEntry(stock: trackedStocks[1], quantity: 80, averagePrice: trackedStocks[1].price * 1.05),
      if (trackedStocks.length > 2)
        PortfolioEntry(stock: trackedStocks[2], quantity: 150, averagePrice: trackedStocks[2].price * 0.9),
    ];
    return PortfolioSummary(entries: entries);
  }

  Future<UserProfile> fetchUserProfile() async {
    // TODO(thanhvien5): Lấy dữ liệu hồ sơ thực từ backend.
    return const UserProfile(
      fullName: 'Nguyễn Văn A',
      email: 'vana@example.com',
      phone: '+84 912 345 678',
      receiveNotifications: true,
      preferredLanguage: 'vi',
      darkMode: false,
    );
  }

  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    // TODO(thanhvien5): Gửi dữ liệu lên backend.
    return profile;
  }
}
