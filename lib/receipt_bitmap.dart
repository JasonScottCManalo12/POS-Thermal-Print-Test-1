import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// One receipt row. Prices use integer centavos to avoid floating-point money math.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.unitPriceCentavos,
  })  : assert(quantity > 0),
        assert(unitPriceCentavos >= 0);

  final String name;
  final int quantity;
  final int unitPriceCentavos;

  int get lineTotalCentavos => quantity * unitPriceCentavos;
}

/// Data-driven receipt input. Totals are calculated from the item rows.
class ReceiptData {
  const ReceiptData({
    required this.storeName,
    required this.receiptTitle,
    required this.items,
    this.discountCentavos = 0,
    this.footer = 'Thank you!',
    this.testLabel = 'TEST DATA — NOT A REAL SALE',
  }) : assert(discountCentavos >= 0);

  final String storeName;
  final String receiptTitle;
  final List<ReceiptLineItem> items;
  final int discountCentavos;
  final String footer;
  final String testLabel;

  int get subtotalCentavos =>
      items.fold(0, (sum, item) => sum + item.lineTotalCentavos);

  int get totalCentavos => subtotalCentavos - discountCentavos;

  bool get hasValidTotals =>
      items.every((item) => item.quantity > 0 && item.unitPriceCentavos >= 0) &&
      discountCentavos >= 0 &&
      discountCentavos <= subtotalCentavos;
}

/// Renders receipt data into a monochrome 384-dot bitmap for ESC/POS raster printing.
class ReceiptBitmap {
  static const int paperWidth = 384;
  static const double margin = 6;
  static const double contentWidth = paperWidth - margin * 2;

  static String money(int centavos) {
    final whole = centavos.abs() ~/ 100;
    final fraction = (centavos.abs() % 100).toString().padLeft(2, '0');
    return '${centavos < 0 ? '-' : ''}$whole.$fraction';
  }

  static ReceiptData sampleData() => const ReceiptData(
        storeName: 'POS THERMAL TEST',
        receiptTitle: 'DYNAMIC RECEIPT DEMO',
        items: [
          ReceiptLineItem(name: 'Coffee', quantity: 2, unitPriceCentavos: 6000),
          ReceiptLineItem(name: 'Bread', quantity: 1, unitPriceCentavos: 4500),
          ReceiptLineItem(name: 'Milk', quantity: 1, unitPriceCentavos: 7850),
        ],
        discountCentavos: 500,
        footer: 'Thank you!',
      );

  static Future<List<int>> buildSampleReceipt() =>
      buildReceipt(sampleData());

  static Future<List<int>> buildReceipt(ReceiptData receipt) async {
    if (!receipt.hasValidTotals) {
      throw ArgumentError('Receipt totals are invalid. Check quantities, prices, and discount.');
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    var y = 8.0;

    void drawText(
      String text, {
      double size = 25,
      bool bold = false,
      TextAlign align = TextAlign.left,
      double gap = 5,
    }) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: const Color(0xFF000000),
            fontSize: size,
            fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            height: 1.0,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: contentWidth);
      painter.paint(canvas, Offset(margin, y));
      y += painter.height + gap;
    }

    void separator({double gapAfter = 10}) {
      final paint = Paint()
        ..color = const Color(0xFF000000)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(margin, y + 2),
        Offset(paperWidth - margin, y + 2),
        paint,
      );
      y += gapAfter + 3;
    }

    void columns(
      String item,
      String qty,
      String amount, {
      double size = 25,
      bool bold = false,
    }) {
      const itemWidth = 174.0;
      const qtyWidth = 48.0;
      const amountWidth = contentWidth - itemWidth - qtyWidth;
      final style = TextStyle(
        color: const Color(0xFF000000),
        fontSize: size,
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        height: 1.0,
      );

      final itemPainter = TextPainter(
        text: TextSpan(text: item, style: style),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: itemWidth);
      final qtyPainter = TextPainter(
        text: TextSpan(text: qty, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: qtyWidth);
      final amountPainter = TextPainter(
        text: TextSpan(text: amount, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: amountWidth);

      itemPainter.paint(canvas, Offset(margin, y));
      qtyPainter.paint(canvas, Offset(margin + itemWidth, y));
      amountPainter.paint(canvas, Offset(margin + itemWidth + qtyWidth, y));
      y += [itemPainter.height, qtyPainter.height, amountPainter.height]
              .reduce((a, b) => a > b ? a : b) +
          8;
    }

    drawText(receipt.storeName, size: 34, bold: true, align: TextAlign.center, gap: 4);
    drawText('SENDA SDXP-210 · PT210A', size: 21, align: TextAlign.center, gap: 3);
    drawText(receipt.receiptTitle, size: 21, bold: true, align: TextAlign.center, gap: 8);
    separator();

    columns('ITEM', 'QTY', 'TOTAL', size: 22, bold: true);
    separator(gapAfter: 8);
    for (final item in receipt.items) {
      columns(item.name, item.quantity.toString(), money(item.lineTotalCentavos), size: 27);
    }
    separator();

    columns('Subtotal', '', money(receipt.subtotalCentavos), size: 25);
    columns('Discount', '', money(receipt.discountCentavos), size: 25);
    columns('TOTAL', '', money(receipt.totalCentavos), size: 31, bold: true);
    separator();

    drawText(receipt.footer, size: 31, bold: true, align: TextAlign.center, gap: 5);
    drawText('Flutter-rendered bitmap receipt', size: 17, align: TextAlign.center, gap: 4);
    drawText(receipt.testLabel, size: 16, bold: true, align: TextAlign.center, gap: 0);

    final height = y.ceil() + 8;
    final picture = recorder.endRecording();
    final image = await picture.toImage(paperWidth, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    if (data == null) throw Exception('Could not render receipt bitmap.');

    const bytesPerRow = paperWidth ~/ 8;
    final raster = List<int>.filled(bytesPerRow * height, 0);
    for (var py = 0; py < height; py++) {
      for (var px = 0; px < paperWidth; px++) {
        final offset = (py * paperWidth + px) * 4;
        final red = data.getUint8(offset);
        final green = data.getUint8(offset + 1);
        final blue = data.getUint8(offset + 2);
        final luminance = (red * 299 + green * 587 + blue * 114) ~/ 1000;
        if (luminance < 180) {
          raster[py * bytesPerRow + px ~/ 8] |= 0x80 >> (px % 8);
        }
      }
    }

    return [
      0x1B, 0x40,
      0x1D, 0x76, 0x30, 0x00,
      bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
      height & 0xFF, (height >> 8) & 0xFF,
      ...raster,
      ...List<int>.filled(4, 0x0A),
    ];
  }
}
