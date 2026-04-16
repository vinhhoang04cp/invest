class MarketIndex {
  const MarketIndex({
    required this.name,
    required this.value,
    required this.changePercent,
    this.previousClose,
    this.change,
  });

  final String name;
  final double value;
  final double changePercent;
  final double? previousClose;
  final double? change;

  bool get isPositive => changePercent >= 0;
}
