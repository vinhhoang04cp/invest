import 'package:flutter/foundation.dart';

/// Lớp đại diện cho một mã Cổ phiếu kết hợp cùng với giá và các chỉ số thị trường theo thời gian thực.
/// Được sử dụng rộng rãi khắp ứng dụng (đặc biệt trong Watchlist và màn hình Chi tiết).
class Stock {
  const Stock({
    required this.symbol,
    required this.name,
    required this.price,
    required this.changePercent,
    required this.volume,
    this.apiSymbol,
    this.dayHigh,
    this.dayLow,
    this.open,
    this.previousClose,
    this.marketCap,
  });

  final String symbol;         // Mã định danh hiển thị UI (FPT)
  final String name;           // Tên tổ chức/công ty
  final double price;          // Mức giá khớp lệnh hiện tại
  final double changePercent;  // Tỷ lệ thay đổi giá so với giá tham chiếu
  final int volume;            // Tổng khối lượng giao dịch trong ngày
  final String? apiSymbol;     // Tham chiếu hệ thống API (FPT.VN)
  final double? dayHigh;       // Mức giá trần/cao nhất trong ngày
  final double? dayLow;        // Mức giá sàn/thấp nhất trong ngày
  final double? open;          // Mức giá thời điểm mở cửa
  final double? previousClose; // Mức giá lúc đóng cửa của phiên hôm trước (Tham chiếu)
  final double? marketCap;     // Vốn hóa thị trường ước tính

  /// Tiền chênh lệch bằng con số tuyệt đối
  double get changeValue => price * changePercent / 100;

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

  factory Stock.fromJson(Map<String, dynamic> json) {
    return Stock(
      symbol: json['symbol'] as String,
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Stock && other.symbol == symbol;
  }

  @override
  int get hashCode => symbol.hashCode;

  @override
  String toString() {
    return 'Stock(symbol: $symbol, name: $name, price: $price, '
        'changePercent: $changePercent, volume: $volume, apiSymbol: $apiSymbol)';
  }
}

/// Đại diện cho một điểm (Point) độc lập trên biểu đồ đường giá (Line chart hoặc Sparkline)
@immutable
class StockPricePoint {
  const StockPricePoint({
    required this.timeLabel, // Mốc thời gian tương ứng (Trục X)
    required this.price,     // Giá trị tại mốc thời gian đó (Trục Y)
  });

  final String timeLabel;
  final double price;
}
