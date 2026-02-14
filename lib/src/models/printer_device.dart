/// Represents a discovered Bluetooth printer device.
class PrinterDevice {
  /// Platform-specific device identifier.
  /// - Android: Bluetooth MAC address (e.g. "AA:BB:CC:DD:EE:FF")
  /// - iOS: CBPeripheral UUID string
  final String id;

  /// Human-readable device name.
  final String name;

  /// Signal strength (RSSI) in dBm. May be null if not available.
  final int? rssi;

  const PrinterDevice({
    required this.id,
    required this.name,
    this.rssi,
  });

  factory PrinterDevice.fromMap(Map<String, dynamic> map) {
    return PrinterDevice(
      id: map['id'] as String,
      name: map['name'] as String,
      rssi: map['rssi'] as int?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (rssi != null) 'rssi': rssi,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PrinterDevice &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'PrinterDevice(id: $id, name: $name, rssi: $rssi)';
}
