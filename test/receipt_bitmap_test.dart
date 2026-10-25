import 'package:flutter_test/flutter_test.dart';
import 'package:pos_thermal_print_test_1/receipt_bitmap.dart';

void main() {
  group('ReceiptData', () {
    test('calculates line totals, subtotal, discount, and final total', () {
      final receipt = ReceiptBitmap.sampleData();

      expect(receipt.items.map((item) => item.lineTotalCentavos).toList(),
          [12000, 4500, 7850]);
      expect(receipt.subtotalCentavos, 24350);
      expect(receipt.discountCentavos, 500);
      expect(receipt.totalCentavos, 23850);
      expect(receipt.hasValidTotals, isTrue);
    });

    test('formats centavos without floating-point rounding', () {
      expect(ReceiptBitmap.money(0), '0.00');
      expect(ReceiptBitmap.money(7850), '78.50');
      expect(ReceiptBitmap.money(5), '0.05');
      expect(ReceiptBitmap.money(-125), '-1.25');
    });

    test('rejects a discount greater than the subtotal', () {
      const receipt = ReceiptData(
        storeName: 'Test',
        receiptTitle: 'Test',
        items: [
          ReceiptLineItem(name: 'Item', quantity: 1, unitPriceCentavos: 100),
        ],
        discountCentavos: 101,
      );

      expect(receipt.hasValidTotals, isFalse);
    });
  });
}
