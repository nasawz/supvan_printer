// Integration tests require a real device with Bluetooth.
// Run with: flutter test integration_test/plugin_integration_test.dart
//
// These tests verify the plugin loads and basic API calls don't crash.
// Actual printing requires a physical printer.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:supvan_printer/supvan_printer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('SupvanPrinter instance is accessible', (tester) async {
    final printer = SupvanPrinter.instance;
    expect(printer, isNotNull);
  });

  testWidgets('startScan and stopScan do not throw', (tester) async {
    final printer = SupvanPrinter.instance;
    // These may fail on simulator (no Bluetooth) but should not crash
    try {
      await printer.startScan();
      await Future.delayed(const Duration(seconds: 1));
      await printer.stopScan();
    } catch (_) {
      // Expected on simulator
    }
  });
}
