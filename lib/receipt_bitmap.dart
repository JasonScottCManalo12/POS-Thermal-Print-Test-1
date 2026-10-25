import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders a bold, full-width 384-dot receipt for the SENDA printer test.
class ReceiptBitmap {
  static const int paperWidth = 384;
  static const double margin = 6;
  static const double contentWidth = paperWidth - margin * 2;

  static Future<List<int>> buildSampleReceipt() async {
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

    // Fixed column anchors prevent spacing characters and proportional fonts
    // from causing apparent alignment drift.
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

    drawText('POS THERMAL TEST', size: 34, bold: true, align: TextAlign.center, gap: 4);
    drawText('SENDA SDXP-210 · PT210A', size: 21, align: TextAlign.center, gap: 3);
    drawText('CAPSTONE RECEIPT DEMO', size: 21, bold: true, align: TextAlign.center, gap: 8);
    separator();

    columns('ITEM', 'QTY', 'TOTAL', size: 22, bold: true);
    separator(gapAfter: 8);
    columns('Coffee', '2', '120.00', size: 27);
    columns('Bread', '1', '45.00', size: 27);
    columns('Milk', '1', '78.50', size: 27);
    separator();

    columns('Subtotal', '', '243.50', size: 25);
    columns('Discount', '', '0.00', size: 25);
    columns('TOTAL', '', '243.50', size: 31, bold: true);
    separator();

    drawText('Thank you!', size: 31, bold: true, align: TextAlign.center, gap: 5);
    drawText('Bitmap receipt rendered by Flutter', size: 17, align: TextAlign.center, gap: 4);
    drawText('TEST DATA — NOT A REAL SALE', size: 16, bold: true, align: TextAlign.center, gap: 0);

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
