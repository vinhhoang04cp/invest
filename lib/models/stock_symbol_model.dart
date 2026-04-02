class StockSymbolModel {
  const StockSymbolModel({
    required this.displaySymbol,
    required this.apiSymbol,
    required this.companyName,
    required this.exchange,
    this.currency,
    this.type,
  });

  final String displaySymbol;
  final String apiSymbol;
  final String companyName;
  final String exchange;
  final String? currency;
  final String? type;

  factory StockSymbolModel.fromJson(Map<String, dynamic> json) {
    return StockSymbolModel(
      displaySymbol: (json['displaySymbol'] as String? ?? json['symbol'] as String? ?? '').toUpperCase(),
      apiSymbol: json['symbol'] as String? ?? '',
      companyName: json['description'] as String? ?? json['companyName'] as String? ?? '',
      exchange: json['exchange'] as String? ?? 'VN',
      currency: json['currency'] as String?,
      type: json['type'] as String?,
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
