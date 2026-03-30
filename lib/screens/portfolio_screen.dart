import 'package:flutter/material.dart';

import '../models/portfolio.dart';
import '../services/api_service.dart';

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  final ApiService _apiService = ApiService.instance;
  late Future<PortfolioSummary> _portfolioFuture;

  @override
  void initState() {
    super.initState();
    _portfolioFuture = _apiService.fetchPortfolio();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục đầu tư'),
        actions: <Widget>[
          IconButton(
            onPressed: () {
              // TODO(thanhvien4): Mở modal thêm mã mới vào danh mục.
            },
            icon: const Icon(Icons.add),
            tooltip: 'Thêm mã',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() {
            _portfolioFuture = _apiService.fetchPortfolio();
          });
          await _portfolioFuture;
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
                _buildSummaryCard(context, summary),
                const SizedBox(height: 16),
                _buildPortfolioList(summary),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, PortfolioSummary summary) {
    final TextTheme textTheme = Theme.of(context).textTheme;
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
            Text('${summary.totalValue.toStringAsFixed(0)} đ', style: textTheme.headlineSmall),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text('Lợi nhuận:', style: textTheme.bodyMedium),
                const SizedBox(width: 8),
                Text(
                  '${summary.totalProfitLoss.toStringAsFixed(0)} đ',
                  style: textTheme.titleMedium?.copyWith(color: profitColor),
                ),
                const SizedBox(width: 12),
                Chip(
                  label: Text('${summary.totalProfitLossPercent.toStringAsFixed(2)}%'),
                  backgroundColor: profitColor.withOpacity(.12),
                  labelStyle: TextStyle(color: profitColor),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('TODO(thanhvien4): Thêm biểu đồ phân bổ danh mục.'),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioList(PortfolioSummary summary) {
    return Column(
      children: summary.entries
          .map(
            (PortfolioEntry entry) => Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                title: Text('${entry.stock.symbol} • ${entry.stock.name}'),
                subtitle: Text('Số lượng: ${entry.quantity} | Giá vốn: ${entry.averagePrice.toStringAsFixed(0)} đ'),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text('${entry.currentValue.toStringAsFixed(0)} đ'),
                    Text(
                      '${entry.profitLoss.toStringAsFixed(0)} đ',
                      style: TextStyle(color: entry.profitLoss >= 0 ? Colors.green : Colors.red),
                    ),
                  ],
                ),
                onTap: () {
                  // TODO(thanhvien4): Điều hướng tới chỉnh sửa hoặc chi tiết từng mục danh mục.
                },
              ),
            ),
          )
          .toList(),
    );
  }
}
