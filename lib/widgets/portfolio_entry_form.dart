import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/portfolio.dart';
import '../state/watchlist_provider.dart';
import '../state/portfolio_provider.dart';
import '../services/yahoo_finance_service.dart';

class PortfolioEntryForm extends StatefulWidget {
  final PortfolioItem? initialItem;

  const PortfolioEntryForm({super.key, this.initialItem});

  @override
  State<PortfolioEntryForm> createState() => _PortfolioEntryFormState();
}

class _PortfolioEntryFormState extends State<PortfolioEntryForm> {
  final _formKey = GlobalKey<FormState>();
  late String _symbol;
  late int _quantity;
  late final TextEditingController _priceController;
  bool _isFetchingPrice = false;

  @override
  void initState() {
    super.initState();
    _symbol = widget.initialItem?.symbol ?? '';
    _quantity = widget.initialItem?.quantity ?? 0;
    final initialPrice = widget.initialItem?.averagePrice ?? 0;
    _priceController = TextEditingController(
      text: initialPrice == 0 ? '' : initialPrice.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _onSymbolChanged(String? value) async {
    if (value == null || value == _symbol) return;

    setState(() {
      _symbol = value;
      _isFetchingPrice = true;
    });

    try {
      final stock = await YahooFinanceService.instance.fetchSingleQuote(value);
      if (stock != null && mounted) {
        setState(() {
          _priceController.text = stock.price.toStringAsFixed(0);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingPrice = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final watchlistProvider = Provider.of<WatchlistProvider>(context);
    final availableSymbols = watchlistProvider.availableSymbols;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.initialItem == null ? 'Thêm đầu tư mới' : 'Chỉnh sửa đầu tư',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Dropdown chọn mã
            DropdownButtonFormField<String>(
              isExpanded: true,
              value: _symbol.isEmpty ? null : _symbol,
              decoration: const InputDecoration(
                labelText: 'Mã cổ phiếu',
                border: OutlineInputBorder(),
              ),
              items: availableSymbols.map((s) {
                return DropdownMenuItem(
                  value: s.displaySymbol,
                  child: Text(
                    '${s.displaySymbol} - ${s.companyName}',
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: widget.initialItem != null ? null : _onSymbolChanged,
              validator: (value) => value == null ? 'Vui lòng chọn mã' : null,
            ),
            const SizedBox(height: 16),

            // Số lượng
            TextFormField(
              initialValue: _quantity == 0 ? '' : _quantity.toString(),
              decoration: const InputDecoration(
                labelText: 'Số lượng',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Nhập số lượng';
                final n = int.tryParse(value);
                if (n == null || n <= 0) return 'Số lượng phải > 0';
                return null;
              },
              onSaved: (value) => _quantity = int.parse(value!),
            ),
            const SizedBox(height: 16),

            // Giá vốn
            TextFormField(
              controller: _priceController,
              decoration: InputDecoration(
                labelText: 'Giá vốn (đ)',
                border: const OutlineInputBorder(),
                suffixIcon: _isFetchingPrice
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) return 'Nhập giá vốn';
                final n = double.tryParse(value);
                if (n == null || n <= 0) return 'Giá phải > 0';
                return null;
              },
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _formKey.currentState!.save();
                    Navigator.pop(context, {
                      'symbol': _symbol,
                      'quantity': _quantity,
                      'price': double.tryParse(_priceController.text) ?? 0,
                    });
                }
              },
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.all(16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: const Text('Lưu thay đổi'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
