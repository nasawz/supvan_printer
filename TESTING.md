# Device Validation Checklist

Run the example app on real devices with a physical Supvan printer.

## Prerequisites

- [ ] Supvan T50/T50Plus/T50Pro printer powered on
- [ ] Label material loaded
- [ ] Android device (API 24+) with Bluetooth
- [ ] iOS device (iOS 13+) with Bluetooth
- [ ] Bluetooth and location permissions granted

## Test Matrix

### Android

| Test Case | Steps | Expected | Pass? |
|---|---|---|---|
| Scan | Tap "Scan" button | Printer appears in device list | |
| Connect | Tap device in list | Status bar shows "Connected: [name]" | |
| Connect (bypass) | If normal connect fails, bypassWhitelist=true is used | Connection succeeds | |
| Status query | Tap "Status" button | Shows "PrinterStatus(0: Ready)" | |
| Print text | Tap "Print Test" | Label prints with "SUPVAN" text | |
| Print barcode | Included in test job | CODE_128 barcode prints | |
| Print QR code | Included in test job | QR code prints | |
| Disconnect | Tap disconnect icon | Status bar shows "Not connected" | |
| Re-scan after disconnect | Tap "Scan" again | Devices rediscovered | |

### iOS

| Test Case | Steps | Expected | Pass? |
|---|---|---|---|
| Scan | Tap "Scan" button | Printer appears in device list | |
| Connect | Tap device in list | Status bar shows "Connected: [name]" | |
| Status query | Tap "Status" button | Shows "PrinterStatus(0: Ready)" | |
| Print text | Tap "Print Test" | Label prints with "SUPVAN" text | |
| Cancel print | Call cancelPrint during print | Print stops | |
| Disconnect | Tap disconnect icon | Status bar shows "Not connected" | |

### Edge Cases

| Test Case | Steps | Expected | Pass? |
|---|---|---|---|
| Scan with BT off | Disable Bluetooth, tap Scan | Error or empty list | |
| Connect timeout | Power off printer, try connect | Failure callback received | |
| Print when disconnected | Disconnect, try print | Error message shown | |
| Multiple copies | Set copies=3 in PrintJob | 3 labels printed | |
| Density range | Test density 1 and 9 | Visible difference in print darkness | |

## Compatibility Matrix

| Platform | Min Version | Tested Version | Device Model | Result |
|---|---|---|---|---|
| Android | API 24 | | | |
| iOS | 13.0 | | | |

## Notes

- Record any issues, workarounds, or observations here.
- If the Android SDK rejects a device name, the plugin's `bypassWhitelist` parameter handles it via reflection.
- iOS status query only returns connected/disconnected (no detailed status codes like Android).
