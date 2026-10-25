import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'printer_commands.dart';
import 'receipt_bitmap.dart';

void main() => runApp(const ThermalPrintTestApp());

class ThermalPrintTestApp extends StatelessWidget {
  const ThermalPrintTestApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'POS Thermal Print Test 1',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
        ),
        home: const PrinterTestHome(),
      );
}

class PrinterTestHome extends StatefulWidget {
  const PrinterTestHome({super.key});

  @override
  State<PrinterTestHome> createState() => _PrinterTestHomeState();
}

class _PrinterTestHomeState extends State<PrinterTestHome> {
  static const printerAddress = '86:67:7A:8C:31:89';
  final bluetooth = FlutterClassicBluetooth();

  List<BtcDevice> pairedDevices = [];
  BtcConnection? connection;
  bool loadingDevices = false;
  bool connecting = false;
  bool printing = false;
  String status = 'Not connected';
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    refreshPairedDevices();
  }

  Future<BtcPermissionStatus> ensureBluetoothPermissions() async {
    const permissions = {BtcPermission.scan, BtcPermission.connect};
    var permission = await bluetooth.checkPermissions(permissions: permissions);
    if (permission == BtcPermissionStatus.denied) {
      permission = await bluetooth.requestPermissions(permissions: permissions);
    }
    if (permission == BtcPermissionStatus.permanentlyDenied) {
      await bluetooth.openAppSettings();
    }
    return permission;
  }

  Future<void> refreshPairedDevices() async {
    setState(() {
      loadingDevices = true;
      errorMessage = null;
    });
    try {
      final permission = await ensureBluetoothPermissions();
      if (permission == BtcPermissionStatus.permanentlyDenied) {
        throw Exception('Bluetooth permission is denied. Allow Nearby devices in Android settings, then tap Refresh.');
      }
      if (permission == BtcPermissionStatus.denied) {
        throw Exception('Bluetooth permission was not granted.');
      }
      if (!await bluetooth.isEnabled()) {
        throw Exception('Turn on Bluetooth in Android settings, then tap Refresh.');
      }
      final devices = await bluetooth.getPairedDevices();
      if (!mounted) return;
      setState(() {
        pairedDevices = devices;
        status = devices.any((d) => d.address.toUpperCase() == printerAddress)
            ? 'Printer is paired — ready to test connection'
            : 'Printer MAC not found in the paired-device list';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        status = 'Could not read paired devices';
      });
    } finally {
      if (mounted) setState(() => loadingDevices = false);
    }
  }

  Future<void> connectToPrinter() async {
    if (connection != null) return;
    setState(() {
      connecting = true;
      errorMessage = null;
      status = 'Connecting to SENDA SDXP-210…';
    });
    try {
      final permission = await ensureBluetoothPermissions();
      if (permission == BtcPermissionStatus.permanentlyDenied) {
        throw Exception('Bluetooth permission is denied. Allow Nearby devices in Android settings, then try again.');
      }
      if (permission == BtcPermissionStatus.denied) {
        throw Exception('Bluetooth permission was not granted.');
      }
      final paired = pairedDevices.any((device) => device.address.toUpperCase() == printerAddress);
      if (!paired) {
        throw Exception('SENDA printer was not found in paired devices. Refresh and check Android Bluetooth settings.');
      }
      final connected = await bluetooth.connect(
        address: printerAddress,
        timeout: const Duration(seconds: 12),
      );
      if (!mounted) {
        await connected.close();
        connected.dispose();
        return;
      }
      setState(() {
        connection = connected;
        status = 'Bluetooth connection established';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        status = 'Connection failed';
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => connecting = false);
    }
  }

  Future<void> sendBytes(List<int> bytes, String successStatus) async {
    final active = connection;
    if (active == null || printing) return;
    setState(() {
      printing = true;
      errorMessage = null;
      status = 'Sending print data…';
    });
    try {
      await active.output.add(Uint8List.fromList(bytes));
      await active.output.allSent;
      if (!mounted) return;
      setState(() => status = successStatus);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        status = 'Print failed';
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  Future<List<int>> buildBitmapTest() => ReceiptBitmap.buildSampleReceipt();

  Future<void> printBitmapTest() async {
    try {
      final bytes = await buildBitmapTest();
      await sendBytes(bytes, 'Custom bitmap receipt sent — check the paper');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        status = 'Bitmap generation failed';
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> printTestReceipt() async {
    await sendBytes([
      ...PrinterCommands.initialize(),
      ...PrinterCommands.text('HELLO FROM FLUTTER!'),
      ...PrinterCommands.lineFeed(3),
    ], 'Test receipt sent — check the paper');
  }

  Future<void> printFormattedReceipt() async {
    await sendBytes(PrinterCommands.formattedDemo(), 'Formatted receipt sent — check the paper');
  }

  Future<void> printFontTest() async {
    await sendBytes(PrinterCommands.fontTestDemo(), 'Font test sent — check the paper');
  }

  Future<void> disconnectPrinter() async {
    final active = connection;
    if (active == null) return;
    setState(() {
      status = 'Disconnecting…';
      errorMessage = null;
    });
    try {
      await active.close();
      active.dispose();
      if (!mounted) return;
      setState(() {
        connection = null;
        status = 'Disconnected';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => errorMessage = e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  void dispose() {
    final active = connection;
    if (active != null) {
      active.close();
      active.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final printerFound = pairedDevices.any((device) => device.address.toUpperCase() == printerAddress);
    return Scaffold(
      appBar: AppBar(title: const Text('POS Thermal Print Test 1')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Icon(Icons.print_outlined, size: 72),
            const SizedBox(height: 16),
            Text('Bluetooth Thermal Printer Test', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text('SENDA SDXP-210 · Model PT210A', textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Card(child: ListTile(
              leading: Icon(connection == null ? Icons.bluetooth_searching : Icons.bluetooth_connected),
              title: const Text('Bluetooth connection'),
              subtitle: Text(status),
            )),
            const Card(child: ListTile(
              leading: Icon(Icons.receipt_long),
              title: Text('First print test'),
              subtitle: Text('HELLO FROM FLUTTER!'),
              trailing: Text('Next'),
            )),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loadingDevices ? null : refreshPairedDevices,
              icon: loadingDevices ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
              label: const Text('Refresh paired devices'),
            ),
            const SizedBox(height: 8),
            if (connection == null)
              FilledButton.icon(
                onPressed: (!printerFound || connecting) ? null : connectToPrinter,
                icon: connecting ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bluetooth_connected),
                label: const Text('Connect to SENDA printer'),
              )
            else ...[
              FilledButton.icon(
                onPressed: printing ? null : printTestReceipt,
                icon: const Icon(Icons.print),
                label: const Text('PRINT TEST RECEIPT'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: printing ? null : printFormattedReceipt,
                icon: const Icon(Icons.receipt_long),
                label: const Text('PRINT FORMATTED RECEIPT'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: printing ? null : printFontTest,
                icon: const Icon(Icons.format_size),
                label: const Text('PRINT FONT TEST'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: printing ? null : printBitmapTest,
                icon: const Icon(Icons.image_outlined),
                label: const Text('PRINT CUSTOM BITMAP RECEIPT'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: disconnectPrinter,
                icon: const Icon(Icons.bluetooth_disabled),
                label: const Text('Disconnect printer'),
              ),
            ],
            if (errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 20),
            Text('Paired devices (${pairedDevices.length})', style: Theme.of(context).textTheme.titleMedium),
            if (pairedDevices.isEmpty && !loadingDevices)
              const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('No paired devices were returned. Tap Refresh to try again.')),
            for (final device in pairedDevices)
              Card(child: ListTile(
                leading: Icon(device.address.toUpperCase() == printerAddress ? Icons.print : Icons.bluetooth),
                title: Text(device.displayName),
                subtitle: Text(device.address),
                trailing: device.address.toUpperCase() == printerAddress ? const Icon(Icons.check_circle, color: Colors.teal) : null,
              )),
            const SizedBox(height: 8),
            const Text(
              'The native font test exercises ESC/POS style controls. The custom receipt test lays out item rows and totals in Flutter, then sends the whole receipt as a monochrome raster image.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
