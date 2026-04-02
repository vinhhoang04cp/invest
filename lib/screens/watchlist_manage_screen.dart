import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../constants/stock_symbols.dart';
import '../models/stock_symbol_model.dart';
import '../state/watchlist_provider.dart';

class WatchlistManageScreen extends StatefulWidget {
  const WatchlistManageScreen({super.key});

  static const String routeName = '/watchlist-manage';

  @override
  State<WatchlistManageScreen> createState() => _WatchlistManageScreenState();
}

class _WatchlistManageScreenState extends State<WatchlistManageScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý watchlist'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Làm mới danh sách mã',
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<WatchlistProvider>().refreshSymbolCatalog(),
          ),
          TextButton(
            onPressed: () => _showResetDialog(context),
            child: const Text('Đặt lại'),
          ),
        ],
      ),
      floatingActionButton: Consumer<WatchlistProvider>(
        builder: (BuildContext context, WatchlistProvider provider, _) {
          return FloatingActionButton.extended(
            onPressed: provider.isLoading ? null : () => _showAddSymbolSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mã'),
          );
        },
      ),
      body: Consumer<WatchlistProvider>(
        builder: (BuildContext context, WatchlistProvider provider, _) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          final List<StockSymbolModel> symbols = provider.trackedSymbols;
          if (symbols.isEmpty) {
            return const Center(child: Text('Danh sách watchlist đang trống.')); 
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: symbols.length,
            onReorder: (int oldIndex, int newIndex) {
              provider.reorder(oldIndex, newIndex);
            },
            itemBuilder: (BuildContext context, int index) {
              final StockSymbolModel symbol = symbols[index];
              return Card(
                key: ValueKey<String>(symbol.displaySymbol),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(symbol.displaySymbol, style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(symbol.companyName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      provider.removeSymbol(symbol.displaySymbol);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _showAddSymbolSheet(BuildContext context) async {
    final WatchlistProvider provider = context.read<WatchlistProvider>();
    if (provider.isLoading) {
      return;
    }
    final TextEditingController controller = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              if (provider.availableSymbols.isEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const <Widget>[
                    SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                  ],
                );
              }
              List<StockSymbolModel> candidates = provider.availableSymbols
                  .where((StockSymbolModel symbol) => !provider.containsSymbol(symbol.displaySymbol))
                  .toList();
              final String query = controller.text.trim().toLowerCase();
              if (query.isNotEmpty) {
                candidates = candidates
                    .where(
                      (StockSymbolModel symbol) =>
                          symbol.displaySymbol.toLowerCase().contains(query) ||
                          symbol.companyName.toLowerCase().contains(query),
                    )
                    .toList();
              } else {
                candidates.sort((StockSymbolModel a, StockSymbolModel b) => a.displaySymbol.compareTo(b.displaySymbol));
                if (candidates.length > 120) {
                  candidates = candidates.take(120).toList();
                }
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Tìm mã cổ phiếu...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 320,
                    child: candidates.isEmpty
                        ? const Center(child: Text('Không tìm thấy mã phù hợp'))
                        : ListView.separated(
                            itemCount: candidates.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (BuildContext context, int index) {
                              final StockSymbolModel symbol = candidates[index];
                              return ListTile(
                                title: Text(symbol.displaySymbol),
                                subtitle: Text(
                                  '${symbol.companyName} • ${symbol.exchange}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () {
                                  provider.addSymbol(symbol.displaySymbol);
                                  Navigator.of(context).pop();
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    controller.dispose();
  }

  Future<void> _showResetDialog(BuildContext context) async {
    final WatchlistProvider provider = context.read<WatchlistProvider>();
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Đặt lại danh sách'),
          content: const Text('Bạn có chắc muốn khôi phục watchlist về mặc định?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Đồng ý'),
            ),
          ],
        );
      },
    );
    if (confirm == true) {
      await provider.resetToDefault();
    }
  }
}
