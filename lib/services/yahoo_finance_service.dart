import 'dart:async'; // Thư viện xử lý bất đồng bộ (Future, Stream, Timer)
import 'dart:convert'; // Thư viện encode/decode JSON (jsonDecode, jsonEncode)
import 'dart:math'; // Thư viện toán học (dùng min() để giới hạn độ dài chuỗi log)

import 'package:http/http.dart' as http; // HTTP client để gọi REST API

import '../constants/stock_symbols.dart'; // Danh sách 30 mã chứng khoán mặc định
import '../models/market_index.dart'; // Model chỉ số thị trường (VN-Index, HNX)
import '../models/market_news.dart'; // Model tin tức tài chính
import '../models/portfolio.dart'; // Model danh mục đầu tư + tính lãi/lỗ
import '../models/stock.dart'; // Model mã cổ phiếu + giá thị trường
import '../models/stock_symbol_model.dart'; // Model mã CK từ API search
import '../models/user.dart'; // Model hồ sơ người dùng
import 'logger_service.dart'; // Service ghi log (wrapper Talker)

// =============================================================================
// _YahooAuthManager — Quản lý xác thực với Yahoo Finance
// =============================================================================
//
// Yahoo Finance API yêu cầu 2 thứ cho mỗi request:
//   1. Cookie: lấy từ fc.yahoo.com (hoặc login.yahoo.com)
//   2. Crumb: token ngăn chặn CSRF, lấy từ endpoint getcrumb
//
// Luồng xác thực:
//   Step 1: GET https://fc.yahoo.com → Set-Cookie header → lưu _cookie
//   Step 2: GET https://query2.../v1/test/getcrumb (với Cookie) → lưu _crumb
//   Step 3: Mọi API call sau: thêm Cookie vào Header + crumb vào query params
//
// TTL (Time-To-Live): 20 phút — sau đó tự xin lại cookie+crumb mới.
// Fallback: Nếu cả 2 cách trên lỗi → thử scrape crumb từ HTML Yahoo Finance page.
// =============================================================================

class _YahooAuthManager {
  /// [_client]: HTTP client để gửi request (được inject từ ngoài → dễ test mock)
  /// [_logger]: Logger service để ghi log xác thực
  _YahooAuthManager(this._client, this._logger);

  final http.Client _client;
  final LoggerService _logger;

  String? _crumb;      // Mã crumb ngắn (vd: "abc123xYz") — dùng như CSRF token
  String? _cookie;     // Cookie session từ Yahoo (vd: "A=...; B=...")
  DateTime? _lastAuth; // Thời điểm xác thực thành công gần nhất (dùng kiểm tra TTL)
  int _failCount = 0;  // Đếm số lần xác thực thất bại liên tiếp (tránh retry vô hạn)
  bool _isAuthenticating = false; // Mutex ngăn auth chạy đồng thời

  // TTL: cookie/crumb chỉ dùng được trong 20 phút, sau đó cần xin lại
  static const Duration _authTtl = Duration(minutes: 20);

  // User-Agent giả mạo Chrome trên Windows — Yahoo block request nếu không có UA
  static const String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

  /// Kiểm tra thông tin xác thực hiện tại còn hợp lệ không.
  /// Trả về false nếu thiếu cookie/crumb HOẶC đã quá TTL 20 phút.
  bool get _isValid =>
      _crumb != null &&
      _cookie != null &&
      _lastAuth != null &&
      DateTime.now().difference(_lastAuth!) < _authTtl;

  /// Trả về true nếu đã có đủ cookie + crumb (dù có thể đã hết hạn).
  bool get hasAuth => _crumb != null && _cookie != null;

  /// Đảm bảo thông tin xác thực hợp lệ trước khi gọi API.
  ///
  /// Nếu [force] = true → bỏ qua cache, bắt buộc xác thực lại (dùng khi nhận 401/403).
  /// Có cơ chế giới hạn: nếu đã thất bại > 3 lần → bỏ qua (tránh gửi request vô nghĩa).
  /// Cooldown 60 giây sau mỗi lần fail — tránh spam auth requests.
  Future<void> ensureAuth({bool force = false}) async {
    if (!force && _isValid) return; // Còn hợp lệ → dùng tiếp, không làm gì
    // Đã fail nhiều lần → không thử nữa (kể cả force)
    if (_failCount > 3) {
      // Cooldown: chỉ thử lại sau 60 giây kể từ lần auth cuối
      if (_lastAuth != null &&
          DateTime.now().difference(_lastAuth!) < const Duration(seconds: 60)) {
        _logger.warning('Yahoo Auth: Thất bại quá nhiều lần, bỏ qua bước xác thực');
        return;
      }
    }
    // Mutex: tránh nhiều request cùng trigger auth đồng thời
    if (_isAuthenticating) return;
    _isAuthenticating = true;
    try {
      await _authenticate();
    } finally {
      _isAuthenticating = false;
    }
  }

  /// Xóa thông tin xác thực hiện tại khỏi bộ nhớ.
  /// Gọi sau khi nhận HTTP 401/403 để buộc xin cookie+crumb mới ở lần sau.
  void invalidate() {
    _crumb = null;
    _cookie = null;
    _lastAuth = null;
  }

  /// Trả về crumb hiện tại (có thể null nếu chưa xác thực).
  String? get crumb => _crumb;

  /// Trả về HTTP headers chuẩn bao gồm User-Agent và Cookie (nếu có).
  /// Dùng làm headers cho mọi request đến Yahoo Finance.
  Map<String, String> get headers {
    final Map<String, String> h = <String, String>{
      'User-Agent': _userAgent,
      'Accept': 'application/json,text/html,application/xhtml+xml',
      'Accept-Language': 'en-US,en;q=0.9',
    };
    if (_cookie != null) {
      h['Cookie'] = _cookie!; // Thêm cookie vào header nếu đã có
    }
    return h;
  }

  /// Nối thêm query parameter `crumb` vào URI trước khi gửi request.
  ///
  /// Ví dụ: uri = https://query1.../v7/finance/quote?symbols=FPT.VN
  ///        → trả về: https://...?symbols=FPT.VN&crumb=abc123
  ///
  /// Lý do: Yahoo yêu cầu crumb như một phần của URL để xác minh session.
  Uri withCrumb(Uri uri) {
    if (_crumb == null) return uri; // Không có crumb → giữ nguyên URI
    final Map<String, dynamic> params = Map<String, dynamic>.from(uri.queryParameters);
    params['crumb'] = _crumb!;
    return uri.replace(queryParameters: params);
  }

  // ---------------------------------------------------------------------------
  // _authenticate() — Core: Thực hiện quy trình xin cookie + crumb
  // ---------------------------------------------------------------------------

  Future<void> _authenticate() async {
    try {
      _logger.info('Yahoo Auth: Bắt đầu tiến trình xác thực...');

      // ══════════════════════════════════════════════
      // CÁCH 1: fc.yahoo.com → getcrumb (Ổn định nhất)
      // ══════════════════════════════════════════════

      // Bước 1a: GET fc.yahoo.com để lấy cookie session từ Yahoo.
      // Lưu ý: fc.yahoo.com trả về HTTP 404 nhưng VẪN set-cookie trong header!
      // Đây là trick đã được cộng đồng discover khi reverse engineer Yahoo Finance.
      final http.Response cookieResponse = await _client.get(
        Uri.parse('https://fc.yahoo.com'),
        headers: <String, String>{'User-Agent': _userAgent},
      );

      String? cookie = _extractCookies(cookieResponse);
      _logger.debug(
          'Yahoo Auth: fc.yahoo.com status=${cookieResponse.statusCode}, '
          'cookie=${cookie != null ? "present" : "null"}');

      // Bước 1b: Nếu fc.yahoo.com không trả cookie → thử trang login Yahoo
      if (cookie == null || cookie.isEmpty) {
        final http.Response consentResponse = await _client.get(
          Uri.parse('https://login.yahoo.com/'),
          headers: <String, String>{'User-Agent': _userAgent},
        );
        cookie = _extractCookies(consentResponse);
        _logger.debug(
            'Yahoo Auth: login.yahoo.com status=${consentResponse.statusCode}, '
            'cookie=${cookie != null ? "present" : "null"}');
      }

      if (cookie != null && cookie.isNotEmpty) {
        _cookie = cookie;
      }

      // Bước 2: Dùng cookie vừa có để lấy crumb từ endpoint chính thức
      if (_cookie != null) {
        final http.Response crumbResponse = await _client.get(
          Uri.parse('https://query2.finance.yahoo.com/v1/test/getcrumb'),
          headers: headers, // headers đã có Cookie bên trong
        );

        _logger.debug(
            'Yahoo Auth: getcrumb status=${crumbResponse.statusCode}, '
            'body=${crumbResponse.body.length > 50 ? crumbResponse.body.substring(0, 50) : crumbResponse.body}');

        // Thành công: response là plaintext crumb (không phải HTML/JSON)
        if (crumbResponse.statusCode == 200 &&
            crumbResponse.body.isNotEmpty &&
            !crumbResponse.body.contains('<')) { // '<' = dấu hiệu trả về HTML lỗi
          _crumb = crumbResponse.body.trim();
          _lastAuth = DateTime.now();
          _failCount = 0; // Reset bộ đếm fail
          _logger.info(
              'Yahoo Auth: ✅ Authenticated '
              '(crumb=${_crumb!.substring(0, min(6, _crumb!.length))}...)');
          return; // Thành công → thoát
        }
      }

      // ══════════════════════════════════════════════
      // CÁCH 2: Scrape crumb từ HTML trang Yahoo Finance
      // ══════════════════════════════════════════════
      _logger.info('Yahoo Auth: Cách 1 thất bại, chuyển sang phương án bóc dữ liệu HTML...');
      final http.Response pageResponse = await _client.get(
        Uri.parse('https://finance.yahoo.com/quote/%5EGSPC/'),
        headers: <String, String>{'User-Agent': _userAgent},
      );

      // Cập nhật cookie từ trang này
      final String? pageCookie = _extractCookies(pageResponse);
      if (pageCookie != null && pageCookie.isNotEmpty) {
        _cookie = pageCookie;
      }

      // Tìm kiếm crumb trong HTML bằng Regex
      if (pageResponse.statusCode == 200) {
        final String body = pageResponse.body;
        String? extractedCrumb;

        // Pattern 1: Tìm "crumb":"xxxxx" trong embedded JS data
        final RegExp crumbPattern = RegExp(r'"crumb"\s*:\s*"([^"]+)"');
        final Match? match = crumbPattern.firstMatch(body);
        if (match != null) {
          extractedCrumb = match.group(1); // group(1) = capture group đầu tiên
        }

        // Pattern 2: Tìm kiểu CrumbStore cũ (Yahoo cũ dùng pattern này)
        if (extractedCrumb == null) {
          final RegExp crumbStorePattern =
              RegExp(r'"CrumbStore"\s*:\s*\{"crumb"\s*:\s*"([^"]+)"\}');
          final Match? storeMatch = crumbStorePattern.firstMatch(body);
          if (storeMatch != null) {
            extractedCrumb = storeMatch.group(1);
          }
        }

        if (extractedCrumb != null && extractedCrumb.isNotEmpty) {
          // Unescape unicode: crumb đôi khi chứa "\u002F" (mã hóa của "/")
          _crumb = extractedCrumb.replaceAll(r'\u002F', '/');
          _lastAuth = DateTime.now();
          _failCount = 0;
          _logger.info(
              'Yahoo Auth: ✅ Authenticated via HTML '
              '(crumb=${_crumb!.substring(0, min(6, _crumb!.length))}...)');
          return;
        }
      }

      // ══════════════════════════════════════════════
      // Xác thực thất bại hoàn toàn — tiếp tục không có crumb
      // ══════════════════════════════════════════════
      // Một số endpoint (đặc biệt v8/chart) đôi khi vẫn work không cần crumb.
      _failCount++;
      _lastAuth = DateTime.now(); // Lưu timestamp để tránh retry quá nhanh
      _logger.warning(
          'Yahoo Auth: ⚠️ Could not obtain crumb (fail #$_failCount). '
          'Will try requests without crumb.');
    } catch (e, st) {
      _failCount++;
      _lastAuth = DateTime.now();
      _logger.error('Yahoo Auth: ❌ Exception during auth (fail #$_failCount)', e, st);
    }
  }

  // ---------------------------------------------------------------------------
  // _extractCookies() — Parse Set-Cookie header từ HTTP response
  // ---------------------------------------------------------------------------

  /// Trích xuất và nối tất cả cookies từ header `Set-Cookie` thành 1 chuỗi.
  ///
  /// HTTP cho phép nhiều Set-Cookie headers (hoặc 1 header phân cách bởi dấu phẩy).
  /// Hàm này parse và chỉ lấy phần `name=value` (bỏ qua `Path=`, `Expires=`, v.v.).
  ///
  /// Ví dụ input: "A=abc; Path=/; HttpOnly, B=def; expires=Thu..."
  /// Ví dụ output: "A=abc; B=def"
  String? _extractCookies(http.Response response) {
    final String? setCookie = response.headers['set-cookie'];
    if (setCookie == null || setCookie.isEmpty) return null;

    final List<String> cookieParts = <String>[];
    // Regex: tách theo dấu phẩy KHÔNG phải giữa chừng giá trị (nhờ lookahead [^ ])
    for (final String part in setCookie.split(RegExp(r',(?=[^ ])'))) {
      final String trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      // Lấy phần trước dấu chấm phẩy đầu tiên (name=value; bỏ; Path=...)
      final int semiIdx = trimmed.indexOf(';');
      final String nameValue = semiIdx >= 0 ? trimmed.substring(0, semiIdx) : trimmed;
      if (nameValue.contains('=')) { // Chỉ lấy nếu có dấu = (là cookie hợp lệ)
        cookieParts.add(nameValue.trim());
      }
    }
    return cookieParts.isEmpty ? null : cookieParts.join('; ');
  }
}

// =============================================================================
// YahooFinanceService — Core Service: Giao tiếp với Yahoo Finance API
// =============================================================================
//
// THIẾT KẾ: Singleton Pattern
//   - Chỉ có 1 instance duy nhất toàn app (YahooFinanceService.instance)
//   - Private constructor `._internal()` ngăn tạo instance mới từ ngoài
//   - Dùng chung 1 http.Client → connection pool hiệu quả hơn
//
// CHIẾN LƯỢC FALLBACK 2 LỚP:
//   fetchQuotes() → _tryFetchQuotesV7() → nếu lỗi → _fetchQuotesViaChart()
//   fetchMarketIndices() → v7/quote → nếu lỗi → v8/chart → nếu lỗi → placeholder
// =============================================================================

/// Service chính xử lý toàn bộ giao tiếp với Yahoo Finance API.
///
/// Sử dụng Singleton Pattern để đảm bảo:
/// - 1 http.Client duy nhất (connection pooling)
/// - 1 AuthManager duy nhất (không xin cookie/crumb trùng lặp)
/// - 1 cache symbol duy nhất
///
/// Cách dùng: `YahooFinanceService.instance.fetchQuotes(['FPT', 'VNM'])`
class YahooFinanceService {
  /// Private constructor — chỉ gọi nội bộ khi khởi tạo static instance.
  /// [client] optional để inject mock trong unit test.
  YahooFinanceService._internal({http.Client? client})
      : _client = client ?? http.Client() {
    _auth = _YahooAuthManager(_client, _logger);
  }

  /// Singleton instance — khởi tạo 1 lần, dùng suốt vòng đời app.
  static final YahooFinanceService instance = YahooFinanceService._internal();

  final http.Client _client;
  final LoggerService _logger = LoggerService();
  late final _YahooAuthManager _auth; // `late` vì gán trong constructor body

  // Cache danh sách tất cả symbol VN — tránh fetch lại nhiều lần
  List<StockSymbolModel>? _cachedSymbols;

  // Circuit breaker: bỏ qua v7/quote nếu đã fail liên tiếp
  int _v7FailCount = 0;
  DateTime? _v7LastFail;

  // ===========================================================================
  // Helper Methods (dùng nội bộ)
  // ===========================================================================

  /// Chuyển đổi mã cổ phiếu display sang định dạng Yahoo Finance API.
  ///
  /// Yahoo Finance VN dùng hậu tố `.VN`: "FPT" → "FPT.VN"
  /// Chỉ số thị trường giữ nguyên: "^VNINDEX" → "^VNINDEX"
  String toYahooSymbol(String symbol) {
    final String upper = symbol.toUpperCase().trim();
    if (upper.startsWith('^')) return upper;   // Chỉ số: giữ nguyên
    if (upper.endsWith('.VN')) return upper;   // Đã có hậu tố: giữ nguyên
    return '$upper.VN';                        // Thêm hậu tố .VN
  }

  /// Gửi GET request với xác thực Yahoo tự động.
  ///
  /// Tự động:
  /// 1. Gọi `ensureAuth()` để đảm bảo cookie/crumb còn hạn
  /// 2. Gắn crumb vào URL query params
  /// 3. Gắn cookie vào headers
  /// 4. Nếu nhận 401/403 → invalidate auth → xin lại → retry 1 lần (có giới hạn)
  Future<http.Response> _authGet(Uri uri) async {
    await _auth.ensureAuth(); // Đảm bảo đã xác thực

    // Thêm crumb vào URI nếu có (vd: ?symbols=FPT.VN → ?symbols=FPT.VN&crumb=...)
    final Uri requestUri = _auth.withCrumb(uri);

    _logger.logApiCall('GET', requestUri.toString());
    http.Response response = await _client.get(requestUri, headers: _auth.headers);
    _logger.logApiResponse(requestUri.toString(),
        statusCode: response.statusCode, body: '(${response.body.length} bytes)');

    // Xác thực hết hạn giữa chừng → xin lại và thử lại 1 lần
    // Chỉ retry nếu auth chưa fail quá nhiều (tránh vòng lặp vô tận)
    if ((response.statusCode == 401 || response.statusCode == 403) && _auth.hasAuth) {
      _logger.warning('Yahoo: Got ${response.statusCode}, re-authenticating...');
      _auth.invalidate();               // Xóa auth cũ
      await _auth.ensureAuth(force: true); // Bắt buộc xin lại

      // Chỉ retry nếu auth thành công (có crumb mới)
      if (_auth.crumb != null) {
        final Uri retryUri = _auth.withCrumb(uri); // URI mới với crumb mới
        response = await _client.get(retryUri, headers: _auth.headers);
        _logger.logApiResponse(retryUri.toString(),
            statusCode: response.statusCode, body: '(${response.body.length} bytes)');
      }
    }

    return response;
  }

  /// Wrapper generic thử lại [fn] tối đa [maxAttempts] lần.
  ///
  /// Mỗi lần thất bại chờ thêm (800ms * số lần thất bại) trước khi retry.
  /// Gọi là "linear backoff" (khác exponential backoff nhân đôi mỗi lần).
  ///
  /// Ví dụ: maxAttempts=2, fail lần 1 → chờ 800ms → thử lần 2 → throw
  Future<T> _retry<T>(
    Future<T> Function() fn, {
    int maxAttempts = 2,
    String? label, // Nhãn để log (vd: "fetchChart(FPT, 1d)")
  }) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await fn();
      } catch (e, st) {
        if (attempt >= maxAttempts) {
          _logger.error('[$label] Failed after $attempt attempts', e, st);
          rethrow; // Hết lần thử → ném lỗi ra ngoài
        }
        _logger.warning('[$label] Attempt $attempt failed, retrying...');
        await Future<void>.delayed(Duration(milliseconds: 800 * attempt));
      }
    }
    throw StateError('Unreachable'); // Compiler cần dòng này dù không bao giờ chạy
  }

  // ===========================================================================
  // Public API — Lấy dữ liệu thị trường
  // ===========================================================================

  /// Lấy giá và thông tin thị trường của nhiều mã cổ phiếu cùng lúc.
  ///
  /// Chiến lược:
  /// 1. Thử `v7/finance/quote` (endpoint chính thức, đầy đủ fields) — bỏ qua nếu circuit breaker mở
  /// 2. Fallback sang `v8/finance/chart` (ít bị chặn auth hơn, chạy song song)
  ///
  /// [symbols]: danh sách mã display (vd: ['FPT', 'VNM', 'VCB'])
  Future<List<Stock>> fetchQuotes(List<String> symbols) async {
    if (symbols.isEmpty) return <Stock>[];

    // Circuit breaker: bỏ qua v7 nếu đã fail >= 2 lần trong 5 phút gần đây
    final bool skipV7 = _v7FailCount >= 2 &&
        _v7LastFail != null &&
        DateTime.now().difference(_v7LastFail!) < const Duration(minutes: 5);

    if (!skipV7) {
      // Thử endpoint v7 trước
      final List<Stock>? v7Result = await _tryFetchQuotesV7(symbols);
      if (v7Result != null && v7Result.isNotEmpty) {
        _v7FailCount = 0; // Reset circuit breaker khi thành công
        return v7Result;
      }
      // v7 thất bại → tăng counter
      _v7FailCount++;
      _v7LastFail = DateTime.now();
    }

    // Fallback sang v8/chart nếu v7 lỗi hoặc bị bỏ qua
    if (skipV7) {
      _logger.info('fetchQuotes: v7 circuit breaker mở, dùng thẳng v8/chart...');
    } else {
      _logger.info('fetchQuotes: v7 lỗi, quay số với endpoint dự phòng v8/chart...');
    }
    return _fetchQuotesViaChart(symbols);
  }

  /// Thử lấy quotes qua endpoint chính `v7/finance/quote`.
  ///
  /// Trả về null nếu thất bại (để caller biết cần chuyển fallback).
  /// Trả về List<Stock> rỗng nếu không có kết quả.
  ///
  /// Cấu trúc JSON trả về:
  /// ```json
  /// {
  ///   "quoteResponse": {
  ///     "result": [
  ///       {
  ///         "symbol": "FPT.VN",
  ///         "longName": "FPT Corporation",
  ///         "regularMarketPrice": 125000,
  ///         "regularMarketChangePercent": 1.23,
  ///         ...
  ///       }
  ///     ]
  ///   }
  /// }
  /// ```
  Future<List<Stock>?> _tryFetchQuotesV7(List<String> symbols) async {
    try {
      // Nối các symbol thành chuỗi: "FPT.VN,VNM.VN,VCB.VN"
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
        return null; // Không thành công → signal fallback
      }

      // Parse JSON: jsonDecode trả về dynamic, cast sang Map an toàn
      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      // Drill down: data → quoteResponse → result → List<Map>
      final Map<String, dynamic>? quoteResponse =
          data['quoteResponse'] as Map<String, dynamic>?;
      if (quoteResponse == null) return null;

      final List<dynamic>? results = quoteResponse['result'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      // Map mỗi item JSON → đối tượng Stock
      return results.map((dynamic item) {
        final Map<String, dynamic> q = item as Map<String, dynamic>;
        // "FPT.VN" → "FPT" để hiển thị trên UI
        final String rawSymbol = (q['symbol'] as String? ?? '');
        final String displaySymbol = rawSymbol.replaceAll('.VN', '').toUpperCase();

        return Stock(
          symbol: displaySymbol,
          name: q['longName'] as String? ?? q['shortName'] as String? ?? displaySymbol,
          // as num? → an toàn với cả int và double từ JSON
          // ?.toDouble() → null-safe convert
          price: (q['regularMarketPrice'] as num?)?.toDouble() ?? 0,
          changePercent: (q['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
          volume: (q['regularMarketVolume'] as num?)?.toInt() ?? 0,
          apiSymbol: rawSymbol,
          dayHigh: (q['regularMarketDayHigh'] as num?)?.toDouble(),
          dayLow: (q['regularMarketDayLow'] as num?)?.toDouble(),
          open: (q['regularMarketOpen'] as num?)?.toDouble(),
          previousClose: (q['regularMarketPreviousClose'] as num?)?.toDouble(),
          marketCap: (q['marketCap'] as num?)?.toDouble(),
        );
      }).toList();
    } catch (e) {
      _logger.warning('v7/quote exception: $e');
      return null; // Exception → signal fallback
    }
  }

  /// Fallback: Lấy giá cổ phiếu qua endpoint `v8/finance/chart`.
  ///
  /// Chạy SONG SONG (Future.wait) thay vì tuần tự → nhanh hơn nhiều.
  /// Giới hạn đồng thời 5 request để không bị rate-limit.
  /// endpoint chart ít bị Yahoo block auth hơn endpoint v7/quote.
  ///
  /// Lấy giá từ field `meta` trong response chart:
  /// ```json
  /// { "chart": { "result": [{ "meta": { "regularMarketPrice": 125000 } }] } }
  /// ```
  Future<List<Stock>> _fetchQuotesViaChart(List<String> symbols) async {
    final List<Stock> stocks = <Stock>[];

    // Chia thành batch nhỏ (5 mã/batch) để tránh rate-limit
    const int batchSize = 5;
    for (int batchStart = 0; batchStart < symbols.length; batchStart += batchSize) {
      final List<String> batch = symbols.skip(batchStart).take(batchSize).toList();

      // Chạy song song trong mỗi batch
      final List<Stock?> batchResults = await Future.wait(
        batch.map((String symbol) => _fetchSingleChartQuote(symbol)),
      );

      // Lọc null (mã lỗi) và thêm vào danh sách
      for (final Stock? stock in batchResults) {
        if (stock != null) stocks.add(stock);
      }
    }

    return stocks;
  }

  /// Lấy giá 1 mã cổ phiếu từ v8/chart. Trả về null nếu lỗi.
  Future<Stock?> _fetchSingleChartQuote(String symbol) async {
    try {
      final String yahooSymbol = toYahooSymbol(symbol);
      // range=1d&interval=1d: chỉ lấy 1 nến ngày hôm nay (tối thiểu data)
      final Uri uri = Uri.parse(
        'https://query1.finance.yahoo.com/v8/finance/chart/$yahooSymbol'
        '?range=1d&interval=1d&includePrePost=false',
      );

      final http.Response response = await _authGet(uri);
      if (response.statusCode != 200) return null; // Bỏ qua mã lỗi

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      // Chuỗi drill-down: data → chart → result → [0]
      final List<dynamic>? results =
          (data['chart'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final Map<String, dynamic> result = results.first as Map<String, dynamic>;
      final Map<String, dynamic>? meta = result['meta'] as Map<String, dynamic>?;
      if (meta == null) return null;

      final double price = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0;
      // chartPreviousClose ưu tiên hơn previousClose (Yahoo dùng tên khác nhau)
      final double prevClose = (meta['chartPreviousClose'] as num?)?.toDouble() ??
          (meta['previousClose'] as num?)?.toDouble() ??
          price; // Fallback = bằng giá hiện tại (change = 0%)
      // Tính % thay đổi thủ công: ((giá mới - giá cũ) / giá cũ * 100)
      final double changePercent = prevClose != 0 ? ((price - prevClose) / prevClose * 100) : 0;

      final String displaySymbol = symbol.toUpperCase().replaceAll('.VN', '');

      // Lấy volume từ cấu trúc indicators.quote[0].volume (phức tạp hơn)
      int volume = 0;
      final Map<String, dynamic>? indicators = result['indicators'] as Map<String, dynamic>?;
      final List<dynamic>? quoteList = indicators?['quote'] as List<dynamic>?;
      if (quoteList != null && quoteList.isNotEmpty) {
        final Map<String, dynamic> quote = quoteList.first as Map<String, dynamic>;
        final List<dynamic>? volumes = quote['volume'] as List<dynamic>?;
        if (volumes != null && volumes.isNotEmpty) {
          volume = (volumes.last as num?)?.toInt() ?? 0; // `.last` = nến gần nhất
        }
      }

      // Tìm tên công ty từ constants (Yahoo đôi khi trả về tên tiếng Anh đơn giản)
      final StockSymbol? knownSymbol = kStockSymbolLookup[displaySymbol];

      return Stock(
        symbol: displaySymbol,
        name: knownSymbol?.companyName ?? meta['shortName'] as String? ?? displaySymbol,
        price: price,
        changePercent: changePercent,
        volume: volume,
        apiSymbol: yahooSymbol,
        previousClose: prevClose,
        dayHigh: (meta['regularMarketDayHigh'] as num?)?.toDouble(),
        dayLow: (meta['regularMarketDayLow'] as num?)?.toDouble(),
      );
    } catch (e) {
      _logger.warning('v8/chart fallback failed for $symbol: $e');
      return null;
    }
  }

  /// Shortcut: Lấy thông tin 1 mã cổ phiếu duy nhất.
  ///
  /// Đơn giản là gói [fetchQuotes] với list 1 phần tử.
  Future<Stock?> fetchSingleQuote(String symbol) async {
    final List<Stock> results = await fetchQuotes(<String>[symbol]);
    return results.isNotEmpty ? results.first : null;
  }

  /// Lấy dữ liệu chỉ số thị trường: VN-Index (^VNINDEX) và HNX (^HNXI).
  ///
  /// Chiến lược 3 lớp:
  /// 1. v7/quote (batch) → nhanh, đầy đủ
  /// 2. v8/chart (từng chỉ số) → chậm hơn nhưng ít bị chặn
  /// 3. Placeholder 0 → tránh crash UI khi cả 2 cách đều lỗi
  Future<List<MarketIndex>> fetchMarketIndices() async {
    // Cấu hình 2 chỉ số cần lấy
    // chartSymbol: dùng cho v8/chart (URL-encoded, không có ^)
    final List<Map<String, String>> indexConfigs = <Map<String, String>>[
      <String, String>{'symbol': '^VNINDEX', 'name': 'VN-Index', 'chartSymbol': '%5EVNINDEX'},
      <String, String>{'symbol': '^HNXI', 'name': 'HNX', 'chartSymbol': '%5EHNXI'},
    ];

    final List<MarketIndex> results = <MarketIndex>[];

    // Circuit breaker: bỏ qua v7 nếu đã fail nhiều lần gần đây
    final bool skipV7 = _v7FailCount >= 2 &&
        _v7LastFail != null &&
        DateTime.now().difference(_v7LastFail!) < const Duration(minutes: 5);

    // Cách 1: v7/quote batch request cho tất cả chỉ số
    if (!skipV7) {
      try {
        final String symbols = indexConfigs.map((Map<String, String> c) => c['symbol']!).join(',');

        final Uri uri = Uri.parse(
          'https://query1.finance.yahoo.com/v7/finance/quote'
          '?symbols=$symbols'
          '&fields=symbol,regularMarketPrice,regularMarketChangePercent,'
          'regularMarketPreviousClose,regularMarketChange',
        );

        final http.Response response = await _authGet(uri);

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
          final List<dynamic>? quotes =
              (data['quoteResponse'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;

          if (quotes != null && quotes.isNotEmpty) {
            for (final Map<String, String> config in indexConfigs) {
              // Tìm quote khớp symbol trong result list
              final Map<String, dynamic>? q = _findQuoteBySymbol(quotes, config['symbol']!);

              if (q != null) {
                results.add(MarketIndex(
                  name: config['name']!,
                  value: (q['regularMarketPrice'] as num?)?.toDouble() ?? 0,
                  changePercent: (q['regularMarketChangePercent'] as num?)?.toDouble() ?? 0,
                  previousClose: (q['regularMarketPreviousClose'] as num?)?.toDouble(),
                  change: (q['regularMarketChange'] as num?)?.toDouble(),
                ));
              }
            }

            if (results.isNotEmpty) return results; // Thành công → trả về
          }
        }
      } catch (e) {
        _logger.warning('v7/quote for indices failed: $e');
      }
    }

    // Cách 2: Gọi v8/chart song song cho tất cả chỉ số
    // Dùng Uri.parse đúng cách để tránh lỗi encoding ký tự ^
    final List<MarketIndex?> chartResults = await Future.wait(
      indexConfigs.map((Map<String, String> config) async {
        try {
          // Dùng URL đã encode sẵn: %5E thay cho ^
          final Uri uri = Uri.parse(
            'https://query1.finance.yahoo.com/v8/finance/chart/${config['chartSymbol']}'
            '?range=1d&interval=1d&includePrePost=false',
          );

          final http.Response response = await _authGet(uri);

          if (response.statusCode == 200) {
            final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
            final List<dynamic>? results =
                (data['chart'] as Map<String, dynamic>?)?['result'] as List<dynamic>?;

            if (results != null && results.isNotEmpty) {
              final Map<String, dynamic> meta =
                  (results.first as Map<String, dynamic>)['meta'] as Map<String, dynamic>;
              final double price = (meta['regularMarketPrice'] as num?)?.toDouble() ?? 0;
              final double prevClose =
                  (meta['chartPreviousClose'] as num?)?.toDouble() ??
                  (meta['previousClose'] as num?)?.toDouble() ??
                  price;
              final double changePct = prevClose != 0 ? ((price - prevClose) / prevClose * 100) : 0;

              return MarketIndex(
                name: config['name']!,
                value: price,
                changePercent: changePct,
                previousClose: prevClose,
                change: price - prevClose,
              );
            }
          }
        } catch (e) {
          _logger.warning('v8/chart for index ${config['symbol']} failed: $e');
        }
        return null;
      }),
    );

    // Gộp kết quả, dùng placeholder nếu chart cũng lỗi
    for (int i = 0; i < indexConfigs.length; i++) {
      if (chartResults[i] != null) {
        results.add(chartResults[i]!);
      } else {
        results.add(MarketIndex(
          name: indexConfigs[i]['name']!,
          value: 0,
          changePercent: 0,
        ));
      }
    }

    return results;
  }

  /// Tìm 1 quote object trong list result theo symbol chính xác.
  Map<String, dynamic>? _findQuoteBySymbol(List<dynamic> quotes, String symbol) {
    for (final dynamic item in quotes) {
      final Map<String, dynamic> q = item as Map<String, dynamic>;
      if (q['symbol'] == symbol) return q;
    }
    return null;
  }

  /// Lấy danh sách giá của các mã trong Watchlist.
  ///
  /// Chia nhỏ request thành chunks 15 mã mỗi lần vì Yahoo có giới hạn
  /// số symbols tối đa trong 1 request URL.
  ///
  /// Ưu tiên [symbolModels] → [symbols] → danh sách mặc định [kTrackedStockSymbols].
  Future<List<Stock>> fetchWatchlist({
    List<StockSymbol>? symbols,         // Từ constants/hardcoded
    List<StockSymbolModel>? symbolModels, // Từ API search
  }) async {
    final List<String> displaySymbols;

    // Ưu tiên: symbolModels > symbols > default constants
    if (symbolModels != null && symbolModels.isNotEmpty) {
      displaySymbols = symbolModels.map((StockSymbolModel s) => s.displaySymbol).toList();
    } else if (symbols != null && symbols.isNotEmpty) {
      displaySymbols = symbols.map((StockSymbol s) => s.displaySymbol).toList();
    } else {
      displaySymbols = kTrackedStockSymbols.map((StockSymbol s) => s.displaySymbol).toList();
    }

    final List<Stock> allStocks = <Stock>[];
    const int chunkSize = 15; // Yahoo an toàn với <= 15 symbols/request

    // Duyệt qua từng chunk
    for (int i = 0; i < displaySymbols.length; i += chunkSize) {
      // skip(i): bỏ qua i phần tử đầu; take(chunkSize): lấy tối đa chunkSize
      final List<String> chunk = displaySymbols.skip(i).take(chunkSize).toList();
      try {
        final List<Stock> stocks = await fetchQuotes(chunk);
        allStocks.addAll(stocks);
      } catch (e) {
        _logger.warning('Failed to fetch chunk starting at $i: $e');
      }
    }

    return allStocks;
  }

  /// Lấy data biểu đồ giá của 1 mã cổ phiếu.
  ///
  /// [range]: khoảng thời gian ("1d", "5d", "1mo", "3mo", "1y", "5y")
  /// [interval]: độ rộng mỗi nến ("1m", "5m", "30m", "1h", "1d")
  ///
  /// Dùng [_retry] để tự động thử lại nếu network bất ổn.
  Future<List<StockPricePoint>> fetchChart(
    String displaySymbol, {
    String? apiSymbol, // Nếu không truyền → tự tính bằng toYahooSymbol()
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
        return <StockPricePoint>[]; // Trả về rỗng thay vì throw → UI xử lý gracefully
      }

      // useDateLabel: nếu không phải 1d → dùng nhãn ngày/tháng thay vì giờ:phút
      return _parseChartResponse(response.body, useDateLabel: range != '1d');
    }, label: 'fetchChart($displaySymbol, $range)');
  }

  /// Shortcut: Lấy biểu đồ trong ngày (Intraday) với nến 30 phút.
  ///
  /// Dùng cho: MiniSparkline, StockDetailScreen (tab 1D)
  Future<List<StockPricePoint>> fetchIntradayPrices(
    String displaySymbol, {
    String? apiSymbol,
  }) async {
    return fetchChart(displaySymbol, apiSymbol: apiSymbol, range: '1d', interval: '30m');
  }

  /// Shortcut: Lấy biểu đồ lịch sử 1 tháng (mỗi nến = 1 ngày).
  ///
  /// Dùng cho: StockDetailScreen (tab 1M)
  Future<List<StockPricePoint>> fetchHistoricalPrices(
    String displaySymbol, {
    String? apiSymbol,
  }) async {
    return fetchChart(displaySymbol, apiSymbol: apiSymbol, range: '1mo', interval: '1d');
  }

  // ---------------------------------------------------------------------------
  // _parseChartResponse() — Parser JSON biểu đồ Yahoo Finance
  // ---------------------------------------------------------------------------

  /// Phân tích cú pháp (parse) response JSON từ endpoint `v8/finance/chart`.
  ///
  /// Cấu trúc JSON Yahoo Finance chart:
  /// ```json
  /// {
  ///   "chart": {
  ///     "result": [{
  ///       "timestamp": [1714000000, 1714001800, ...],  // Unix timestamp (giây)
  ///       "indicators": {
  ///         "quote": [{
  ///           "close": [125000, 125200, null, 124800, ...] // null nếu chưa có nến
  ///         }]
  ///       }
  ///     }]
  ///   }
  /// }
  /// ```
  ///
  /// [useDateLabel]: true → nhãn "DD/MM", false → nhãn "HH:mm"
  List<StockPricePoint> _parseChartResponse(String body, {required bool useDateLabel}) {
    try {
      final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
      final Map<String, dynamic>? chart = data['chart'] as Map<String, dynamic>?;
      final List<dynamic>? results = chart?['result'] as List<dynamic>?;

      if (results == null || results.isEmpty) return <StockPricePoint>[];

      final Map<String, dynamic> result = results.first as Map<String, dynamic>;
      // timestamps: list Unix timestamp (giây kể từ epoch 1970)
      final List<dynamic>? timestamps = result['timestamp'] as List<dynamic>?;
      final Map<String, dynamic>? indicators = result['indicators'] as Map<String, dynamic>?;
      // quoteList có thể có nhiều phần tử nhưng thường chỉ 1
      final List<dynamic>? quoteList = indicators?['quote'] as List<dynamic>?;

      if (timestamps == null || quoteList == null || quoteList.isEmpty) {
        return <StockPricePoint>[];
      }

      final Map<String, dynamic> quote = quoteList.first as Map<String, dynamic>;
      // close: giá đóng cửa mỗi nến (có thể null nếu nến chưa đóng/dữ liệu thiếu)
      final List<dynamic>? closes = quote['close'] as List<dynamic>?;
      if (closes == null) return <StockPricePoint>[];

      // An toàn với length không khớp giữa timestamps và closes
      final int length = timestamps.length < closes.length ? timestamps.length : closes.length;
      final List<StockPricePoint> points = <StockPricePoint>[];

      for (int i = 0; i < length; i++) {
        final num? closePrice = closes[i] as num?;
        if (closePrice == null) continue; // Bỏ qua nến thiếu dữ liệu

        // Chuyển Unix timestamp (giây) → DateTime → local timezone
        final int timestamp = (timestamps[i] as num).toInt();
        final DateTime time = DateTime.fromMillisecondsSinceEpoch(
          timestamp * 1000, // Nhân 1000: từ giây → milliseconds
          isUtc: true,       // UTC → sau đó toLocal()
        ).toLocal();

        // Định dạng nhãn thời gian:
        // padLeft(2, '0'): đảm bảo "9" → "09" (2 chữ số)
        final String label = useDateLabel
            ? '${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}'
            : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        points.add(StockPricePoint(timeLabel: label, price: closePrice.toDouble()));
      }

      return points;
    } catch (e, st) {
      _logger.error('Failed to parse chart response', e, st);
      return <StockPricePoint>[]; // Trả về rỗng thay vì crash
    }
  }

  // ===========================================================================
  // Symbol Search & Catalog
  // ===========================================================================

  /// Tìm kiếm mã cổ phiếu theo từ khóa qua Yahoo Finance Search API.
  ///
  /// Lọc kết quả chỉ lấy mã Việt Nam (.VN) hoặc chỉ số VN (^VN*).
  ///
  /// [query]: từ khóa tìm (mã hoặc tên công ty, vd: "FPT", "Vingroup")
  Future<List<StockSymbolModel>> searchSymbols(String query) async {
    if (query.trim().isEmpty) return <StockSymbolModel>[];

    try {
      // quotesCount=20: tối đa 20 kết quả; newsCount=0: không lấy tin tức
      final Uri uri = Uri.parse(
        'https://query2.finance.yahoo.com/v1/finance/search'
        '?q=${Uri.encodeComponent(query)}' // Encode đặc biệt: "FPT Corp" → "FPT%20Corp"
        '&quotesCount=20&newsCount=0&listsCount=0'
        '&quotesQueryId=tss_match_phrase_query',
      );

      final http.Response response = await _authGet(uri);
      if (response.statusCode != 200) return <StockSymbolModel>[];

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? quotes = data['quotes'] as List<dynamic>?;
      if (quotes == null) return <StockSymbolModel>[];

      return quotes
          .where((dynamic item) {
            // Chỉ lấy mã VN: kết thúc .VN hoặc bắt đầu ^VN
            final Map<String, dynamic> q = item as Map<String, dynamic>;
            final String symbol = q['symbol'] as String? ?? '';
            return symbol.endsWith('.VN') || symbol.startsWith('^VN');
          })
          .map((dynamic item) {
            final Map<String, dynamic> q = item as Map<String, dynamic>;
            final String rawSymbol = q['symbol'] as String? ?? '';
            final String displaySymbol = rawSymbol.replaceAll('.VN', '').toUpperCase();

            return StockSymbolModel(
              displaySymbol: displaySymbol,
              apiSymbol: rawSymbol,
              // Ưu tiên tên đầy đủ (longname) → tên ngắn (shortname) → mã
              companyName: q['longname'] as String? ?? q['shortname'] as String? ?? displaySymbol,
              exchange: q['exchange'] as String? ?? 'VN',
            );
          })
          .toList();
    } catch (e) {
      _logger.warning('searchSymbols error: $e');
      return <StockSymbolModel>[];
    }
  }

  /// Tải toàn bộ danh mục mã chứng khoán Việt Nam.
  ///
  /// Chiến lược:
  /// 1. Trả về cache nếu đã có (tránh fetch lại nhiều lần)
  /// 2. Bắt đầu từ danh sách hardcoded 30 mã trong constants
  /// 3. Enrich (bổ sung) bằng cách search "VN stock" trên Yahoo
  /// 4. Sắp xếp alphabetical và cache lại
  Future<List<StockSymbolModel>> fetchAllVietnamSymbols() async {
    // Trả về cache nếu có
    if (_cachedSymbols != null && _cachedSymbols!.isNotEmpty) {
      return _cachedSymbols!;
    }

    // Bắt đầu từ danh sách hardcoded 30 mã trong constants
    final List<StockSymbolModel> symbols = kTrackedStockSymbols
        .map((StockSymbol s) => StockSymbolModel(
              displaySymbol: s.displaySymbol,
              apiSymbol: '${s.displaySymbol}.VN',
              companyName: s.companyName,
              exchange: s.exchange,
            ))
        .toList();

    // Thêm mã từ Yahoo Search API (nếu có)
    try {
      final List<StockSymbolModel> searched = await searchSymbols('VN stock');
      final Set<String> existing = symbols.map((StockSymbolModel s) => s.displaySymbol).toSet();
      for (final StockSymbolModel s in searched) {
        if (!existing.contains(s.displaySymbol)) {
          symbols.add(s);
          existing.add(s.displaySymbol); // Tránh trùng trong cùng vòng lặp
        }
      }
    } catch (e) {
      _logger.warning('Failed to enrich symbol list: $e');
    }

    // Sắp xếp alphabetical để dễ tìm kiếm
    symbols.sort((StockSymbolModel a, StockSymbolModel b) =>
        a.displaySymbol.compareTo(b.displaySymbol));

    _cachedSymbols = symbols; // Lưu cache
    return symbols;
  }

  /// Xóa cache và load lại danh sách mã (force refresh).
  Future<List<StockSymbolModel>> refreshSymbols() async {
    _cachedSymbols = null; // Xóa cache
    return fetchAllVietnamSymbols(); // Load lại từ đầu
  }

  // ===========================================================================
  // News, Portfolio, User Profile
  // ===========================================================================

  /// Lấy tin tức thị trường chứng khoán Việt Nam từ Yahoo Finance Search.
  ///
  /// Dùng endpoint search với keyword "Vietnam stock market" nhưng chỉ lấy news
  /// (newsCount=15, quotesCount=0).
  ///
  /// Fallback: Nếu API lỗi → trả về 1 placeholder "Đang cập nhật..."
  Future<List<MarketNews>> fetchMarketNews() async {
    try {
      final Uri uri = Uri.parse(
        'https://query2.finance.yahoo.com/v1/finance/search'
        '?q=Vietnam%20stock%20market'
        '&quotesCount=0&newsCount=15&listsCount=0',
      );

      final http.Response response = await _authGet(uri);
      if (response.statusCode != 200) return _getFallbackNews();

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      final List<dynamic>? news = data['news'] as List<dynamic>?;
      if (news == null || news.isEmpty) return _getFallbackNews();

      return news.take(15).map((dynamic item) {
        final Map<String, dynamic> n = item as Map<String, dynamic>;
        // providerPublishTime: Unix timestamp (giây) thời điểm đăng bài
        final int? publishTime = (n['providerPublishTime'] as num?)?.toInt();
        final DateTime published = publishTime != null
            ? DateTime.fromMillisecondsSinceEpoch(publishTime * 1000, isUtc: true).toLocal()
            : DateTime.now(); // Fallback = thời gian hiện tại

        return MarketNews(
          title: n['title'] as String? ?? 'Tin tức',
          source: n['publisher'] as String? ?? 'Yahoo Finance',
          publishedAt: published,
          url: n['link'] as String?, // Link đến bài báo gốc
        );
      }).toList();
    } catch (e) {
      _logger.warning('fetchMarketNews error: $e');
      return _getFallbackNews();
    }
  }

  /// Trả về tin tức placeholder khi không fetch được từ API.
  List<MarketNews> _getFallbackNews() {
    return <MarketNews>[
      MarketNews(
        title: 'Đang cập nhật tin tức thị trường...',
        source: 'Hệ thống',
        publishedAt: DateTime.now(),
      ),
    ];
  }

  /// Lấy danh mục đầu tư của người dùng.
  ///
  /// **HIỆN TẠI: Đây là MOCK DATA** — Giả lập 3 mã đầu tiên trong watchlist
  /// với khối lượng và giá vốn cố định.
  ///
  /// TODO: Thay bằng API backend hoặc local database khi có tính năng thêm giao dịch.
  Future<PortfolioSummary> fetchPortfolio() async {
    _logger.info('Fetching portfolio...');
    try {
      // Dùng fetchWatchlist để lấy giá thực → tính lãi/lỗ có ý nghĩa hơn
      final List<Stock> trackedStocks = await fetchWatchlist();
      final List<PortfolioEntry> entries = <PortfolioEntry>[
        // Mã 1: Mua 120 cổ phiếu với giá = 95% giá thị trường (đang lãi ~5%)
        if (trackedStocks.isNotEmpty)
          PortfolioEntry(
            stock: trackedStocks[0],
            quantity: 120,
            averagePrice: trackedStocks[0].price * 0.95,
          ),
        // Mã 2: Mua 80 cổ phiếu với giá = 105% giá thị trường (đang lỗ ~5%)
        if (trackedStocks.length > 1)
          PortfolioEntry(
            stock: trackedStocks[1],
            quantity: 80,
            averagePrice: trackedStocks[1].price * 1.05,
          ),
        // Mã 3: Mua 150 cổ phiếu với giá = 90% giá thị trường (đang lãi ~10%)
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

  /// Lấy hồ sơ người dùng.
  ///
  /// **HIỆN TẠI: MOCK DATA** — Trả về dữ liệu cứng.
  /// TODO: Kết nối với authentication backend (Firebase Auth, REST API).
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

  /// Lưu thay đổi hồ sơ người dùng.
  ///
  /// **HIỆN TẠI: MOCK** — Echo lại profile nhận vào (không lưu thật).
  /// TODO: POST/PATCH lên backend API.
  Future<UserProfile> updateUserProfile(UserProfile profile) async {
    return profile; // Mock: trả về y chang những gì nhận vào
  }
}
