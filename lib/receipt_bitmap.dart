import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Builds a sample receipt as a monochrome ESC/POS raster-image command.
///
/// Drawing the whole receipt in Flutter gives predictable layout regardless
/// of the printer's built-in fonts. Width is 384 dots for a typical 58 mm
/// printer; verify the paper width and printable area on the target device.
class ReceiptBitmap {
  static const int paperWidth = 384;
  static const int margin = 12;

  static Future<List<int>> buildSampleReceipt() async {
    const rows = <_ReceiptRow>[
      _ReceiptRow('POS THERMAL TEST', bold: true, size: 25, centered: true),
      _ReceiptRow('SENDA SDXP-210 · PT210A', size: 16, centered: true),
      _ReceiptRow('CAPSTONE RECEIPT DEMO', size: 16, centered: true),
      _ReceiptRow('', size: 10),
      _ReceiptRow('--------------------------------'),
      _ReceiptRow('ITEM                  QTY   TOTAL', size: 16, bold: true),
      _ReceiptRow('Coffee                  2  120.00'),
      _ReceiptRow('Bread                   1   45.00'),
      _ReceiptRow('Milk                    1   78.50'),
      _ReceiptRow('--------------------------------'),
      _ReceiptRow('Subtotal                    243.50'),
      _ReceiptRow('Discount                      0.00'),
      _ReceiptRow('TOTAL                       243.50', bold: true, size: 21),
      _ReceiptRow(''),
      _ReceiptRow('Thank you!', bold: true, size: 21, centered: true),
      _ReceiptRow('Bitmap layout rendered by Flutter', size: 14, centered: true),
      _ReceiptRow(''),
    ];

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawColor(const Color(0xFFFFFFFF), BlendMode.src);
    var y = 8.0;

    for (final row in rows) {
      if (row.text.isEmpty) {
        y += row.size.toDouble() * 0.65;
        continue;
      }
      final painter = TextPainter(
        text: TextSpan(
          text: row.text,
          style: TextStyle(
            color: const Color(0xFF000000),
            fontSize: row.size.toDouble(),
            fontWeight: row.bold ? FontWeight.bold : FontWeight.normal,
            height: 1.2,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: row.centered ? TextAlign.center : TextAlign.left,
        maxLines: 1,
      )..layout(maxWidth: paperWidth - margin * 2);
      final x = row.centered ? (paperWidth - painter.width) / 2 : margin.toDouble();
      painter.paint(canvas, Offset(x, y));
      y += painter.height + 3;
    }

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
        if (luminance < 160) {
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

class _ReceiptRow {
  final String text;
  final bool bold;
  final int size;
  final bool centered;

  const _ReceiptRow(
    this.text, {
    this.bold = false,
    this.size = 18,
    this.centered = false,
  });
}
