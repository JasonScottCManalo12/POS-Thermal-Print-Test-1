import 'package:flutter/material.dart';

import 'receipt_bitmap.dart';

class _ReceiptRowControllers {
  _ReceiptRowControllers({
    String name = '',
    String quantity = '1',
    String unitPrice = '',
  })  : name = TextEditingController(text: name),
        quantity = TextEditingController(text: quantity),
        unitPrice = TextEditingController(text: unitPrice);

  final TextEditingController name;
  final TextEditingController quantity;
  final TextEditingController unitPrice;

  void dispose() {
    name.dispose();
    quantity.dispose();
    unitPrice.dispose();
  }
}

/// Lets the tester enter receipt data and send it to the existing bitmap printer.
class ReceiptBuilderScreen extends StatefulWidget {
  const ReceiptBuilderScreen({
    super.key,
    required this.onPrint,
  });

  final Future<void> Function(ReceiptData receipt) onPrint;

  @override
  State<ReceiptBuilderScreen> createState() => _ReceiptBuilderScreenState();
}

class _ReceiptBuilderScreenState extends State<ReceiptBuilderScreen> {
  final _store = TextEditingController(text: 'POS THERMAL TEST');
  final _title = TextEditingController(text: 'CUSTOM RECEIPT DEMO');
  final _discount = TextEditingController(text: '0.00');
  final List<_ReceiptRowControllers> _rows = [
    _ReceiptRowControllers(name: 'Coffee', quantity: '2', unitPrice: '60.00'),
    _ReceiptRowControllers(name: 'Bread', quantity: '1', unitPrice: '45.00'),
  ];
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _store.dispose();
    _title.dispose();
    _discount.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  int? _parseMoney(String input) {
    final value = input.trim().replaceAll(',', '');
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(value)) return null;
    final pieces = value.split('.');
    final whole = int.tryParse(pieces[0]);
    final fraction = pieces.length == 1
        ? 0
        : int.parse(pieces[1].padRight(2, '0'));
    if (whole == null) return null;
    return whole * 100 + fraction;
  }

  ReceiptData? _buildReceipt() {
    final store = _store.text.trim();
    final title = _title.text.trim();
    if (store.isEmpty || title.isEmpty) {
      _error = 'Enter a store name and receipt title.';
      return null;
    }
    if (_rows.isEmpty) {
      _error = 'Add at least one item.';
      return null;
    }

    final items = <ReceiptLineItem>[];
    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      final name = row.name.text.trim();
      final quantity = int.tryParse(row.quantity.text.trim());
      final price = _parseMoney(row.unitPrice.text);
      if (name.isEmpty || quantity == null || quantity <= 0 || price == null) {
        _error = 'Check item ${index + 1}: enter a name, positive whole quantity, and price (e.g. 12.50).';
        return null;
      }
      items.add(ReceiptLineItem(
        name: name,
        quantity: quantity,
        unitPriceCentavos: price,
      ));
    }

    final discount = _parseMoney(_discount.text);
    if (discount == null) {
      _error = 'Enter a valid discount (e.g. 0.00 or 5.50).';
      return null;
    }
    final receipt = ReceiptData(
      storeName: store,
      receiptTitle: title,
      items: items,
      discountCentavos: discount,
      footer: 'Thank you!',
    );
    if (!receipt.hasValidTotals) {
      _error = 'Discount cannot be greater than the subtotal.';
      return null;
    }
    _error = null;
    return receipt;
  }

  String _money(int centavos) => '₱${ReceiptBitmap.money(centavos)}';

  @override
  Widget build(BuildContext context) {
    final receipt = _buildReceipt();
    return Scaffold(
      appBar: AppBar(title: const Text('Build a Receipt')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('CUSTOM RECEIPT BUILDER',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            const Text(
              'Enter sample items and prices. This is a printer test, not a real sale.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _store,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Store / header name',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Receipt title',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            Text('ITEMS', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (var index = 0; index < _rows.length; index++)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text('Item ${index + 1}',
                                style: Theme.of(context).textTheme.titleSmall),
                          ),
                          IconButton(
                            tooltip: 'Remove item',
                            onPressed: _rows.length <= 1
                                ? null
                                : () {
                                    setState(() {
                                      _rows.removeAt(index).dispose();
                                    });
                                  },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      TextField(
                        controller: _rows[index].name,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Item name',
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _rows[index].quantity,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Quantity',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _rows[index].unitPrice,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Unit price (₱)',
                                border: OutlineInputBorder(),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            OutlinedButton.icon(
              onPressed: () => setState(() {
                _rows.add(_ReceiptRowControllers());
              }),
              icon: const Icon(Icons.add),
              label: const Text('ADD ITEM'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Discount (₱)',
                helperText: 'Use 0.00 when there is no discount.',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('CALCULATED TOTALS',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (receipt == null)
                      const Text('Complete the fields to calculate totals.')
                    else ...[
                      _totalRow('Subtotal', _money(receipt.subtotalCentavos)),
                      _totalRow('Discount', '-${_money(receipt.discountCentavos)}'),
                      const Divider(),
                      _totalRow('TOTAL', _money(receipt.totalCentavos), bold: true),
                    ],
                  ],
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _sending || receipt == null
                  ? null
                  : () async {
                      final validated = _buildReceipt();
                      if (validated == null) {
                        setState(() {});
                        return;
                      }
                      setState(() {
                        _sending = true;
                        _error = null;
                      });
                      try {
                        await widget.onPrint(validated);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Print command sent. Check the printer.')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _error = 'Could not print: $e');
                        }
                      } finally {
                        if (mounted) setState(() => _sending = false);
                      }
                    },
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.print),
              label: const Text('PRINT THIS RECEIPT'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 22 : 18,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
