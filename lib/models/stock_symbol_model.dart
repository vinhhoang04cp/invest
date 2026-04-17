/// Mô hình đại diện cho một mã thông tin chứng khoán lấy từ API search toàn thị trường.
/// Thường dùng cho chức năng tìm kiếm cổ phiếu.
class StockSymbolModel {
  const StockSymbolModel({
    required this.displaySymbol,
    required this.apiSymbol,
    required this.companyName,
    required this.exchange,
    this.currency,
    this.type,
  });

  final String displaySymbol;  // Tên mã hiển thị trên UI (vd: FPT)
  final String apiSymbol;      // Tên mã dùng để gọi API (vd: FPT.VN)
  final String companyName;    // Tên đầy đủ của công ty (vd: CTCP FPT)
  final String exchange;       // Sàn giao dịch (vd: HOSE, HNX)
  final String? currency;      // Loại tiền tệ (vd: VND)
  final String? type;          // Loại tài sản (vd: EQUITY)

  /// Trả về ký hiệu định dạng chuẩn của Yahoo Finance (hậu tố .VN)
  /// Ví dụ FPT -> FPT.VN
  String get yahooSymbol {
    if (apiSymbol.endsWith('.VN') || apiSymbol.startsWith('^')) {
      return apiSymbol;
    }
    return '$displaySymbol.VN';
  }

  /// Hàm Factory khởi tạo đối tượng từ tập dữ liệu JSON trả về bởi API.
  factory StockSymbolModel.fromJson(Map<String, dynamic> json) {
    // Support both Finnhub-style and Yahoo-style responses
    final String rawSymbol = json['symbol'] as String? ?? '';
    final String display = (json['displaySymbol'] as String? ??
            rawSymbol.replaceAll('.VN', ''))
        .toUpperCase();

    return StockSymbolModel(
      displaySymbol: display,
      apiSymbol: rawSymbol.isEmpty ? display : rawSymbol,
      companyName: json['description'] as String? ??
          json['companyName'] as String? ??
          json['longname'] as String? ??
          json['shortname'] as String? ??
          '',
      exchange: json['exchange'] as String? ?? 'VN',
      currency: json['currency'] as String?,
      type: json['type'] as String? ?? json['quoteType'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'displaySymbol': displaySymbol,
      'symbol': apiSymbol,
      'companyName': companyName,
      'exchange': exchange,
      'currency': currency,
      'type': type,
    };
  }
}
