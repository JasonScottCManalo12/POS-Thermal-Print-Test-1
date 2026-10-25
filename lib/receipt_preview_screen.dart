import 'package:flutter/material.dart';

import 'receipt_bitmap.dart';

/// Screen preview of the receipt data before sending it to the thermal printer.
class ReceiptPreviewScreen extends StatefulWidget {
  const ReceiptPreviewScreen({
    super.key,
    required this.receipt,
    required this.onPrint,
  });

  final ReceiptData receipt;
  final Future<void> Function() onPrint;

  @override
  State<ReceiptPreviewScreen> createState() => _ReceiptPreviewScreenState();
}

class _ReceiptPreviewScreenState extends State<ReceiptPreviewScreen> {
  bool _printing = false;
  String? _error;

  String _money(int centavos) => '₱${ReceiptBitmap.money(centavos)}';

  @override
  Widget build(BuildContext context) {
    final receipt = widget.receipt;
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Preview')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'PREVIEW ONLY — NOT PRINTED YET',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 360,
                      constraints: const BoxConstraints(maxWidth: 420),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 22),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black12),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 8,
                            offset: Offset(0, 3),
                          ),
                        ],
                      ),
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          color: Colors.black,
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              receipt.storeName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 5),
                            const Text('SENDA SDXP-210 · PT210A', textAlign: TextAlign.center),
                            const SizedBox(height: 5),
                            Text(
                              receipt.receiptTitle,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Divider(color: Colors.black, height: 24, thickness: 1.5),
                            const Row(
                              children: [
                                Expanded(flex: 5, child: Text('ITEM', style: TextStyle(fontWeight: FontWeight.bold))),
                                SizedBox(width: 30, child: Text('QTY', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.bold))),
                                SizedBox(width: 88, child: Text('TOTAL', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const Divider(color: Colors.black, height: 18),
                            for (final item in receipt.items)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(flex: 5, child: Text(item.name, softWrap: true)),
                                    SizedBox(width: 30, child: Text('${item.quantity}', textAlign: TextAlign.center)),
                                    SizedBox(width: 88, child: Text(ReceiptBitmap.money(item.lineTotalCentavos), textAlign: TextAlign.right)),
                                  ],
                                ),
                              ),
                            const Divider(color: Colors.black, height: 22),
                            _amountRow('Subtotal', _money(receipt.subtotalCentavos)),
                            const SizedBox(height: 5),
                            _amountRow('Discount', '-${_money(receipt.discountCentavos)}'),
                            const Divider(color: Colors.black, height: 24),
                            _amountRow('TOTAL', _money(receipt.totalCentavos), bold: true),
                            const SizedBox(height: 18),
                            Text(receipt.footer, textAlign: TextAlign.center),
                            const SizedBox(height: 12),
                            Text(receipt.testLabel, textAlign: TextAlign.center, style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'This is a screen preview of the receipt data. The printer uses a 384-dot bitmap layout, so small spacing differences may remain.',
                    textAlign: TextAlign.center,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _printing
                      ? null
                      : () async {
                          setState(() {
                            _printing = true;
                            _error = null;
                          });
                          try {
                            await widget.onPrint();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Print command sent. Check the printer.')),
                              );
                            }
                          } catch (e) {
                            if (mounted) setState(() => _error = 'Could not print: $e');
                          } finally {
                            if (mounted) setState(() => _printing = false);
                          }
                        },
                  icon: _printing
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.print),
                  label: const Text('PRINT THIS RECEIPT'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontSize: bold ? 16 : 13,
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}
