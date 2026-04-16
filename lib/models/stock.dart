import 'package:flutter/foundation.dart';

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

  final String symbol;
  final String name;
  final double price;
  final double changePercent;
  final int volume;
  final String? apiSymbol;
  final double? dayHigh;
  final double? dayLow;
  final double? open;
  final double? previousClose;
  final double? marketCap;

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

@immutable
class StockPricePoint {
  const StockPricePoint({
    required this.timeLabel,
    required this.price,
  });

  final String timeLabel;
  final double price;
}
