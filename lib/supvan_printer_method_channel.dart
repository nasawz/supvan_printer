import 'package:flutter/services.dart';

import 'src/models/models.dart';
import 'supvan_printer_platform_interface.dart';

/// Implementation of [SupvanPrinterPlatform] using MethodChannel + EventChannel.
class MethodChannelSupvanPrinter extends SupvanPrinterPlatform {
  static const String _channelName = 'com.supvan.printer/methods';
  static const String _scanEventChannel = 'com.supvan.printer/scan';
  static const String _connectionEventChannel =
      'com.supvan.printer/connection';

  final MethodChannel _methodChannel = const MethodChannel(_channelName);
  final EventChannel _scanChannel = const EventChannel(_scanEventChannel);
  final EventChannel _connectionChannel =
      const EventChannel(_connectionEventChannel);

  Stream<PrinterDevice>? _scanResultsStream;
  Stream<PrinterConnectionState>? _connectionStateStream;

  // ---- Scanning ----

  @override
  Future<void> startScan() async {
    await _methodChannel.invokeMethod<void>('startScan');
  }

  @override
  Future<void> stopScan() async {
    await _methodChannel.invokeMethod<void>('stopScan');
  }

  @override
  Stream<PrinterDevice> get scanResults {
    _scanResultsStream ??= _scanChannel
        .receiveBroadcastStream()
        .map((event) => PrinterDevice.fromMap(Map<String, dynamic>.from(event as Map)));
    return _scanResultsStream!;
  }

  // ---- Connection ----

  @override
  Future<bool> connect(String deviceId, {bool bypassWhitelist = false}) async {
    final result = await _methodChannel.invokeMethod<bool>('connect', {
      'deviceId': deviceId,
      'bypassWhitelist': bypassWhitelist,
    });
    return result ?? false;
  }

  @override
  Future<bool> disconnect() async {
    final result = await _methodChannel.invokeMethod<bool>('disconnect');
    return result ?? false;
  }

  @override
  Stream<PrinterConnectionState> get connectionState {
    _connectionStateStream ??= _connectionChannel
        .receiveBroadcastStream()
        .map((event) {
      final state = event as String;
      switch (state) {
        case 'connected':
          return PrinterConnectionState.connected;
        case 'connecting':
          return PrinterConnectionState.connecting;
        case 'disconnecting':
          return PrinterConnectionState.disconnecting;
        case 'disconnected':
        default:
          return PrinterConnectionState.disconnected;
      }
    });
    return _connectionStateStream!;
  }

  // ---- Status ----

  @override
  Future<PrinterStatus> getStatus() async {
    final code = await _methodChannel.invokeMethod<int>('getStatus');
    return PrinterStatus.fromCode(code ?? -1);
  }

  // ---- Printing ----

  @override
  Future<bool> print(PrintJob job) async {
    final result = await _methodChannel.invokeMethod<bool>(
      'print',
      job.toMap(),
    );
    return result ?? false;
  }

  @override
  Future<void> cancelPrint() async {
    await _methodChannel.invokeMethod<void>('cancelPrint');
  }
}
