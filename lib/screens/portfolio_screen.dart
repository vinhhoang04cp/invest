import 'package:flutter/material.dart';

import '../models/portfolio.dart';
import '../services/yahoo_finance_service.dart';

// =============================================================================
// PortfolioScreen — Màn hình Danh mục Đầu tư Cá nhân
// =============================================================================
//
// Hiển thị:
//   - Card tổng kết: Tổng giá trị tài sản, Lợi nhuận/Lỗ tổng thể
//   - Danh sách từng khoản đầu tư (PortfolioEntry): mã CP, số lượng, giá vốn, hiện tại
//
// HIỆN TẠI: Dữ liệu là MOCK (giả lập từ fetchPortfolio trong YahooFinanceService).
// Cần kết nối backend/database thật để lưu giao dịch mua/bán thực tế.
//
// LUỒNG:
//   initState → fetchPortfolio() → _portfolioFuture
//   FutureBuilder → build UI khi Future complete
// =============================================================================

/// Màn hình Danh mục Đầu tư — tổng hợp và hiển thị các khoản đầu tư.
class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final YahooFinanceService _apiService = YahooFinanceService.instance;

  /// Future chứa dữ liệu danh mục — FutureBuilder theo dõi Future này
  late Future<PortfolioSummary> _portfolioFuture;

  @override
  void initState() {
    super.initState();
    _portfolioFuture = _apiService.fetchPortfolio(); // Bắt đầu fetch ngay khi init
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục đầu tư'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              // TODO: Mở popup form nhập giao dịch mới vào danh mục
            },
            icon: const Icon(Icons.add),
            tooltip: 'Thêm mã',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Pull-to-refresh: tạo Future mới → FutureBuilder rebuild
          setState(() {
            _portfolioFuture = _apiService.fetchPortfolio();
          });
          await _portfolioFuture; // Chờ xong rồi dismiss indicator
        },
        child: FutureBuilder<PortfolioSummary>(
          future: _portfolioFuture,
          builder: (BuildContext context, AsyncSnapshot<PortfolioSummary> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Center(child: Text('Không thể tải danh mục: ${snapshot.error}'));
            }
            final PortfolioSummary summary = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildSummaryCard(context, summary), // Card tổng kết
                const SizedBox(height: 16),
                _buildPortfolioList(summary),         // Danh sách từng khoản
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // _buildSummaryCard() — Card tổng kết toàn danh mục
  // ---------------------------------------------------------------------------

  /// Card tổng kết: tổng giá trị tài sản + lợi nhuận/lỗ tổng thể.
  ///
  /// Dữ liệu đến từ computed getters của [PortfolioSummary]:
  ///   totalValue = fold (cộng dồn) tất cả currentValue từng entry
  ///   totalProfitLoss = totalValue - totalInvested
  Widget _buildSummaryCard(BuildContext context, PortfolioSummary summary) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    // Màu xanh nếu lãi, đỏ nếu lỗ
    final Color profitColor = summary.totalProfitLoss >= 0 ? Colors.green : Colors.red;

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Tổng giá trị', style: textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('${summary.totalValue.toStringAsFixed(0)} đ',
                style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text('Lợi nhuận:', style: textTheme.bodyMedium),
                const SizedBox(width: 8),
                // Lãi/lỗ tuyệt đối (VND)
                Text(
                  '${summary.totalProfitLoss.toStringAsFixed(0)} đ',
                  style: textTheme.titleMedium?.copyWith(color: profitColor),
                ),
                const SizedBox(width: 12),
                // Lãi/lỗ phần trăm trong Chip
                Chip(
                  label: Text('${summary.totalProfitLossPercent.toStringAsFixed(2)}%'),
                  backgroundColor: profitColor.withOpacity(.12),
                  labelStyle: TextStyle(color: profitColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // _buildPortfolioList() — Danh sách từng khoản đầu tư
  // ---------------------------------------------------------------------------

  /// Danh sách từng [PortfolioEntry]: mã cổ phiếu, số lượng, giá vốn, giá trị hiện tại.
  ///
  /// Dùng Column + map() thay vì ListView vì đã ở bên trong ListView cha.
  /// Tránh nested scrollable (ListView trong ListView) gây lỗi layout.
  Widget _buildPortfolioList(PortfolioSummary summary) {
    return Column(
      // summary.entries là List<PortfolioEntry>
      // .map() chuyển từng entry → Widget Card → .toList() convert Iterable sang List
      children: summary.entries
          .map(
            (PortfolioEntry entry) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                // Tên: "FPT • CTCP FPT"
                title: Text('${entry.stock.symbol} • ${entry.stock.name}'),
                // Số lượng + giá vốn bình quân
                subtitle: Text(
                    'Số lượng: ${entry.quantity} | Giá vốn: ${entry.averagePrice.toStringAsFixed(0)} đ'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    // Giá trị hiện tại = giá * số lượng
                    Text('${entry.currentValue.toStringAsFixed(0)} đ'),
                    // Lãi/lỗ từng khoản: màu xanh/đỏ
                    Text(
                      '${entry.profitLoss.toStringAsFixed(0)} đ',
                      style: TextStyle(
                          color: entry.profitLoss >= 0 ? Colors.green : Colors.red),
                    ),
                  ],
                ),
                onTap: () {
                  // TODO: Navigate sang màn hình xem/sửa giao dịch của mã này
                },
              ),
            ),
          )
          .toList(),
    );
  }
}
