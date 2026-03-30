import 'stock.dart';

class PortfolioEntry {
  const PortfolioEntry({
    required this.stock,
    required this.quantity,
    required this.averagePrice,
  });

  final Stock stock;
  final int quantity;
  final double averagePrice;

  double get currentValue => stock.price * quantity;
  double get investedValue => averagePrice * quantity;
  double get profitLoss => currentValue - investedValue;
  double get profitLossPercent => investedValue == 0 ? 0 : profitLoss / investedValue * 100;
}

class PortfolioSummary {
  const PortfolioSummary({
    required this.entries,
  });

  final List<PortfolioEntry> entries;

  double get totalValue => entries.fold(0, (double sum, entry) => sum + entry.currentValue);
  double get totalInvested => entries.fold(0, (double sum, entry) => sum + entry.investedValue);
  double get totalProfitLoss => totalValue - totalInvested;
  double get totalProfitLossPercent => totalInvested == 0 ? 0 : totalProfitLoss / totalInvested * 100;
}
