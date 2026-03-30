class MarketIndex {
  const MarketIndex({
    required this.name,
    required this.value,
    required this.changePercent,
  });

  final String name;
  final double value;
  final double changePercent;

  bool get isPositive => changePercent >= 0;
}
