import 'package:flutter_test/flutter_test.dart';
import 'package:pos_thermal_print_test_1/main.dart';

void main() {
  testWidgets('shows the thermal printer test screen', (tester) async {
    await tester.pumpWidget(const ThermalPrintTestApp());

    expect(find.text('POS Thermal Print Test 1'), findsOneWidget);
    expect(find.text('SENDA SDXP-210 · Model PT210A'), findsOneWidget);
    expect(find.text('HELLO FROM FLUTTER!'), findsOneWidget);
  });
}
