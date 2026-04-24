import 'stock.dart';

/// Dữ liệu thô của một khoản đầu tư (dùng để lưu trữ).
class PortfolioItem {
  const PortfolioItem({
    required this.symbol,
    required this.quantity,
    required this.averagePrice,
  });

  final String symbol;
  final int quantity;
  final double averagePrice;

  Map<String, dynamic> toMap() {
    return {
      'symbol': symbol,
      'quantity': quantity,
      'averagePrice': averagePrice,
    };
  }

  factory PortfolioItem.fromMap(Map<String, dynamic> map) {
    return PortfolioItem(
      symbol: map['symbol'] as String,
      quantity: (map['quantity'] as num).toInt(),
      averagePrice: (map['averagePrice'] as num).toDouble(),
    );
  }

  PortfolioItem copyWith({
    String? symbol,
    int? quantity,
    double? averagePrice,
  }) {
    return PortfolioItem(
      symbol: symbol ?? this.symbol,
      quantity: quantity ?? this.quantity,
      averagePrice: averagePrice ?? this.averagePrice,
    );
  }
}

/// Đại diện cho một khoản đầu tư (một mã cổ phiếu cụ thể) trong Danh mục của người dùng.
class PortfolioEntry {
  const PortfolioEntry({
    required this.stock,
    required this.quantity,
    required this.averagePrice,
  });

  final Stock stock;        // Thông tin mã cổ phiếu (chứa giá hiện tại)
  final int quantity;       // Tổng số lượng cổ phiếu đang nắm giữ
  final double averagePrice;// Giá trung bình mua vào (Giá vốn)

  /// Tổng giá trị hiện tại của khoản đầu tư (Giá hiện tại * Số lượng).
  double get currentValue => stock.price * quantity;
  /// Tổng số tiền gốc đã bỏ ra đầu tư (Giá vốn * Số lượng).
  double get investedValue => averagePrice * quantity;
  /// Số tiền lãi hoặc rỗ (Giá trị hiện tại - Vốn).
  double get profitLoss => currentValue - investedValue;
  /// Lợi nhuận gộp tính theo phần trăm (%).
  double get profitLossPercent => investedValue == 0 ? 0 : profitLoss / investedValue * 100;
}

/// Lớp bao bọc tổng thể tài sản toàn bộ Danh mục.
class PortfolioSummary {
  const PortfolioSummary({
    required this.entries,
  });

  final List<PortfolioEntry> entries;

  /// Thống kê: Tổng giá trị tài sản ròng thực tế.
  double get totalValue => entries.fold(0, (double sum, entry) => sum + entry.currentValue);
  /// Thống kê: Tổng mức vốn đổ vào chứng khoán.
  double get totalInvested => entries.fold(0, (double sum, entry) => sum + entry.investedValue);
  /// Thống kê: Tổng lời / lỗ tuyệt đối.
  double get totalProfitLoss => totalValue - totalInvested;
  /// Thống kê: Trung bình tổng tỷ suất Lời/Lỗ theo % của toàn danh mục.
  double get totalProfitLossPercent => totalInvested == 0 ? 0 : totalProfitLoss / totalInvested * 100;
}
