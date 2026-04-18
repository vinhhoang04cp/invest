import 'dart:async'; // Future, unawaited()

import 'package:flutter/foundation.dart'; // ChangeNotifier, debugPrint
import 'package:shared_preferences/shared_preferences.dart'; // Persistent local storage

import '../constants/stock_symbols.dart'; // Danh sách 30 mã mặc định
import '../models/stock_symbol_model.dart'; // Model mã CK từ API
import '../services/yahoo_finance_service.dart'; // Gọi API

// =============================================================================
// WatchlistProvider — State Management cho danh sách theo dõi
// =============================================================================
//
// PATTERN: ChangeNotifier + Provider
//
// ChangeNotifier cung cấp cơ chế pub/sub đơn giản:
//   - Gọi notifyListeners() → tất cả widget đang lắng nghe sẽ rebuild
//   - Widget lắng nghe: Provider.of<WatchlistProvider>(context) hoặc Consumer<>
//
// LIFECYCLE:
//   1. AppBootstrap tạo 1 instance WatchlistProvider
//   2. Constructor gọi _initialize() không đồng bộ (unawaited)
//   3. _initialize() load data từ SharedPreferences + Yahoo API
//   4. isLoading = false → notifyListeners() → UI rebuild
//   5. Các thao tác add/remove/reorder → lưu SharedPreferences → notifyListeners()
//
// PERSISTENT STORAGE:
//   Chỉ lưu List<String> mã (["FPT", "VNM"]) vào SharedPreferences.
//   Không lưu full model để tiết kiệm storage và tránh stale data.
// =============================================================================

/// Provider quản lý danh sách cổ phiếu theo dõi (Watchlist).
///
/// Extends [ChangeNotifier] để tích hợp với Provider package.
/// Mọi widget gọi `Provider.of<WatchlistProvider>(context)` hoặc
/// `Consumer<WatchlistProvider>` sẽ tự động rebuild khi provider thay đổi.
class WatchlistProvider extends ChangeNotifier {
  /// Constructor: Khởi động quá trình load dữ liệu nền.
  ///
  /// `unawaited()`: constructor đồng bộ không thể `await`, dùng `unawaited()`
  /// để chạy async function mà không block. Dart analyzer không cảnh báo
  /// "discarded future" khi dùng unawaited().
  WatchlistProvider() {
    unawaited(_initialize());
  }

  // Khóa lưu trong SharedPreferences
  static const String _storageKey = 'watchlist_symbols';
  // Số mã mặc định khi chưa có cấu hình người dùng
  static const int _defaultCount = 8;

  /// Danh sách mã cổ phiếu hiện đang theo dõi (chỉ lưu tên mã: "FPT", "VNM").
  final List<String> _symbols = <String>[];

  /// Kho tổng: tất cả mã CK VN có thể tra cứu (từ hardcode + Yahoo search).
  final List<StockSymbolModel> _allSymbols = <StockSymbolModel>[];

  /// Map tra cứu nhanh O(1): "FPT" → StockSymbolModel (thay vì lặp list O(n)).
  Map<String, StockSymbolModel> _symbolLookup = <String, StockSymbolModel>{};

  bool _isLoading = true; // true khi đang khởi tạo, false khi xong

  /// Cache kết quả tính toán của getter [trackedSymbols].
  /// Null khi cần tính lại (sau add/remove/reorder).
  List<StockSymbolModel>? _trackedSymbolsCache;

  // ===========================================================================
  // Public Getters
  // ===========================================================================

  /// Trả về true khi Provider đang khởi tạo (load SharedPreferences + API).
  bool get isLoading => _isLoading;

  /// Danh sách TẤT CẢ mã CK có thể thêm vào watchlist (dùng trong tìm kiếm).
  List<StockSymbolModel> get availableSymbols => _allSymbols;

  /// Danh sách [StockSymbolModel] của các mã đang theo dõi (theo thứ tự người dùng).
  ///
  /// Có cache để tránh tính toán lại nhiều lần liên tiếp khi UI rebuild.
  /// Cache bị xóa (_invalidateCache) khi có thay đổi (add/remove/reorder).
  List<StockSymbolModel> get trackedSymbols {
    // Trả về cache nếu còn hợp lệ
    if (_trackedSymbolsCache != null) {
      return _trackedSymbolsCache!;
    }

    // Chưa có dữ liệu → trả về danh sách mặc định
    if (_symbols.isEmpty && _allSymbols.isEmpty) {
      return _trackedSymbolsCache = _getDefaultWatchlist();
    }

    // Map từng mã string → StockSymbolModel tương ứng.
    // Nếu không tìm thấy trong lookup → tạo placeholder tối giản.
    final List<StockSymbolModel> result = _symbols
        .map(
          (String code) =>
              _symbolLookup[code] ?? // Tra cứu O(1) trong map
              StockSymbolModel(     // Placeholder nếu không tìm thấy
                displaySymbol: code,
                apiSymbol: '$code.VN',
                companyName: code,
                exchange: 'VN',
              ),
        )
        .toList(growable: false); // growable: false = immutable size, nhẹ hơn

    return _trackedSymbolsCache = result; // Gán cache và trả về cùng lúc
  }

  // ===========================================================================
  // Public Actions
  // ===========================================================================

  /// Kiểm tra mã đã có trong watchlist chưa.
  bool containsSymbol(String displaySymbol) {
    return _symbols.contains(displaySymbol.toUpperCase());
  }

  /// Thêm 1 mã mới vào watchlist.
  ///
  /// Quy trình:
  /// 1. Normalize thành UPPERCASE
  /// 2. Kiểm tra trùng → bỏ qua nếu đã có
  /// 3. Đảm bảo mã có trong lookup map
  /// 4. Thêm vào list → lưu SharedPreferences → invalidate cache → notify UI
  Future<void> addSymbol(String displaySymbol) async {
    final String code = displaySymbol.toUpperCase();
    if (_symbols.contains(code)) {
      return; // Đã có → không làm gì
    }
    _ensureSymbolInLookup(code); // Đảm bảo có thể lookup model
    _symbols.add(code);
    await _save();
    _invalidateCache();
    notifyListeners(); // Trigger rebuild tất cả widget lắng nghe
  }

  /// Xóa 1 mã khỏi watchlist.
  ///
  /// [List.remove()] trả về true nếu xóa thành công → chỉ lưu/notify khi thực sự thay đổi.
  Future<void> removeSymbol(String displaySymbol) async {
    if (_symbols.remove(displaySymbol.toUpperCase())) {
      await _save();
      _invalidateCache();
      notifyListeners();
    }
  }

  /// Sắp xếp lại thứ tự watchlist (dùng cho ReorderableListView).
  ///
  /// Dart quirk của ReorderableListView:
  /// Khi kéo item xuống, `newIndex` là chỉ số SAU KHI item cũ vẫn còn đó.
  /// Phải trừ 1 để bù lại khi removeAt làm shift các index.
  ///
  /// Ví dụ: kéo index 0 xuống index 2
  ///   Before: [A, B, C, D] → removeAt(0) → [B, C, D]
  ///   newIndex nhận = 2, nhưng sau removeAt thật sự là vị trí 1
  ///   → newIndex - 1 = 1 → insert(1, A) → [B, A, C, D] ✓
  Future<void> reorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1; // Bù lại vì item đã bị remove trước insert
    }
    final String item = _symbols.removeAt(oldIndex); // Lấy ra khỏi list
    _symbols.insert(newIndex, item);                  // Chèn vào vị trí mới
    await _save();
    _invalidateCache();
    notifyListeners();
  }

  /// Xóa toàn bộ watchlist và khôi phục về danh sách mặc định (8 mã đầu trong constants).
  Future<void> resetToDefault() async {
    final List<StockSymbolModel> defaults = _getDefaultWatchlist();
    _symbols
      ..clear()                                                                    // Xóa hết
      ..addAll(defaults.map((StockSymbolModel symbol) => symbol.displaySymbol)); // Thêm lại default
    await _save();
    _invalidateCache();
    notifyListeners();
  }

  /// Làm mới kho tổng (symbol catalog) từ Yahoo Finance API.
  ///
  /// Sau khi refresh, cập nhật lookup map và rebuild trackedSymbols.
  /// Gọi từ WatchlistManageScreen khi user nhấn nút refresh.
  Future<void> refreshSymbolCatalog() async {
    try {
      final List<StockSymbolModel> fetched =
          await YahooFinanceService.instance.refreshSymbols(); // Force re-fetch API
      _allSymbols
        ..clear()
        ..addAll(fetched);
      // Rebuild lookup map O(1) từ list mới
      _symbolLookup = <String, StockSymbolModel>{
        for (final StockSymbolModel symbol in _allSymbols)
          symbol.displaySymbol.toUpperCase(): symbol,
      };
      // Đảm bảo các mã đang theo dõi vẫn có trong lookup
      for (final String code in _symbols) {
        _ensureSymbolInLookup(code);
      }
      _invalidateCache();
      notifyListeners();
    } catch (error) {
      debugPrint('WatchlistProvider refreshSymbolCatalog error: $error');
    }
  }

  // ===========================================================================
  // Private Helpers
  // ===========================================================================

  /// Xóa cache để buộc tính toán lại ở lần gọi getter [trackedSymbols] kế tiếp.
  void _invalidateCache() {
    _trackedSymbolsCache = null;
  }

  /// Tạo danh sách mặc định: 8 mã đầu tiên từ [kTrackedStockSymbols] trong constants.
  List<StockSymbolModel> _getDefaultWatchlist() {
    return kTrackedStockSymbols
        .take(_defaultCount) // Iterable.take(): lấy tối đa N phần tử đầu
        .map((StockSymbol s) => StockSymbolModel(
              displaySymbol: s.displaySymbol,
              apiSymbol: s.apiSymbol,
              companyName: s.companyName,
              exchange: s.exchange,
            ))
        .toList(growable: false);
  }

  // ---------------------------------------------------------------------------
  // _initialize() — Khởi tạo provider: load từ storage + API
  // ---------------------------------------------------------------------------

  Future<void> _initialize() async {
    try {
      // Bước 1: Load watchlist đã lưu từ bộ nhớ máy
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<String>? stored = prefs.getStringList(_storageKey);

      // Bước 2: Tải kho tổng từ Yahoo (với fallback về hardcoded list)
      try {
        final List<StockSymbolModel> fetched =
            await YahooFinanceService.instance.fetchAllVietnamSymbols();
        _allSymbols
          ..clear()
          ..addAll(fetched);
      } catch (e) {
        debugPrint('Failed to fetch symbols, using defaults: $e');
        // Fallback: dùng danh sách hardcoded từ constants
        _allSymbols
          ..clear()
          ..addAll(_getDefaultWatchlist());
      }

      // Bước 3: Xây dựng lookup map để tra nhanh O(1)
      // Cú pháp: { for (item in list) key: value } = collection for trong Map literal
      _symbolLookup = <String, StockSymbolModel>{
        for (final StockSymbolModel symbol in _allSymbols)
          symbol.displaySymbol.toUpperCase(): symbol,
      };

      // Bước 4: Load danh sách watchlist (đã lưu hoặc mặc định)
      if (stored != null && stored.isNotEmpty) {
        // Có dữ liệu đã lưu → dùng
        _symbols
          ..clear()
          ..addAll(stored.map((String code) => code.toUpperCase()));
      } else {
        // Lần đầu chạy app → dùng danh sách mặc định
        final List<StockSymbolModel> defaults = _getDefaultWatchlist();
        _symbols
          ..clear()
          ..addAll(defaults.map((StockSymbolModel symbol) => symbol.displaySymbol));
      }

      // Đảm bảo tất cả mã đang theo dõi đều có trong lookup
      for (final String code in _symbols) {
        _ensureSymbolInLookup(code);
      }
    } catch (error) {
      debugPrint('WatchlistProvider initialization error: $error');
      // Fallback toàn phần: dùng hardcoded defaults nếu mọi thứ đều lỗi
      if (_symbols.isEmpty) {
        _symbols
          ..clear()
          ..addAll(kTrackedStockSymbols.take(_defaultCount).map((StockSymbol e) => e.displaySymbol));
      }
      if (_allSymbols.isEmpty) {
        final List<StockSymbolModel> defaults = _getDefaultWatchlist();
        _allSymbols
          ..clear()
          ..addAll(defaults);
        _symbolLookup = <String, StockSymbolModel>{
          for (final StockSymbolModel symbol in _allSymbols)
            symbol.displaySymbol.toUpperCase(): symbol,
        };
      }
      for (final String code in _symbols) {
        _ensureSymbolInLookup(code);
      }
    } finally {
      // finally: LUÔN chạy dù có lỗi hay không → đảm bảo isLoading luôn được set false
      _isLoading = false;
      notifyListeners(); // Báo UI biết đã xong khởi tạo → rebuild từ loading sang content
    }
  }

  // ---------------------------------------------------------------------------
  // _ensureSymbolInLookup() — Đảm bảo mã luôn có trong lookup map
  // ---------------------------------------------------------------------------

  /// Thêm mã vào lookup map nếu chưa có.
  ///
  /// Tìm kiếm theo 3 cách (ưu tiên giảm dần):
  /// 1. Lookup map (O(1)) — đã có → return ngay
  /// 2. Linear search trong allSymbols (O(n)) — tìm thấy → thêm vào map
  /// 3. Tạo placeholder tối giản — không tìm thấy đâu hết
  void _ensureSymbolInLookup(String code) {
    if (_symbolLookup.containsKey(code)) {
      return; // Đã có → không làm gì
    }
    // Linear search (chỉ chạy khi thực sự cần, không ảnh hưởng nhiều đến perf)
    for (final StockSymbolModel symbol in _allSymbols) {
      if (symbol.displaySymbol.toUpperCase() == code) {
        _symbolLookup[code] = symbol;
        return;
      }
    }
    // Cuối cùng: tạo placeholder để UI không crash (hiển thị mã thay vì tên công ty)
    _symbolLookup[code] = StockSymbolModel(
      displaySymbol: code,
      apiSymbol: '$code.VN',
      companyName: code,    // Tên = mã (chưa có thông tin)
      exchange: 'VN',
    );
  }

  // ---------------------------------------------------------------------------
  // _save() — Lưu watchlist vào SharedPreferences
  // ---------------------------------------------------------------------------

  /// Lưu danh sách mã hiện tại vào bộ nhớ persistent của thiết bị.
  ///
  /// SharedPreferences.setStringList: lưu ['FPT', 'VNM', 'VCB'] → persist qua restart app.
  Future<void> _save() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    // Tạo copy List (không lưu reference trực tiếp → an toàn với concurrent modification)
    await prefs.setStringList(_storageKey, List<String>.from(_symbols));
  }
}
