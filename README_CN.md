# supvan_printer

Supvan 热敏打印机的 Flutter 插件（T50 / T50Plus / T50Pro）。

通过 Platform Channels 封装了原生 Supvan Android SDK (`supvan.jar`) 和 iOS SDK (`SFPrintSDK.xcframework`)，提供统一的 Dart API：

- 蓝牙设备扫描
- 打印机连接/断开
- 打印机状态查询
- 打印文本、条形码（CODE_128）、二维码和图片

## 快速开始

### 安装

添加到你的 `pubspec.yaml`：

```yaml
dependencies:
  supvan_printer:
    path: ../supvan_printer   # 或者发布到 pub.dev / git
```

### Android 配置

1. **最低 SDK 版本**：插件要求 `minSdk 24`（Android 7.0+）。

   在你的应用 `android/app/build.gradle.kts` 中：
   ```kotlin
   defaultConfig {
       minSdk = 24
   }
   ```

2. **权限**：插件在自己的 `AndroidManifest.xml` 中声明了所有必需的蓝牙权限。你的应用无需额外的 manifest 更改。

3. **运行时权限**：在扫描之前，你必须在运行时请求蓝牙和位置权限。建议使用 [`permission_handler`](https://pub.dev/packages/permission_handler) 包。

### iOS 配置

1. **最低部署目标**：iOS 13.0+。

2. **Info.plist**：在你的应用 `ios/Runner/Info.plist` 中添加蓝牙使用说明：

   ```xml
   <key>NSBluetoothAlwaysUsageDescription</key>
   <string>此应用使用蓝牙连接热敏打印机。</string>
   <key>NSBluetoothPeripheralUsageDescription</key>
   <string>此应用使用蓝牙连接热敏打印机。</string>
   ```

## 使用方法

### 快速示例

```dart
import 'package:supvan_printer/supvan_printer.dart';

final printer = SupvanPrinter.instance;

// 1. 监听发现的设备
printer.scanResults.listen((device) {
  print('发现: ${device.name} (${device.id})');
});

// 2. 监听连接状态变化
printer.connectionState.listen((state) {
  print('连接状态: $state');
});

// 3. 开始扫描
await printer.startScan();

// 4. 连接设备（发现后）
await printer.connect(device.id);
// 在 Android 上，如果 SDK 拒绝设备名称，使用：
// await printer.connect(device.id, bypassWhitelist: true);

// 5. 查询打印机状态
final status = await printer.getStatus();
print(status); // PrinterStatus.ready 等

// 6. 打印
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

// 7. 断开连接
await printer.disconnect();
```

### 打印图片

```dart
import 'dart:typed_data';

// 加载图片字节（PNG 格式）
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

## API 参考

### SupvanPrinter

| 方法 | 描述 |
|---|---|
| `startScan()` | 开始蓝牙设备扫描 |
| `stopScan()` | 停止扫描 |
| `scanResults` | 发现的 `PrinterDevice` 流 |
| `connect(deviceId, {bypassWhitelist})` | 连接打印机 |
| `disconnect()` | 断开当前打印机 |
| `connectionState` | `PrinterConnectionState` 流 |
| `getStatus()` | 查询打印机状态 |
| `print(PrintJob)` | 提交打印任务 |
| `cancelPrint()` | 取消当前打印（仅 iOS） |

### PrinterStatus

| 状态 | 代码 | 描述 |
|---|---|---|
| `ready` | 0 | 打印机就绪 |
| `overheat` | 1 | 打印头过热 |
| `coverOpen` | 2 | 机盖未关闭 |
| `materialNotLoaded` | 3 | 未装载耗材 |
| `materialLow` | 4 | 耗材不足 |
| `materialNotDetected` | 5 | 未检测到耗材 |
| `materialUnrecognized` | 6 | 耗材无法识别 |
| `materialEmpty` | 7 | 耗材已耗尽 |
| `batteryLow` | 8 | 电池电压过低 |

### PrintItem 类型

| 类型 | 格式字符串 | 描述 |
|---|---|---|
| `PrintItem.text()` | TEXT | 纯文本 |
| `PrintItem.barcode()` | CODE_128 | CODE_128 条形码 |
| `PrintItem.qrCode()` | QR_CODE | 二维码 |
| `PrintItem.image()` | IMAGE | 位图图片 |

### PrintJob 参数

| 参数 | 类型 | 默认值 | 描述 |
|---|---|---|---|
| `labelWidth` | int | 必填 | 标签宽度（mm） |
| `labelHeight` | int | 必填 | 标签高度（mm） |
| `copies` | int | 1 | 打印份数（1-99） |
| `density` | int | 3 | 打印浓度（1-9） |
| `rotate` | int | 0 | 旋转（0=0°, 1=90°, 2=180°, 3=270°） |
| `horizontalOffset` | int | 0 | 水平偏移（-9 到 9） |
| `verticalOffset` | int | 0 | 垂直偏移（-9 到 9） |
| `paperType` | PaperType | gap | 纸张类型 |
| `gap` | int | 3 | 标签间距（mm，0-8） |
| `oneByOne` | bool | true | 逐份打印 |
| `tailLength` | int | 0 | 尾部留白（mm） |

## 平台差异

| 功能 | Android | iOS |
|---|---|---|
| 设备 ID | 蓝牙 MAC 地址 | CBPeripheral UUID |
| 条形码打印 | 支持（CODE_128） | 取决于 SDK 版本 |
| 二维码打印 | 支持 | 取决于 SDK 版本 |
| 图片打印 | 支持（Bitmap） | 支持（UIImage） |
| 取消打印 | 无操作 | 支持 |
| 白名单绕过 | 通过反射支持 | 不适用 |
| 状态码 | 完整（0-8） | 仅已连接/未连接 |

## 故障排除

### Android：设备无法连接
- 确保运行时已授予蓝牙和位置权限。
- 如果 SDK 拒绝设备，尝试 `connect(id, bypassWhitelist: true)`。
- 连接前停止扫描（`stopScan()` 然后 `connect()`）。

### iOS：未发现设备
- 检查蓝牙在设置中是否已启用。
- 验证 `NSBluetoothAlwaysUsageDescription` 是否在 Info.plist 中。
- SDK 内部会过滤设备；确保打印机处于配对模式。

### 两者：打印静默失败
- 先使用 `getStatus()` 查询状态，检查耗材/机盖问题。
- 确保标签尺寸与实际装载的耗材匹配。
