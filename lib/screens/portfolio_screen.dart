import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/portfolio.dart';
import '../state/portfolio_provider.dart';
import '../widgets/portfolio_entry_form.dart';

// =============================================================================
// PortfolioScreen — Màn hình Danh mục Đầu tư Cá nhân
// =============================================================================

class PortfolioScreen extends StatefulWidget {
  const PortfolioScreen({super.key});

  @override
  State<PortfolioScreen> createState() => _PortfolioScreenState();
}

class _PortfolioScreenState extends State<PortfolioScreen> {
  
  void _showEntryForm(BuildContext context, {PortfolioItem? initialItem}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => PortfolioEntryForm(initialItem: initialItem),
    );

    if (result != null && mounted) {
      final provider = Provider.of<PortfolioProvider>(context, listen: false);
      await provider.upsertEntry(
        result['symbol'],
        result['quantity'],
        result['price'],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Danh mục đầu tư'),
        actions: <Widget>[
          IconButton(
            onPressed: () => _showEntryForm(context),
            icon: const Icon(Icons.add),
            tooltip: 'Thêm mã',
          ),
        ],
      ),
      body: Consumer<PortfolioProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = provider.summary;

          return RefreshIndicator(
            onRefresh: () => provider.refreshPrices(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                _buildSummaryCard(context, summary), // Card tổng kết
                const SizedBox(height: 16),
                _buildPortfolioList(context, provider, summary), // Danh sách từng khoản
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, PortfolioSummary summary) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color profitColor = summary.totalProfitLoss >= 0 ? Colors.green : Colors.red;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Tổng giá trị tài sản', style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              '${summary.totalValue.toStringAsFixed(0)} đ',
              style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lợi nhuận', style: textTheme.bodySmall),
                    Text(
                      '${summary.totalProfitLoss >= 0 ? "+" : ""}${summary.totalProfitLoss.toStringAsFixed(0)} đ',
                      style: textTheme.titleMedium?.copyWith(color: profitColor),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: profitColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${summary.totalProfitLoss >= 0 ? "+" : ""}${summary.totalProfitLossPercent.toStringAsFixed(2)}%',
                    style: TextStyle(color: profitColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPortfolioList(BuildContext context, PortfolioProvider provider, PortfolioSummary summary) {
    if (summary.entries.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Text('Chưa có mã nào trong danh mục'),
        ),
      );
    }

    return Column(
      children: summary.entries.map((PortfolioEntry entry) {
        final item = provider.items.firstWhere((i) => i.symbol == entry.stock.symbol);
        
        return Dismissible(
          key: Key(entry.stock.symbol),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red,
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          onDismissed: (direction) {
            provider.removeEntry(entry.stock.symbol);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Đã xóa ${entry.stock.symbol}')),
            );
          },
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              title: Row(
                children: [
                  Text(
                    entry.stock.symbol,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.stock.name,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'SL: ${entry.quantity} | Vốn: ${entry.averagePrice.toStringAsFixed(0)} đ',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${entry.currentValue.toStringAsFixed(0)} đ',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  Text(
                    '${entry.profitLoss >= 0 ? "+" : ""}${entry.profitLoss.toStringAsFixed(0)} đ',
                    style: TextStyle(
                      color: entry.profitLoss >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              onTap: () => _showEntryForm(context, initialItem: item),
            ),
          ),
        );
      }).toList(),
    );
  }
}
