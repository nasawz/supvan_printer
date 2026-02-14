# supvan_printer

Flutter plugin for Supvan thermal printers (T50 / T50Plus / T50Pro).

Wraps the native Supvan Android SDK (`supvan.jar`) and iOS SDK (`SFPrintSDK.xcframework`) via Platform Channels, providing a unified Dart API for:

- Bluetooth device scanning
- Printer connection / disconnection
- Printer status query
- Printing text, barcodes (CODE_128), QR codes, and images

## Getting Started

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  supvan_printer:
    path: ../supvan_printer   # or publish to pub.dev / git
```

### Android Setup

1. **Minimum SDK**: The plugin requires `minSdk 24` (Android 7.0+).

   In your app's `android/app/build.gradle.kts`:
   ```kotlin
   defaultConfig {
       minSdk = 24
   }
   ```

2. **Permissions**: The plugin declares all required Bluetooth permissions in its own `AndroidManifest.xml`. No additional manifest changes needed in your app.

3. **Runtime permissions**: You must request Bluetooth and location permissions at runtime before scanning. Consider using the [`permission_handler`](https://pub.dev/packages/permission_handler) package.

### iOS Setup

1. **Minimum deployment target**: iOS 13.0+.

2. **Info.plist**: Add Bluetooth usage descriptions to your app's `ios/Runner/Info.plist`:

   ```xml
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>This app uses Bluetooth to connect to thermal printers.</string>
   <key>NSBluetoothPeripheralUsageDescription</key>
   <string>This app uses Bluetooth to connect to thermal printers.</string>
   ```

## Usage

### Quick Start

```dart
import 'package:supvan_printer/supvan_printer.dart';

final printer = SupvanPrinter.instance;

// 1. Listen for discovered devices
printer.scanResults.listen((device) {
  print('Found: ${device.name} (${device.id})');
});

// 2. Listen for connection state changes
printer.connectionState.listen((state) {
  print('Connection: $state');
});

// 3. Start scanning
await printer.startScan();

// 4. Connect to a device (after discovery)
await printer.connect(device.id);
// On Android, if the SDK rejects the device name, use:
// await printer.connect(device.id, bypassWhitelist: true);

// 5. Query printer status
final status = await printer.getStatus();
print(status); // PrinterStatus.ready, etc.

// 6. Print
await printer.print(PrintJob(
  labelWidth: 40,
  labelHeight: 30,
  copies: 1,
  density: 4,
  gap: 6,
  pages: [
    PrintPage(width: 40, height: 30, items: [
      PrintItem.text(
        x: 6, y: 5, width: 10, height: 2,
        content: 'Hello World',
        fontSize: 3,
      ),
      PrintItem.barcode(
        x: 1, y: 10, width: 23, height: 3,
        content: '123456',
      ),
      PrintItem.qrCode(
        x: 4, y: 15, width: 6, height: 6,
        content: 'https://example.com',
      ),
    ]),
  ],
));

// 7. Disconnect
await printer.disconnect();
```

### Printing Images

```dart
import 'dart:typed_data';

// Load image bytes (PNG format)
final Uint8List imageBytes = await loadImageBytes();

await printer.print(PrintJob(
  labelWidth: 40,
  labelHeight: 30,
  pages: [
    PrintPage(width: 40, height: 30, items: [
      PrintItem.image(
        x: 3, y: 3, width: 10, height: 10,
        imageBytes: imageBytes,
      ),
    ]),
  ],
));
```

## API Reference

### SupvanPrinter

| Method | Description |
|---|---|
| `startScan()` | Start Bluetooth device scanning |
| `stopScan()` | Stop scanning |
| `scanResults` | Stream of discovered `PrinterDevice` |
| `connect(deviceId, {bypassWhitelist})` | Connect to a printer |
| `disconnect()` | Disconnect from current printer |
| `connectionState` | Stream of `PrinterConnectionState` |
| `getStatus()` | Query printer status |
| `print(PrintJob)` | Submit a print job |
| `cancelPrint()` | Cancel current print (iOS only) |

### PrinterStatus

| Status | Code | Description |
|---|---|---|
| `ready` | 0 | Printer ready |
| `overheat` | 1 | Print head overheated |
| `coverOpen` | 2 | Cover not closed |
| `materialNotLoaded` | 3 | Material not loaded |
| `materialLow` | 4 | Material running low |
| `materialNotDetected` | 5 | No material detected |
| `materialUnrecognized` | 6 | Material not recognized |
| `materialEmpty` | 7 | Material exhausted |
| `batteryLow` | 8 | Battery voltage low |

### PrintItem Types

| Type | Format String | Description |
|---|---|---|
| `PrintItem.text()` | TEXT | Plain text |
| `PrintItem.barcode()` | CODE_128 | CODE_128 barcode |
| `PrintItem.qrCode()` | QR_CODE | QR code |
| `PrintItem.image()` | IMAGE | Bitmap image |

### PrintJob Parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `labelWidth` | int | required | Label width in mm |
| `labelHeight` | int | required | Label height in mm |
| `copies` | int | 1 | Number of copies (1-99) |
| `density` | int | 3 | Print density (1-9) |
| `rotate` | int | 0 | Rotation (0=0, 1=90, 2=180, 3=270) |
| `horizontalOffset` | int | 0 | Horizontal offset (-9 to 9) |
| `verticalOffset` | int | 0 | Vertical offset (-9 to 9) |
| `paperType` | PaperType | gap | Paper type |
| `gap` | int | 3 | Gap between labels in mm (0-8) |
| `oneByOne` | bool | true | Collated printing |
| `tailLength` | int | 0 | Tail length in mm |

## Platform Differences

| Feature | Android | iOS |
|---|---|---|
| Device ID | Bluetooth MAC address | CBPeripheral UUID |
| Barcode printing | Supported (CODE_128) | Depends on SDK version |
| QR code printing | Supported | Depends on SDK version |
| Image printing | Supported (Bitmap) | Supported (UIImage) |
| Cancel print | No-op | Supported |
| Whitelist bypass | Supported via reflection | N/A |
| Status codes | Full (0-8) | Connected/Disconnected only |

## Troubleshooting

### Android: Device not connecting
- Ensure Bluetooth and location permissions are granted at runtime.
- If the SDK rejects the device, try `connect(id, bypassWhitelist: true)`.
- Stop scanning before connecting (`stopScan()` then `connect()`).

### iOS: No devices found
- Check that Bluetooth is enabled in Settings.
- Verify `NSBluetoothAlwaysUsageDescription` is in Info.plist.
- The SDK filters devices internally; ensure the printer is in pairing mode.

### Both: Print fails silently
- Query status first with `getStatus()` to check for material/cover issues.
- Ensure the label dimensions match the actual loaded material.
