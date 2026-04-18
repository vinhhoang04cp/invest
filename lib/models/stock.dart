import 'package:flutter/foundation.dart'; // @immutable annotation

// =============================================================================
// Stock — Model Cổ phiếu với Giá thị trường
// =============================================================================
//
// Model cốt lõi của toàn ứng dụng — đại diện cho 1 mã cổ phiếu kèm dữ liệu
// giá real-time. Được dùng ở:
//   - HomeScreen (Watchlist cards)
//   - StockListScreen (danh sách)
//   - StockDetailScreen (chi tiết giá)
//   - PortfolioEntry (tính lãi/lỗ)
//
// THIẾT KẾ IMMUTABLE:
//   Tất cả field là `final` → không thể thay đổi sau khi tạo.
//   Muốn "sửa" → dùng copyWith() để tạo object mới với field mong muốn thay đổi.
//   Lợi ích: thread-safe, dễ debug, dễ test, tương thích tốt với Flutter rebuild.
//
// PHÂN BIỆT symbol vs apiSymbol:
//   symbol: "FPT" — mã hiển thị trên UI
//   apiSymbol: "FPT.VN" — mã gửi lên Yahoo Finance API
// =============================================================================

/// Đại diện cho 1 mã cổ phiếu kèm dữ liệu giá thị trường.
class Stock {
  const Stock({
    required this.symbol,       // Bắt buộc: mã hiển thị
    required this.name,         // Bắt buộc: tên công ty
    required this.price,        // Bắt buộc: giá hiện tại
    required this.changePercent,// Bắt buộc: % thay đổi
    required this.volume,       // Bắt buộc: khối lượng giao dịch
    this.apiSymbol,             // Tùy chọn: mã Yahoo API
    this.dayHigh,               // Tùy chọn: giá cao nhất trong ngày
    this.dayLow,                // Tùy chọn: giá thấp nhất trong ngày
    this.open,                  // Tùy chọn: giá mở cửa
    this.previousClose,         // Tùy chọn: giá đóng cửa phiên trước (tham chiếu)
    this.marketCap,             // Tùy chọn: vốn hóa thị trường
  });

  final String symbol;         // "FPT" — mã hiển thị trên UI
  final String name;           // "CTCP FPT" — tên công ty đầy đủ
  final double price;          // Giá khớp lệnh hiện tại (VND)
  final double changePercent;  // Phần trăm thay đổi so với phiên trước (có thể âm)
  final int volume;            // Tổng khối lượng cổ phiếu giao dịch trong ngày
  final String? apiSymbol;     // "FPT.VN" — format Yahoo Finance API (nullable)
  final double? dayHigh;       // Giá cao nhất trong phiên (nullable nếu API không có)
  final double? dayLow;        // Giá thấp nhất trong phiên (nullable)
  final double? open;          // Giá lúc mở cửa phiên hôm nay (nullable)
  final double? previousClose; // Giá đóng cửa phiên trước = Giá tham chiếu (nullable)
  final double? marketCap;     // Vốn hóa thị trường = price × tổng CP lưu hành (nullable)

  // ---------------------------------------------------------------------------
  // Computed Getters — Giá trị tính toán từ field hiện có
  // ---------------------------------------------------------------------------

  /// Tiền chênh lệch tuyệt đối so với phiên trước.
  ///
  /// Ví dụ: price=125000, changePercent=1.5 → changeValue = 125000 * 1.5 / 100 = 1875
  /// Hiển thị: "+1,875 đ" hoặc "-1,875 đ"
  double get changeValue => price * changePercent / 100;

  // ---------------------------------------------------------------------------
  // copyWith — Immutable Update Pattern
  // ---------------------------------------------------------------------------

  /// Tạo bản sao với một số field được thay đổi.
  ///
  /// Pattern: `stock.copyWith(price: 126000)` tạo object mới với price khác,
  /// tất cả field khác giữ nguyên.
  ///
  /// Dùng null-aware operator `??`: nếu tham số null → dùng giá trị hiện tại.
  Stock copyWith({
    String? symbol,
    String? name,
    double? price,
    double? changePercent,
    int? volume,
    String? apiSymbol,
    double? dayHigh,
    double? dayLow,
    double? open,
    double? previousClose,
    double? marketCap,
  }) {
    return Stock(
      symbol: symbol ?? this.symbol,
      name: name ?? this.name,
      price: price ?? this.price,
      changePercent: changePercent ?? this.changePercent,
      volume: volume ?? this.volume,
      apiSymbol: apiSymbol ?? this.apiSymbol,
      dayHigh: dayHigh ?? this.dayHigh,
      dayLow: dayLow ?? this.dayLow,
      open: open ?? this.open,
      previousClose: previousClose ?? this.previousClose,
      marketCap: marketCap ?? this.marketCap,
    );
  }

  // ---------------------------------------------------------------------------
  // Factory constructor — Tạo từ JSON
  // ---------------------------------------------------------------------------

  /// Tạo object Stock từ Map JSON (thường từ JSON API hoặc SharedPreferences).
  ///
  /// Dùng `as Type?` để cast kiểu an toàn, kết hợp ?? để fallback khi null.
  /// Ví dụ: `(json['price'] as num?)?.toDouble() ?? 0`
  ///   → Nếu 'price' null hoặc không tồn tại → dùng 0
  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'] as String,
      // Fallback: dùng symbol làm tên nếu không có 'name' field
      name: json['name'] as String? ?? json['symbol'] as String,
      price: (json['price'] as num).toDouble(),
      changePercent: (json['changePercent'] as num).toDouble(),
      volume: (json['volume'] as num).toInt(),
      apiSymbol: json['apiSymbol'] as String? ?? json['symbol'] as String?,
      dayHigh: (json['dayHigh'] as num?)?.toDouble(),
      dayLow: (json['dayLow'] as num?)?.toDouble(),
      open: (json['open'] as num?)?.toDouble(),
      previousClose: (json['previousClose'] as num?)?.toDouble(),
      marketCap: (json['marketCap'] as num?)?.toDouble(),
    );
  }

  // ---------------------------------------------------------------------------
  // Serialization — Chuyển về JSON
  // ---------------------------------------------------------------------------

  /// Chuyển Stock thành Map để serialize (lưu hoặc gửi API).
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'symbol': symbol,
      'name': name,
      'price': price,
      'changePercent': changePercent,
      'volume': volume,
      'apiSymbol': apiSymbol,
      'dayHigh': dayHigh,
      'dayLow': dayLow,
      'open': open,
      'previousClose': previousClose,
      'marketCap': marketCap,
    };
  }

  // ---------------------------------------------------------------------------
  // Equality & Hash — Dùng symbol làm identity
  // ---------------------------------------------------------------------------

  /// Override == để so sánh theo symbol (bỏ qua sự khác biệt về giá).
  ///
  /// Lý do: Cùng 1 mã cổ phiếu dù giá khác nhau vẫn được coi là "giống nhau".
  /// Dùng trong Set và Map operations (watchlist dedup, find in list...).
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true; // Cùng reference object → bằng nhau
    return other is Stock && other.symbol == symbol;
  }

  /// hashCode phải khớp với == — cùng dùng symbol.
  /// Quy tắc: nếu a == b thì a.hashCode == b.hashCode.
  @override
  int get hashCode => symbol.hashCode;

  @override
  String toString() {
    return 'Stock(symbol: $symbol, name: $name, price: $price, '
        'changePercent: $changePercent, volume: $volume, apiSymbol: $apiSymbol)';
  }
}

// =============================================================================
// StockPricePoint — Một điểm trên biểu đồ giá
// =============================================================================

/// Đại diện cho 1 điểm dữ liệu trên biểu đồ đường giá.
///
/// Mỗi điểm = (nhãn thời gian, giá) → vẽ thành FlSpot trong fl_chart.
///
/// @immutable: Dart annotation yêu cầu tất cả field phải là final.
/// Compiler cảnh báo nếu vi phạm. Đây là tài liệu rõ ràng về design intent.
@immutable
class StockPricePoint {
  const StockPricePoint({
    required this.timeLabel, // Trục X: "14:30" hoặc "18/04"
    required this.price,     // Trục Y: giá tại thời điểm đó
  });

  final String timeLabel; // Nhãn thời gian định dạng sẵn (không phải DateTime thô)
  final double price;     // Giá đóng cửa (close price) tại timeLabel này
}
