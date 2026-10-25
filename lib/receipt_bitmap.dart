import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders a larger, column-aligned receipt as a monochrome ESC/POS raster.
class ReceiptBitmap {
  static const int paperWidth = 384;
  static const double margin = 8;

  static Future<List<int>> buildSampleReceipt() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    var y = 8.0;

    void drawText(
      String text, {
      double size = 21,
      bool bold = false,
      TextAlign align = TextAlign.left,
      double? width,
      double gap = 5,
    }) {
      final maxWidth = width ?? (paperWidth - margin * 2);
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: const Color(0xFF000000),
            fontSize: size,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            height: 1.12,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: align,
        maxLines: 1,
      )..layout(maxWidth: maxWidth);
      painter.paint(canvas, Offset(margin, y));
      y += painter.height + gap;
    }

    void drawSeparator() {
      final paint = Paint()
        ..color = const Color(0xFF000000)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(margin, y + 2), Offset(paperWidth - margin, y + 2), paint);
      y += 13;
    }

    void drawColumns(String item, String qty, String total, {bool bold = false, double size = 20}) {
      const itemWidth = 190.0;
      const qtyWidth = 42.0;
      const totalWidth = paperWidth - margin * 2 - itemWidth - qtyWidth;
      final style = TextStyle(
        color: const Color(0xFF000000),
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        height: 1.12,
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
      )..layout(maxWidth: qtyWidth);
      final totalPainter = TextPainter(
        text: TextSpan(text: total, style: style),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        maxLines: 1,
      )..layout(maxWidth: totalWidth);

      itemPainter.paint(canvas, Offset(margin, y));
      qtyPainter.paint(canvas, Offset(margin + itemWidth, y));
      totalPainter.paint(canvas, Offset(margin + itemWidth + qtyWidth, y));
      y += [itemPainter.height, qtyPainter.height, totalPainter.height].reduce((a, b) => a > b ? a : b) + 7;
    }

    drawText('POS THERMAL TEST', size: 29, bold: true, align: TextAlign.center, gap: 3);
    drawText('SENDA SDXP-210 · PT210A', size: 18, align: TextAlign.center, gap: 2);
    drawText('CAPSTONE RECEIPT DEMO', size: 18, bold: true, align: TextAlign.center, gap: 8);
    drawSeparator();

    drawColumns('ITEM', 'QTY', 'TOTAL', bold: true, size: 18);
    drawSeparator();
    drawColumns('Coffee', '2', '120.00', size: 22);
    drawColumns('Bread', '1', '45.00', size: 22);
    drawColumns('Milk', '1', '78.50', size: 22);
    drawSeparator();

    drawColumns('Subtotal', '', '243.50', size: 21);
    drawColumns('Discount', '', '0.00', size: 21);
    drawColumns('TOTAL', '', '243.50', bold: true, size: 27);
    drawSeparator();

    drawText('Thank you!', size: 27, bold: true, align: TextAlign.center, gap: 4);
    drawText('Bitmap receipt rendered by Flutter', size: 16, align: TextAlign.center, gap: 3);
    drawText('Keep this receipt for testing only', size: 15, align: TextAlign.center, gap: 0);

    final height = y.ceil() + 10;
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
