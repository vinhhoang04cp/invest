import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../constants/stock_symbols.dart';
import '../models/market_index.dart';
import '../models/market_news.dart';
import '../models/portfolio.dart';
import '../models/stock.dart';
import '../models/stock_symbol_model.dart';
import '../models/user.dart';
import 'logger_service.dart';

// ---------------------------------------------------------------------------
// Yahoo Finance Auth Manager
// Uses the fc.yahoo.com + getcrumb approach (most reliable method)
// ---------------------------------------------------------------------------

class _YahooAuthManager {
  _YahooAuthManager(this._client, this._logger);

  final http.Client _client;
  final LoggerService _logger;

  String? _crumb;
  String? _cookie;
  DateTime? _lastAuth;
  int _failCount = 0;

  static const Duration _authTtl = Duration(minutes: 20);
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  bool get _isValid =>
      _crumb != null &&
      _cookie != null &&
      _lastAuth != null &&
      DateTime.now().difference(_lastAuth!) < _authTtl;

  bool get hasAuth => _crumb != null && _cookie != null;

  Future<void> ensureAuth({bool force = false}) async {
    if (!force && _isValid) return;
    // Don't retry too aggressively if auth keeps failing
    if (_failCount > 3 && !force) {
      _logger.warning('Yahoo Auth: Too many failures, skipping auth');
      return;
    }
    await _authenticate();
  }

  void invalidate() {
    _crumb = null;
    _cookie = null;
    _lastAuth = null;
  }

  String? get crumb => _crumb;

  Map<String, String> get headers {
    final Map<String, String> h = <String, String>{
      'User-Agent': _userAgent,
      'Accept': 'application/json,text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    if (_cookie != null) {
      h['Cookie'] = _cookie!;
    }
    return h;
  }

  /// Build URI with crumb parameter appended
  Uri withCrumb(Uri uri) {
    if (_crumb == null) return uri;
    final Map<String, dynamic> params = Map<String, dynamic>.from(uri.queryParameters);
    params['crumb'] = _crumb!;
    return uri.replace(queryParameters: params);
  }

  Future<void> _authenticate() async {
    try {
      _logger.info('Yahoo Auth: Starting authentication...');

      // ---- Method 1: fc.yahoo.com approach (most reliable) ----
      // Step 1: Hit fc.yahoo.com to get a cookie (returns 404 but sets cookie)
      final http.Response cookieResponse = await _client.get(
        Uri.parse('https://fc.yahoo.com'),
        headers: <String, String>{
          'User-Agent': _userAgent,
        },
      );

      String? cookie = _extractCookies(cookieResponse);
      _logger.debug('Yahoo Auth: fc.yahoo.com status=${cookieResponse.statusCode}, cookie=${cookie != null ? "present" : "null"}');

      // If fc.yahoo.com didn't return cookies, try login.yahoo.com consent
      if (cookie == null || cookie.isEmpty) {
        final http.Response consentResponse = await _client.get(
          Uri.parse('https://login.yahoo.com/'),
          headers: <String, String>{
            'User-Agent': _userAgent,
          },
        );
        cookie = _extractCookies(consentResponse);
        _logger.debug('Yahoo Auth: login.yahoo.com status=${consentResponse.statusCode}, cookie=${cookie != null ? "present" : "null"}');
      }

      if (cookie != null && cookie.isNotEmpty) {
        _cookie = cookie;
      }

      // Step 2: Get crumb using the cookie
      if (_cookie != null) {
        final http.Response crumbResponse = await _client.get(
          Uri.parse('https://query2.finance.yahoo.com/v1/test/getcrumb'),
          headers: headers,
        );

        _logger.debug('Yahoo Auth: getcrumb status=${crumbResponse.statusCode}, body=${crumbResponse.body.length > 50 ? crumbResponse.body.substring(0, 50) : crumbResponse.body}');

        if (crumbResponse.statusCode == 200 &&
            crumbResponse.body.isNotEmpty &&
            !crumbResponse.body.contains('<')) {
          _crumb = crumbResponse.body.trim();
          _lastAuth = DateTime.now();
          _failCount = 0;
          _logger.info('Yahoo Auth: ✅ Authenticated (crumb=${_crumb!.substring(0, min(6, _crumb!.length))}...)');
          return;
        }
      }

      // ---- Method 2: Fall back to extracting crumb from page HTML ----
      _logger.info('Yahoo Auth: Method 1 failed, trying HTML extraction...');
      final http.Response pageResponse = await _client.get(
        Uri.parse('https://finance.yahoo.com/quote/%5EGSPC/'),
        headers: <String, String>{'User-Agent': _userAgent},
      );

      // Extract cookies from page response
      final String? pageCookie = _extractCookies(pageResponse);
      if (pageCookie != null && pageCookie.isNotEmpty) {
        _cookie = pageCookie;
      }

      // Try to extract crumb from HTML
      if (pageResponse.statusCode == 200) {
        final String body = pageResponse.body;
        // Look for crumb in various patterns
        String? extractedCrumb;

        // Pattern 1: "crumb":"xxx"
        final RegExp crumbPattern = RegExp(r'"crumb"\s*:\s*"([^"]+)"');
        final Match? match = crumbPattern.firstMatch(body);
        if (match != null) {
          extractedCrumb = match.group(1);
        }

        // Pattern 2: CrumbStore
        if (extractedCrumb == null) {
          final RegExp crumbStorePattern = RegExp(r'"CrumbStore"\s*:\s*\{"crumb"\s*:\s*"([^"]+)"\}');
          final Match? storeMatch = crumbStorePattern.firstMatch(body);
          if (storeMatch != null) {
            extractedCrumb = storeMatch.group(1);
          }
        }

        if (extractedCrumb != null && extractedCrumb.isNotEmpty) {
          // Unescape unicode
          _crumb = extractedCrumb.replaceAll(r'\u002F', '/');
          _lastAuth = DateTime.now();
          _failCount = 0;
          _logger.info('Yahoo Auth: ✅ Authenticated via HTML (crumb=${_crumb!.substring(0, min(6, _crumb!.length))}...)');
          return;
        }
      }

      // Auth failed - proceed without crumb (some endpoints still work)
      _failCount++;
      _lastAuth = DateTime.now(); // Avoid retrying too fast
      _logger.warning('Yahoo Auth: ⚠️ Could not obtain crumb (fail #$_failCount). Will try requests without crumb.');
    } catch (e, st) {
      _failCount++;
      _lastAuth = DateTime.now();
      _logger.error('Yahoo Auth: ❌ Exception during auth (fail #$_failCount)', e, st);
    }
  }

  /// Extract cookie values from a response's Set-Cookie header
  String? _extractCookies(http.Response response) {
    final String? setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;

    // Parse multiple cookies (they may be comma-separated or in multiple headers)
    final List<String> cookieParts = <String>[];
    for (final String part in setCookie.split(RegExp(r',(?=[^ ])'))) {
      final String trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      // Extract just the name=value portion (before first ;)
      final int semiIdx = trimmed.indexOf(';');
      final String nameValue = semiIdx >= 0 ? trimmed.substring(0, semiIdx) : trimmed;
      if (nameValue.contains('=')) {
        cookieParts.add(nameValue.trim());
      }
    }
    return cookieParts.isEmpty ? null : cookieParts.join('; ');
  }
}

// ---------------------------------------------------------------------------
// Yahoo Finance Service
// ---------------------------------------------------------------------------

class YahooFinanceService {
  YahooFinanceService._internal({http.Client? client})
      : _client = client ?? http.Client() {
    _auth = _YahooAuthManager(_client, _logger);
  }

  static final YahooFinanceService instance = YahooFinanceService._internal();

  final http.Client _client;
  final LoggerService _logger = LoggerService();
  late final _YahooAuthManager _auth;

  // Cache for symbol search results
  List<StockSymbolModel>? _cachedSymbols;

  // ---- Helper methods ----

  /// Converts a Vietnamese stock symbol to Yahoo Finance format.
  /// VCB → VCB.VN, ^VNINDEX stays as-is.
  String toYahooSymbol(String symbol) {
    final String upper = symbol.toUpperCase().trim();
    if (upper.startsWith('^')) return upper;
    if (upper.endsWith('.VN')) return upper;
    return '$upper.VN';
  }

  /// Makes an authenticated GET request to Yahoo Finance.
  /// Retries once with fresh auth if 401/403.
  Future<http.Response> _authGet(Uri uri) async {
    await _auth.ensureAuth();

    // Add crumb to URI if available
    final Uri requestUri = _auth.withCrumb(uri);

    _logger.logApiCall('GET', requestUri.toString());
    http.Response response = await _client.get(requestUri, headers: _auth.headers);
    _logger.logApiResponse(requestUri.toString(),
        statusCode: response.statusCode, body: '(${response.body.length} bytes)');

    // If unauthorized, re-authenticate and retry once
    if (response.statusCode == 401 || response.statusCode == 403) {
      _logger.warning('Yahoo: Got ${response.statusCode}, re-authenticating...');
      _auth.invalidate();
      await _auth.ensureAuth(force: true);

      final Uri retryUri = _auth.withCrumb(uri);
      response = await _client.get(retryUri, headers: _auth.headers);
      _logger.logApiResponse(retryUri.toString(),
          statusCode: response.statusCode, body: '(${response.body.length} bytes)');
    }

    return response;
  }

  /// Simple retry wrapper for API calls.
  Future<T> _retry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 2,
    String? label,
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e, st) {
        if (attempt >= maxAttempts) {
          _logger.error(
            '[$label] Failed after $attempt attempts', e, st,
          );
          rethrow;
        }
        _logger.warning('[$label] Attempt $attempt failed, retrying...');
        await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
      }
    }
    throw StateError('Unreachable');
  }

  // ---- Public API ----

  /// Fetch quotes for multiple symbols.
  /// Strategy: Try v7/quote first, fall back to v8/chart extraction.
  Future<List<Stock>> fetchQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return <Stock>[];

    // Try v7 quote endpoint first
    final List<Stock>? v7Result = await _tryFetchQuotesV7(symbols);
    if (v7Result != null && v7Result.isNotEmpty) {
      return v7Result;
    }

    // Fallback: extract quote data from v8 chart endpoint (more permissive)
    _logger.info('fetchQuotes: v7 failed, falling back to v8/chart...');
    return _fetchQuotesViaChart(symbols);
  }

  /// Try fetching quotes via v7/finance/quote
  Future<List<Stock>?> _tryFetchQuotesV7(List<String> symbols) async {
    try {
      final String yahooSymbols = symbols.map(toYahooSymbol).join(',');

      final Uri uri = Uri.parse(
        'https://query1.finance.yahoo.com/v7/finance/quote'
        '?symbols=$yahooSymbols'
        '&fields=symbol,shortName,longName,regularMarketPrice,regularMarketChangePercent,'
        'regularMarketVolume,regularMarketDayHigh,regularMarketDayLow,'
        'regularMarketOpen,regularMarketPreviousClose,marketCap',
      );

      final http.Response response = await _authGet(uri);

      if (response.statusCode != 200) {
        _logger.warning('v7/quote returned ${response.statusCode}');
        return null;
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      final Map<String, dynamic>? quoteResponse =
          data['quoteResponse'] as Map<String, dynamic>?;
      if (quoteResponse == null) return null;

      final List<dynamic>? results =
          quoteResponse['result'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      return results.map((dynamic item) {
        final Map<String, dynamic> q = item as Map<String, dynamic>;
        final String rawSymbol = (q['symbol'] as String? ?? '');
        final String displaySymbol =
            rawSymbol.replaceAll('.VN', '').toUpperCase();

        return Stock(
          symbol: displaySymbol,
          name: q['longName'] as String? ??
              q['shortName'] as String? ??
              displaySymbol,
          price: (q['regularMarketPrice'] as num?)?.toDouble() ?? 0,
          changePercent:
              (q['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
          volume: (q['regularMarketVolume'] as num?)?.toInt() ?? 0,
          apiSymbol: rawSymbol,
          dayHigh: (q['regularMarketDayHigh'] as num?)?.toDouble(),
          dayLow: (q['regularMarketDayLow'] as num?)?.toDouble(),
          open: (q['regularMarketOpen'] as num?)?.toDouble(),
          previousClose:
              (q['regularMarketPreviousClose'] as num?)?.toDouble(),
          marketCap: (q['marketCap'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      _logger.warning('v7/quote exception: $e');
      return null;
    }
  }

  /// Fallback: Fetch quote data from v8/chart endpoint's meta field.
  /// The chart endpoint is generally more permissive with auth.
  Future<List<Stock>> _fetchQuotesViaChart(List<String> symbols) async {
    final List<Stock> stocks = <Stock>[];

    for (final String symbol in symbols) {
      try {
        final String yahooSymbol = toYahooSymbol(symbol);
        final Uri uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol'
          '?range=1d&interval=1d&includePrePost=false',
        );

        final http.Response response = await _authGet(uri);

        if (response.statusCode != 200) continue;

        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? results =
            (data['chart'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;

        if (results == null || results.isEmpty) continue;

        final Map<String, dynamic> result = results.first as Map<String, dynamic>;
        final Map<String, dynamic>? meta = result['meta'] as Map<String, dynamic>?;

        if (meta == null) continue;

        final double price = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0;
        final double prevClose = (meta['chartPreviousClose'] as num?)?.toDouble() ??
            (meta['previousClose'] as num?)?.toDouble() ?? price;
        final double changePercent = prevClose != 0
            ? ((price - prevClose) / prevClose * 100)
            : 0;

        final String displaySymbol = symbol.toUpperCase().replaceAll('.VN', '');

        // Try to get volume from indicators
        int volume = 0;
        final Map<String, dynamic>? indicators =
            result['indicators'] as Map<String, dynamic>?;
        final List<dynamic>? quoteList =
            indicators?['quote'] as List<dynamic>?;
        if (quoteList != null && quoteList.isNotEmpty) {
          final Map<String, dynamic> quote = quoteList.first as Map<String, dynamic>;
          final List<dynamic>? volumes = quote['volume'] as List<dynamic>?;
          if (volumes != null && volumes.isNotEmpty) {
            volume = (volumes.last as num?)?.toInt() ?? 0;
          }
        }

        // Find company name from constants
        final StockSymbol? knownSymbol = kStockSymbolLookup[displaySymbol];

        stocks.add(Stock(
          symbol: displaySymbol,
          name: knownSymbol?.companyName ?? meta['shortName'] as String? ?? displaySymbol,
          price: price,
          changePercent: changePercent,
          volume: volume,
          apiSymbol: yahooSymbol,
          previousClose: prevClose,
          dayHigh: (meta['regularMarketDayHigh'] as num?)?.toDouble(),
          dayLow: (meta['regularMarketDayLow'] as num?)?.toDouble(),
        ));
      } catch (e) {
        _logger.warning('v8/chart fallback failed for $symbol: $e');
      }
    }

    return stocks;
  }

  /// Fetch a single stock quote.
  Future<Stock?> fetchSingleQuote(String symbol) async {
    final List<Stock> results = await fetchQuotes(<String>[symbol]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Fetch market indices (VN-Index, HNX).
  Future<List<MarketIndex>> fetchMarketIndices() async {
    final List<Map<String, String>> indexConfigs = <Map<String, String>>[
      <String, String>{'symbol': '^VNINDEX', 'name': 'VN-Index'},
      <String, String>{'symbol': '^HNXI', 'name': 'HNX'},
    ];

    final List<MarketIndex> results = <MarketIndex>[];

    // Try v7 quote for indices
    try {
      final String symbols =
          indexConfigs.map((Map<String, String> c) => c['symbol']!).join(',');

      final Uri uri = Uri.parse(
        'https://query1.finance.yahoo.com/v7/finance/quote'
        '?symbols=$symbols'
        '&fields=symbol,regularMarketPrice,regularMarketChangePercent,'
        'regularMarketPreviousClose,regularMarketChange',
      );

      final http.Response response = await _authGet(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        final List<dynamic>? quotes =
            (data['quoteResponse'] as Map<String, dynamic>?)?['result']
                as List<dynamic>?;

        if (quotes != null && quotes.isNotEmpty) {
          for (final Map<String, String> config in indexConfigs) {
            final Map<String, dynamic>? q = _findQuoteBySymbol(quotes, config['symbol']!);

            if (q != null) {
              results.add(MarketIndex(
                name: config['name']!,
                value: (q['regularMarketPrice'] as num?)?.toDouble() ?? 0,
                changePercent:
                    (q['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
                previousClose:
                    (q['regularMarketPreviousClose'] as num?)?.toDouble(),
                change: (q['regularMarketChange'] as num?)?.toDouble(),
              ));
            }
          }

          if (results.isNotEmpty) return results;
        }
      }
    } catch (e) {
      _logger.warning('v7/quote for indices failed: $e');
    }

    // Fallback: Use v8/chart for each index
    for (final Map<String, String> config in indexConfigs) {
      try {
        final Uri uri = Uri.parse(
          'https://query1.finance.yahoo.com/v8/finance/chart/${config['symbol']}'
          '?range=1d&interval=1d&includePrePost=false',
        );

        final http.Response response = await _authGet(uri);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data =
              jsonDecode(response.body) as Map<String, dynamic>;
          final List<dynamic>? chartResults =
              (data['chart'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;

          if (chartResults != null && chartResults.isNotEmpty) {
            final Map<String, dynamic> meta =
                (chartResults.first as Map<String, dynamic>)['meta'] as Map<String, dynamic>;
            final double price = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0;
            final double prevClose =
                (meta['chartPreviousClose'] as num?)?.toDouble() ??
                (meta['previousClose'] as num?)?.toDouble() ?? price;
            final double changePct = prevClose != 0
                ? ((price - prevClose) / prevClose * 100)
                : 0;

            results.add(MarketIndex(
              name: config['name']!,
              value: price,
              changePercent: changePct,
              previousClose: prevClose,
              change: price - prevClose,
            ));
            continue;
          }
        }
      } catch (e) {
        _logger.warning('v8/chart for index ${config['symbol']} failed: $e');
      }

      // Final fallback: placeholder
      results.add(MarketIndex(
        name: config['name']!,
        value: 0,
        changePercent: 0,
      ));
    }

    return results;
  }

  /// Helper to find a quote by symbol in the results list
  Map<String, dynamic>? _findQuoteBySymbol(List<dynamic> quotes, String symbol) {
    for (final dynamic item in quotes) {
      final Map<String, dynamic> q = item as Map<String, dynamic>;
      if (q['symbol'] == symbol) return q;
    }
    return null;
  }

  /// Fetch watchlist stocks.
  Future<List<Stock>> fetchWatchlist({
    List<StockSymbol>? symbols,
    List<StockSymbolModel>? symbolModels,
  }) async {
    final List<String> displaySymbols;

    if (symbolModels != null && symbolModels.isNotEmpty) {
      displaySymbols =
          symbolModels.map((StockSymbolModel s) => s.displaySymbol).toList();
    } else if (symbols != null && symbols.isNotEmpty) {
      displaySymbols =
          symbols.map((StockSymbol s) => s.displaySymbol).toList();
    } else {
      displaySymbols = kTrackedStockSymbols
          .map((StockSymbol s) => s.displaySymbol)
          .toList();
    }

    // Yahoo Finance can handle multiple symbols per call
    // Split into chunks of 15 to be safe
    final List<Stock> allStocks = <Stock>[];
    const int chunkSize = 15;

    for (int i = 0; i < displaySymbols.length; i += chunkSize) {
      final List<String> chunk = displaySymbols
          .skip(i)
          .take(chunkSize)
          .toList();
      try {
        final List<Stock> stocks = await fetchQuotes(chunk);
        allStocks.addAll(stocks);
      } catch (e) {
        _logger.warning('Failed to fetch chunk starting at $i: $e');
      }
    }

    return allStocks;
  }

  /// Fetch chart data using Yahoo Finance v8 chart API.
  Future<List<StockPricePoint>> fetchChart(
    String displaySymbol, {
    String? apiSymbol,
    String range = '1d',
    String interval = '30m',
  }) async {
    return _retry(() async {
      final String yahooSymbol = apiSymbol ?? toYahooSymbol(displaySymbol);

      final Uri uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol'
        '?range=$range&interval=$interval&includePrePost=false',
      );

      final http.Response response = await _authGet(uri);

      if (response.statusCode != 200) {
        return <StockPricePoint>[];
      }

      return _parseChartResponse(response.body, useDateLabel: range != '1d');
    }, label: 'fetchChart($displaySymbol, $range)');
  }

  /// Fetch intraday prices (30-minute candles for today).
  Future<List<StockPricePoint>> fetchIntradayPrices(
    String displaySymbol, {
    String? apiSymbol,
  }) async {
    return fetchChart(
      displaySymbol,
      apiSymbol: apiSymbol,
      range: '1d',
      interval: '30m',
    );
  }

  /// Fetch historical prices (daily candles for 1 month).
  Future<List<StockPricePoint>> fetchHistoricalPrices(
    String displaySymbol, {
    String? apiSymbol,
  }) async {
    return fetchChart(
      displaySymbol,
      apiSymbol: apiSymbol,
      range: '1mo',
      interval: '1d',
    );
  }

  /// Parse Yahoo Finance v8 chart response.
  List<StockPricePoint> _parseChartResponse(
    String body, {
    required bool useDateLabel,
  }) {
    try {
      final Map<String, dynamic> data =
          jsonDecode(body) as Map<String, dynamic>;
      final Map<String, dynamic>? chart =
          data['chart'] as Map<String, dynamic>?;
      final List<dynamic>? results =
          chart?['result'] as List<dynamic>?;

      if (results == null || results.isEmpty) return <StockPricePoint>[];

      final Map<String, dynamic> result =
          results.first as Map<String, dynamic>;
      final List<dynamic>? timestamps =
          result['timestamp'] as List<dynamic>?;
      final Map<String, dynamic>? indicators =
          result['indicators'] as Map<String, dynamic>?;
      final List<dynamic>? quoteList =
          indicators?['quote'] as List<dynamic>?;

      if (timestamps == null || quoteList == null || quoteList.isEmpty) {
        return <StockPricePoint>[];
      }

      final Map<String, dynamic> quote =
          quoteList.first as Map<String, dynamic>;
      final List<dynamic>? closes = quote['close'] as List<dynamic>?;

      if (closes == null) return <StockPricePoint>[];

      final int length =
          timestamps.length < closes.length ? timestamps.length : closes.length;
      final List<StockPricePoint> points = <StockPricePoint>[];

      for (int i = 0; i < length; i++) {
        final num? closePrice = closes[i] as num?;
        if (closePrice == null) continue;

        final int timestamp = (timestamps[i] as num).toInt();
        final DateTime time = DateTime.fromMillisecondsSinceEpoch(
          timestamp * 1000,
          isUtc: true,
        ).toLocal();

        final String label = useDateLabel
            ? '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}'
            : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        points.add(StockPricePoint(
          timeLabel: label,
          price: closePrice.toDouble(),
        ));
      }

      return points;
    } catch (e, st) {
      _logger.error('Failed to parse chart response', e, st);
      return <StockPricePoint>[];
    }
  }

  /// Search for stock symbols using Yahoo Finance search API.
  Future<List<StockSymbolModel>> searchSymbols(String query) async {
    if (query.trim().isEmpty) return <StockSymbolModel>[];

    try {
      final Uri uri = Uri.parse(
        'https://query2.finance.yahoo.com/v1/finance/search'
        '?q=${Uri.encodeComponent(query)}'
        '&quotesCount=20&newsCount=0&listsCount=0'
        '&quotesQueryId=tss_match_phrase_query',
      );

      final http.Response response = await _authGet(uri);

      if (response.statusCode != 200) {
        return <StockSymbolModel>[];
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? quotes = data['quotes'] as List<dynamic>?;

      if (quotes == null) return <StockSymbolModel>[];

      return quotes
          .where((dynamic item) {
            final Map<String, dynamic> q = item as Map<String, dynamic>;
            final String symbol = q['symbol'] as String? ?? '';
            return symbol.endsWith('.VN') || symbol.startsWith('^VN');
          })
          .map((dynamic item) {
            final Map<String, dynamic> q = item as Map<String, dynamic>;
            final String rawSymbol = q['symbol'] as String? ?? '';
            final String displaySymbol =
                rawSymbol.replaceAll('.VN', '').toUpperCase();

            return StockSymbolModel(
              displaySymbol: displaySymbol,
              apiSymbol: rawSymbol,
              companyName: q['longname'] as String? ??
                  q['shortname'] as String? ??
                  displaySymbol,
              exchange: q['exchange'] as String? ?? 'VN',
            );
          })
          .toList();
    } catch (e) {
      _logger.warning('searchSymbols error: $e');
      return <StockSymbolModel>[];
    }
  }

  /// Fetch all Vietnamese stock symbols.
  Future<List<StockSymbolModel>> fetchAllVietnamSymbols() async {
    if (_cachedSymbols != null && _cachedSymbols!.isNotEmpty) {
      return _cachedSymbols!;
    }

    // Start with our hardcoded list
    final List<StockSymbolModel> symbols = kTrackedStockSymbols
        .map(
          (StockSymbol s) => StockSymbolModel(
            displaySymbol: s.displaySymbol,
            apiSymbol: '${s.displaySymbol}.VN',
            companyName: s.companyName,
            exchange: s.exchange,
          ),
        )
        .toList();

    // Try to enrich via Yahoo search
    try {
      final List<StockSymbolModel> searched = await searchSymbols('VN stock');
      final Set<String> existing =
          symbols.map((StockSymbolModel s) => s.displaySymbol).toSet();
      for (final StockSymbolModel s in searched) {
        if (!existing.contains(s.displaySymbol)) {
          symbols.add(s);
          existing.add(s.displaySymbol);
        }
      }
    } catch (e) {
      _logger.warning('Failed to enrich symbol list: $e');
    }

    symbols.sort((StockSymbolModel a, StockSymbolModel b) =>
        a.displaySymbol.compareTo(b.displaySymbol));

    _cachedSymbols = symbols;
    return symbols;
  }

  /// Refresh the symbol cache.
  Future<List<StockSymbolModel>> refreshSymbols() async {
    _cachedSymbols = null;
    return fetchAllVietnamSymbols();
  }

  /// Fetch market news.
  Future<List<MarketNews>> fetchMarketNews() async {
    try {
      final Uri uri = Uri.parse(
        'https://query2.finance.yahoo.com/v1/finance/search'
        '?q=Vietnam%20stock%20market'
        '&quotesCount=0&newsCount=15&listsCount=0',
      );

      final http.Response response = await _authGet(uri);

      if (response.statusCode != 200) {
        return _getFallbackNews();
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? news = data['news'] as List<dynamic>?;

      if (news == null || news.isEmpty) {
        return _getFallbackNews();
      }

      return news.take(15).map((dynamic item) {
        final Map<String, dynamic> n = item as Map<String, dynamic>;
        final int? publishTime = (n['providerPublishTime'] as num?)?.toInt();
        final DateTime published = publishTime != null
            ? DateTime.fromMillisecondsSinceEpoch(publishTime * 1000,
                    isUtc: true)
                .toLocal()
            : DateTime.now();

        return MarketNews(
          title: n['title'] as String? ?? 'Tin tức',
          source: n['publisher'] as String? ?? 'Yahoo Finance',
          publishedAt: published,
          url: n['link'] as String?,
        );
      }).toList();
    } catch (e) {
      _logger.warning('fetchMarketNews error: $e');
      return _getFallbackNews();
    }
  }

  List<MarketNews> _getFallbackNews() {
    return <MarketNews>[
      MarketNews(
        title: 'Đang cập nhật tin tức thị trường...',
        source: 'Hệ thống',
        publishedAt: DateTime.now(),
      ),
    ];
  }

  /// Fetch portfolio data (mock).
  Future<PortfolioSummary> fetchPortfolio() async {
    _logger.info('Fetching portfolio...');
    try {
      final List<Stock> trackedStocks = await fetchWatchlist();
      final List<PortfolioEntry> entries = <PortfolioEntry>[
        if (trackedStocks.isNotEmpty)
          PortfolioEntry(
            stock: trackedStocks[0],
            quantity: 120,
            averagePrice: trackedStocks[0].price * 0.95,
          ),
        if (trackedStocks.length > 1)
          PortfolioEntry(
            stock: trackedStocks[1],
            quantity: 80,
            averagePrice: trackedStocks[1].price * 1.05,
          ),
        if (trackedStocks.length > 2)
          PortfolioEntry(
            stock: trackedStocks[2],
            quantity: 150,
            averagePrice: trackedStocks[2].price * 0.9,
          ),
      ];
      _logger.info('Portfolio fetched: ${entries.length} entries');
      return PortfolioSummary(entries: entries);
    } catch (e, st) {
      _logger.error('Failed to fetch portfolio', e, st);
      rethrow;
    }
  }

  /// Fetch user profile (local mock).
  Future<UserProfile> fetchUserProfile() async {
    return const UserProfile(
      fullName: 'Nguyễn Văn A',
      email: 'vana@example.com',
      phone: '+84 912 345 678',
      receiveNotifications: true,
      preferredLanguage: 'vi',
      darkMode: false,
    );
  }

  /// Update user profile (local mock).
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    return profile;
  }
}
