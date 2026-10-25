import 'package:flutter/material.dart';

void main() {
  runApp(const ThermalPrintTestApp());
}

class ThermalPrintTestApp extends StatelessWidget {
  const ThermalPrintTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'POS Thermal Print Test 1',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const PrinterTestHome(),
    );
  }
}

class PrinterTestHome extends StatelessWidget {
  const PrinterTestHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('POS Thermal Print Test 1')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.print_outlined, size: 72),
            const SizedBox(height: 16),
            Text(
              'Bluetooth Thermal Printer Test',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            const Text(
              'SENDA SDXP-210 · Model PT210A',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            const Card(
              child: ListTile(
                leading: Icon(Icons.bluetooth_searching),
                title: Text('Bluetooth connection'),
                subtitle: Text('Not connected — connection test is next'),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long),
                title: Text('First print test'),
                subtitle: Text('HELLO FROM FLUTTER!'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'This starter build does not initiate Bluetooth connections or send print data yet. '
              'Pair the printer in Android Bluetooth settings before the connection milestone.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
