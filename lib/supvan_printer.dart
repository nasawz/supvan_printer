export 'src/models/models.dart';

import 'src/models/models.dart';
import 'supvan_printer_platform_interface.dart';

/// High-level facade for the Supvan thermal printer plugin.
///
/// Usage:
/// ```dart
/// final printer = SupvanPrinter.instance;
///
/// // Listen for discovered devices
/// printer.scanResults.listen((device) => print(device));
///
/// // Start scanning
/// await printer.startScan();
///
/// // Connect to a device
/// await printer.connect(device.id);
///
/// // Check status
/// final status = await printer.getStatus();
///
/// // Print
/// await printer.print(PrintJob(
///   labelWidth: 40,
///   labelHeight: 30,
///   pages: [
///     PrintPage(width: 40, height: 30, items: [
///       PrintItem.text(x: 5, y: 5, width: 30, height: 5, content: 'Hello'),
///     ]),
///   ],
/// ));
///
/// // Disconnect
/// await printer.disconnect();
/// ```
class SupvanPrinter {
  SupvanPrinter._();

  static final SupvanPrinter _instance = SupvanPrinter._();

  /// Singleton instance.
  static SupvanPrinter get instance => _instance;

  SupvanPrinterPlatform get _platform => SupvanPrinterPlatform.instance;

  // ---- Scanning ----

  /// Start scanning for Bluetooth printers.
  Future<void> startScan() => _platform.startScan();

  /// Stop scanning for Bluetooth printers.
  Future<void> stopScan() => _platform.stopScan();

  /// Stream of discovered printer devices.
  Stream<PrinterDevice> get scanResults => _platform.scanResults;

  // ---- Connection ----

  /// Connect to a printer by its [deviceId].
  ///
  /// On Android, if [bypassWhitelist] is true, the plugin will use reflection
  /// to bypass the SDK's internal device name whitelist check.
  Future<bool> connect(String deviceId, {bool bypassWhitelist = false}) =>
      _platform.connect(deviceId, bypassWhitelist: bypassWhitelist);

  /// Disconnect from the currently connected printer.
  Future<bool> disconnect() => _platform.disconnect();

  /// Stream of connection state changes.
  Stream<PrinterConnectionState> get connectionState => _platform.connectionState;

  // ---- Status ----

  /// Query the current printer status.
  Future<PrinterStatus> getStatus() => _platform.getStatus();

  // ---- Printing ----

  /// Submit a [PrintJob] to the connected printer.
  Future<bool> print(PrintJob job) => _platform.print(job);

  /// Cancel the current print job.
  Future<void> cancelPrint() => _platform.cancelPrint();
}
