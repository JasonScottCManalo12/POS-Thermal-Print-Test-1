import 'dart:convert';

/// Small ESC/POS command builder for the SENDA thermal-printer test.
class PrinterCommands {
  static const esc = 0x1B;
  static const gs = 0x1D;

  static List<int> initialize() => [esc, 0x40];

  static List<int> text(String value) => utf8.encode(value);

  static List<int> lineFeed([int count = 1]) => List<int>.filled(count, 0x0A);

  static List<int> bold(bool enabled) => [esc, 0x45, enabled ? 1 : 0];

  /// ESC a: 0 = left, 1 = center, 2 = right.
  static List<int> align(int value) => [esc, 0x61, value];

  /// GS !: lower nibble = height, upper nibble = width.
  /// 0 = normal; 1 = double-height; 16 = double-width; 17 = double width/height.
  static List<int> size({bool doubleWidth = false, bool doubleHeight = false}) {
    final width = doubleWidth ? 1 : 0;
    final height = doubleHeight ? 1 : 0;
    return [gs, 0x21, (height << 4) | width];
  }

  static List<int> resetStyle() => [
        ...bold(false),
        ...align(0),
        ...size(),
      ];

  static List<int> fontTestDemo() => [
        ...initialize(),
        ...align(1),
        ...bold(true),
        ...text('FONT TEST'),
        ...lineFeed(),
        ...bold(false),
        ...size(),
        ...text('Normal text'),
        ...lineFeed(),
        ...bold(true),
        ...text('Bold text'),
        ...lineFeed(),
        ...bold(false),
        ...size(doubleWidth: true),
        ...text('Double width'),
        ...lineFeed(),
        ...size(doubleHeight: true),
        ...text('Double height'),
        ...lineFeed(),
        ...size(doubleWidth: true, doubleHeight: true),
        ...text('DOUBLE BOTH'),
        ...lineFeed(),
        ...size(),
        ...align(0),
        ...text('Left aligned'),
        ...lineFeed(),
        ...align(2),
        ...text('Right aligned'),
        ...lineFeed(3),
      ];

  static List<int> formattedDemo() => [
        ...initialize(),
        ...align(1),
        ...bold(true),
        ...size(doubleWidth: true, doubleHeight: true),
        ...text('POS TEST'),
        ...lineFeed(),
        ...size(),
        ...bold(false),
        ...text('Thermal Print Test 1'),
        ...lineFeed(2),
        ...align(0),
        ...text('Item A                 P125.00'),
        ...lineFeed(),
        ...text('Item B                  P75.00'),
        ...lineFeed(),
        ...text('------------------------------'),
        ...lineFeed(),
        ...bold(true),
        ...text('TOTAL                  P200.00'),
        ...lineFeed(),
        ...bold(false),
        ...align(1),
        ...text('Thank you!'),
        ...lineFeed(3),
      ];
}
