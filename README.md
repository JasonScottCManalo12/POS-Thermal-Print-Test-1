# POS Thermal Print Test 1

A Flutter Android capstone test for a SENDA SDXP-210 / PT210A Bluetooth Classic thermal printer.

## Verified test path

- Bluetooth Classic connection to the paired printer
- Basic ESC/POS text output
- Formatted receipt and native printer-font/style commands
- Flutter-rendered monochrome bitmap output
- Custom bitmap receipt layout with item rows, subtotal, discount, total, and footer

## Build

Every push to `main` starts the **Build Android APK** GitHub Actions workflow. When it succeeds, download the artifact named `pos-thermal-print-test-1-debug-apk`.

## Important scope

This is a printer capstone test, not the Grocery Business App. The sample receipt uses hard-coded demonstration items and totals. It does not process payments, save sales, calculate tax, or represent a real transaction. The bitmap renderer targets 384 dots wide; printer firmware and paper width can affect output.
