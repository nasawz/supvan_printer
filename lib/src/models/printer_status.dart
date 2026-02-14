/// Unified printer status codes across Android and iOS.
///
/// Android SDK returns int status codes (0-8).
/// iOS SDK returns connection status as bool + error strings.
/// This enum normalizes both into a single type.
enum PrinterStatus {
  /// Printer is ready.
  ready(0, 'Ready'),

  /// Print head temperature too high.
  overheat(1, 'Print head overheated'),

  /// Cover is not closed.
  coverOpen(2, 'Cover not closed'),

  /// Material not loaded properly.
  materialNotLoaded(3, 'Material not loaded'),

  /// Material running low.
  materialLow(4, 'Material running low'),

  /// No material detected.
  materialNotDetected(5, 'No material detected'),

  /// Material not recognized.
  materialUnrecognized(6, 'Material not recognized'),

  /// Material exhausted.
  materialEmpty(7, 'Material exhausted'),

  /// Battery voltage low.
  batteryLow(8, 'Battery voltage low'),

  /// Unknown status.
  unknown(-1, 'Unknown status');

  final int code;
  final String description;

  const PrinterStatus(this.code, this.description);

  /// Create from Android integer status code.
  static PrinterStatus fromCode(int code) {
    return PrinterStatus.values.firstWhere(
      (s) => s.code == code,
      orElse: () => PrinterStatus.unknown,
    );
  }

  @override
  String toString() => 'PrinterStatus($code: $description)';
}

/// Connection state of the printer.
enum PrinterConnectionState {
  /// Not connected to any printer.
  disconnected,

  /// Connection in progress.
  connecting,

  /// Connected and ready.
  connected,

  /// Disconnecting.
  disconnecting,
}
