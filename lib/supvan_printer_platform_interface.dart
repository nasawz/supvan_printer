import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'src/models/models.dart';
import 'supvan_printer_method_channel.dart';

abstract class SupvanPrinterPlatform extends PlatformInterface {
  SupvanPrinterPlatform() : super(token: _token);

  static final Object _token = Object();

  static SupvanPrinterPlatform _instance = MethodChannelSupvanPrinter();

  static SupvanPrinterPlatform get instance => _instance;

  static set instance(SupvanPrinterPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  // ---- Scanning ----

  /// Start scanning for Bluetooth printers.
  Future<void> startScan() {
    throw UnimplementedError('startScan() has not been implemented.');
  }

  /// Stop scanning for Bluetooth printers.
  Future<void> stopScan() {
    throw UnimplementedError('stopScan() has not been implemented.');
  }

  /// Stream of discovered devices during scanning.
  Stream<PrinterDevice> get scanResults {
    throw UnimplementedError('scanResults has not been implemented.');
  }

  // ---- Connection ----

  /// Connect to a printer by device id.
  /// [bypassWhitelist] (Android only) uses reflection to bypass SDK device
  /// name whitelist check.
  Future<bool> connect(String deviceId, {bool bypassWhitelist = false}) {
    throw UnimplementedError('connect() has not been implemented.');
  }

  /// Disconnect from the current printer.
  Future<bool> disconnect() {
    throw UnimplementedError('disconnect() has not been implemented.');
  }

  /// Stream of connection state changes.
  Stream<PrinterConnectionState> get connectionState {
    throw UnimplementedError('connectionState has not been implemented.');
  }

  // ---- Status ----

  /// Get current printer status.
  Future<PrinterStatus> getStatus() {
    throw UnimplementedError('getStatus() has not been implemented.');
  }

  // ---- Printing ----

  /// Submit a print job.
  Future<bool> print(PrintJob job) {
    throw UnimplementedError('print() has not been implemented.');
  }

  /// Cancel the current print job (iOS only, no-op on Android).
  Future<void> cancelPrint() {
    throw UnimplementedError('cancelPrint() has not been implemented.');
  }
}
