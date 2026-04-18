import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // Provider.of, context.read, Consumer

import '../models/stock_symbol_model.dart';
import '../state/watchlist_provider.dart';

// =============================================================================
// WatchlistManageScreen — Quản lý Danh sách Theo dõi
// =============================================================================
//
// Tính năng:
//   - Drag-n-drop để sắp xếp lại thứ tự (ReorderableListView)
//   - Xóa từng mã (swipe hoặc nút delete)
//   - Thêm mã mới qua BottomSheet tìm kiếm
//   - Refresh kho mã từ Yahoo API
//   - Reset về mặc định (với confirm dialog)
//
// PATTERN SỬ DỤNG:
//   - Consumer<WatchlistProvider>: subscribe và rebuild khi provider thay đổi
//   - context.read<WatchlistProvider>(): gọi method không cần rebuild
//   - StatefulBuilder trong BottomSheet: local setState cho nội dung sheet
// =============================================================================

/// Màn hình quản lý watchlist: thêm/xóa/sắp xếp mã theo dõi.
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
            // context.read<T>(): lấy Provider mà KHÔNG đăng ký lắng nghe
            // Dùng khi chỉ cần gọi method, không cần rebuild khi provider thay đổi
            onPressed: () => context.read<WatchlistProvider>().refreshSymbolCatalog(),
          ),
          TextButton(
            onPressed: () => _showResetDialog(context),
            child: const Text('Đặt lại'),
          ),
        ],
      ),

      // FAB (Floating Action Button) mờ đi khi provider đang loading
      // Consumer: chỉ rebuild phần FAB này khi provider thay đổi (không rebuild cả screen)
      floatingActionButton: Consumer<WatchlistProvider>(
        builder: (BuildContext context, WatchlistProvider provider, _) {
          // `_` là child widget từ bên ngoài Consumer — dùng khi có phần không cần rebuild
          return FloatingActionButton.extended(
            // Disable khi đang loading (null onPressed = disabled button)
            onPressed: provider.isLoading ? null : () => _showAddSymbolSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Thêm mã'),
          );
        },
      ),

      body: Consumer<WatchlistProvider>(
        // Consumer lắng nghe WatchlistProvider → rebuild body khi watchlist thay đổi
        builder: (BuildContext context, WatchlistProvider provider, _) {
          // Loading state
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<StockSymbolModel> symbols = provider.trackedSymbols;

          // Empty state
          if (symbols.isEmpty) {
            return const Center(child: Text('Danh sách watchlist đang trống.'));
          }

          // ReorderableListView: ListView có thể kéo thả để sắp xếp lại
          return ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100), // Bottom padding tránh FAB
            itemCount: symbols.length,
            // Callback khi user kéo thả xong → provider.reorder() lưu thứ tự mới
            onReorder: (int oldIndex, int newIndex) {
              provider.reorder(oldIndex, newIndex);
            },
            itemBuilder: (BuildContext context, int index) {
              final StockSymbolModel symbol = symbols[index];
              return Card(
                // Key BẮCT BUỘC cho ReorderableListView để track vị trí
                // ValueKey<String>: dùng symbol name làm key (duy nhất)
                key: ValueKey<String>(symbol.displaySymbol),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  // Icon kéo ở bên trái (ReorderableListView thêm gesture tự động vào đây)
                  leading: const Icon(Icons.drag_handle),
                  title: Text(symbol.displaySymbol,
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(symbol.companyName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      provider.removeSymbol(symbol.displaySymbol);
                      // Provider tự gọi notifyListeners() → Consumer rebuild list
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

  // ---------------------------------------------------------------------------
  // _showAddSymbolSheet() — BottomSheet tìm kiếm và thêm mã
  // ---------------------------------------------------------------------------

  /// Hiển thị BottomSheet cho phép tìm kiếm và thêm mã vào watchlist.
  ///
  /// isScrollControlled: true → BottomSheet có thể chiếm toàn màn hình
  /// MediaQuery.viewInsets.bottom: chiều cao bàn phím (padding tránh keyboard)
  Future<void> _showAddSymbolSheet(BuildContext context) async {
    final WatchlistProvider provider = context.read<WatchlistProvider>();
    if (provider.isLoading) return;

    final TextEditingController controller = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true, // Cho phép sheet cao hơn 50% màn hình
      builder: (BuildContext context) {
        return Padding(
          // viewInsets.bottom = chiều cao bàn phím → padding để nội dung không bị che
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            top: 16,
            left: 16,
            right: 16,
          ),
          // StatefulBuilder: tạo local setState cho BottomSheet
          // Cần vì BottomSheet là StatelessWidget by default, nhưng ta cần
          // rebuild nội dung khi user gõ tìm kiếm (lọc candidates)
          child: StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              if (provider.availableSymbols.isEmpty) {
                // Chưa load xong kho mã → hiển thị loading
                return const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
                  ],
                );
              }

              // Lọc những mã chưa có trong watchlist
              List<StockSymbolModel> candidates = provider.availableSymbols
                  .where((StockSymbolModel s) => !provider.containsSymbol(s.displaySymbol))
                  .toList();

              // Lọc thêm theo từ khóa tìm kiếm
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
                // Không có từ khóa → sort alphabetical và giới hạn 120 mã đầu
                candidates.sort(
                    (StockSymbolModel a, StockSymbolModel b) =>
                        a.displaySymbol.compareTo(b.displaySymbol));
                if (candidates.length > 120) {
                  candidates = candidates.take(120).toList();
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min, // Sheet chỉ cao bằng nội dung
                children: <Widget>[
                  // Drag handle (thanh nhỏ ở đầu sheet)
                  Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  // TextField tìm kiếm trong sheet
                  TextField(
                    controller: controller,
                    decoration: const InputDecoration(
                      hintText: 'Tìm mã cổ phiếu...',
                      prefixIcon: Icon(Icons.search),
                    ),
                    // onChanged: trigger setModalState (local setState of sheet)
                    // KHÔNG dùng setState của màn hình cha để tránh rebuild không cần thiết
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),
                  // Danh sách candidates (chiều cao cố định để sheet không quá cao)
                  SizedBox(
                    height: 320,
                    child: candidates.isEmpty
                        ? const Center(child: Text('Không tìm thấy mã phù hợp'))
                        : ListView.separated(
                            itemCount: candidates.length,
                            separatorBuilder: (_, _) => const Divider(height: 1),
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
                                  Navigator.of(context).pop(); // Đóng sheet
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
    // Dispose controller sau khi sheet đóng (await showModalBottomSheet đã complete)
    controller.dispose();
  }

  // ---------------------------------------------------------------------------
  // _showResetDialog() — Dialog xác nhận Reset watchlist
  // ---------------------------------------------------------------------------

  /// Hiển thị AlertDialog yêu cầu xác nhận trước khi reset watchlist về mặc định.
  ///
  /// showDialog<bool>: dialog trả về bool? (true = đồng ý, false/null = hủy).
  /// `await` để chờ user chọn.
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
              // pop(false): đóng dialog và trả về false cho await
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
    // Chỉ reset nếu user nhấn Đồng ý (confirm == true)
    if (confirm == true) {
      await provider.resetToDefault();
    }
  }
}
