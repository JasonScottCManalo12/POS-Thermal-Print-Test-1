import 'package:flutter/material.dart';

import 'receipt_bitmap.dart';

/// Screen preview of the exact 384-dot bitmap that will be sent to the printer.
class ReceiptPreviewScreen extends StatelessWidget {
  const ReceiptPreviewScreen({
    super.key,
    required this.receipt,
    required this.onPrint,
  });

  final ReceiptData receipt;
  final Future<void> Function() onPrint;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Receipt Preview')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'EXACT PRINTER BITMAP PREVIEW',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<int>>(
                future: ReceiptBitmap.buildPreviewPng(receipt),
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError || snapshot.data == null) {
                    return Center(
                      child: Text('Could not render preview: ${snapshot.error}'),
                    );
                  }
                  return InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 3.0,
                    child: Center(
                      child: Image.memory(
                        snapshot.data!,
                        filterQuality: FilterQuality.none,
                        gaplessPlayback: true,
                      ),
                    ),
                  );
                },
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text(
                'This preview is generated from the same 384-dot bitmap renderer used for printing.',
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onPrint,
                  icon: const Icon(Icons.print),
                  label: const Text('PRINT THIS RECEIPT'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
