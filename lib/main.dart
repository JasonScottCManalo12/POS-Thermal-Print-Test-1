import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_classic_bluetooth/flutter_classic_bluetooth.dart';
import 'printer_commands.dart';

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

  Future<List<int>> buildBitmapTest() async {
    // Render Flutter text to a 384-dot monochrome bitmap (typical 58 mm width).
    const width = 384;
    const height = 160;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Paint()..color = const Color(0xFFFFFFFF),
    );

    final painter = TextPainter(
      text: const TextSpan(
        style: TextStyle(color: Color(0xFF000000), fontSize: 25, height: 1.35),
        children: [
          TextSpan(text: 'BITMAP PRINT TEST\\n', style: TextStyle(fontWeight: FontWeight.bold)),
          TextSpan(text: 'Flutter-rendered text\\n'),
          TextSpan(text: 'Custom fonts and layout\\n'),
          TextSpan(text: '0123456789  ABC xyz'),
        ],
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: width - 16);
    painter.paint(canvas, Offset((width - painter.width) / 2, 12));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    picture.dispose();
    if (data == null) throw Exception('Could not convert Flutter text to bitmap.');

    const bytesPerRow = width ~/ 8;
    final raster = List<int>.filled(bytesPerRow * height, 0);
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final offset = (y * width + x) * 4;
        final red = data.getUint8(offset);
        final green = data.getUint8(offset + 1);
        final blue = data.getUint8(offset + 2);
        final luminance = (red * 299 + green * 587 + blue * 114) ~/ 1000;
        if (luminance < 160) {
          raster[y * bytesPerRow + x ~/ 8] |= 0x80 >> (x % 8);
        }
      }
    }

    // ESC/POS GS v 0: raster bit image. Printer firmware support varies.
    return [
      ...PrinterCommands.initialize(),
      0x1D, 0x76, 0x30, 0x00,
      bytesPerRow & 0xFF, (bytesPerRow >> 8) & 0xFF,
      height & 0xFF, (height >> 8) & 0xFF,
      ...raster,
      ...PrinterCommands.lineFeed(4),
    ];
  }

  Future<void> printBitmapTest() async {
    try {
      final bytes = await buildBitmapTest();
      await sendBytes(bytes, 'Bitmap test sent — check the paper');
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
                label: const Text('PRINT BITMAP FONT TEST'),
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
              'The native font test exercises ESC/POS style controls. The bitmap test renders text in Flutter and sends a monochrome raster image; support for the raster command depends on printer firmware.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
