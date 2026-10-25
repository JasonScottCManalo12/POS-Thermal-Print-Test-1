import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';

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

      final paired = pairedDevices.any(
        (device) => device.address.toUpperCase() == printerAddress,
      );
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

  Future<void> printTestReceipt() async {
    final active = connection;
    if (active == null || printing) return;

    setState(() {
      printing = true;
      errorMessage = null;
      status = 'Sending test receipt…';
    });

    try {
      // Basic ESC/POS sequence: initialize, print text, feed paper.
      // No cutter command is sent because this portable printer may not have a cutter.
      final bytes = <int>[
        0x1B, 0x40, // ESC @ — initialize printer
        ...'HELLO FROM FLUTTER!'.codeUnits,
        0x0A,
        0x0A,
        0x0A,
      ];

      await active.output.add(Uint8List.fromList(bytes));
      await active.output.allSent;

      if (!mounted) return;
      setState(() {
        status = 'Test receipt sent — check the paper';
      });
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
      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
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
    final printerFound = pairedDevices.any(
      (device) => device.address.toUpperCase() == printerAddress,
    );

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
            Card(
              child: ListTile(
                leading: Icon(
                  connection == null ? Icons.bluetooth_searching : Icons.bluetooth_connected,
                ),
                title: const Text('Bluetooth connection'),
                subtitle: Text(status),
              ),
            ),
            const Card(
              child: ListTile(
                leading: Icon(Icons.receipt_long),
                title: Text('First print test'),
                subtitle: Text('HELLO FROM FLUTTER!'),
                trailing: Text('Next'),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loadingDevices ? null : refreshPairedDevices,
              icon: loadingDevices
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Refresh paired devices'),
            ),
            const SizedBox(height: 8),
            if (connection == null)
              FilledButton.icon(
                onPressed: (!printerFound || connecting) ? null : connectToPrinter,
                icon: connecting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.bluetooth_connected),
                label: const Text('Connect to SENDA printer'),
              )
            else ...[
              FilledButton.icon(
                onPressed: printing ? null : printTestReceipt,
                icon: printing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: const Text('PRINT TEST RECEIPT'),
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
            Text('Paired devices (${pairedDevices.length})',
                style: Theme.of(context).textTheme.titleMedium),
            if (pairedDevices.isEmpty && !loadingDevices)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('No paired devices were returned. Tap Refresh to try again.'),
              ),
            for (final device in pairedDevices)
              Card(
                child: ListTile(
                  leading: Icon(
                    device.address.toUpperCase() == printerAddress
                        ? Icons.print
                        : Icons.bluetooth,
                  ),
                  title: Text(device.displayName),
                  subtitle: Text(device.address),
                  trailing: device.address.toUpperCase() == printerAddress
                      ? const Icon(Icons.check_circle, color: Colors.teal)
                      : null,
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'This milestone sends a minimal ESC/POS test sequence after Bluetooth connection. '
              'It does not send GCash, payment, or transaction data.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
