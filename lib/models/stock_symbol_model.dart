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

  /// Yahoo Finance symbol format (e.g. VCB.VN)
  String get yahooSymbol {
    if (apiSymbol.endsWith('.VN') || apiSymbol.startsWith('^')) {
      return apiSymbol;
    }
    return '$displaySymbol.VN';
  }

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
