# 打印图片使用说明

本文档介绍如何使用 `supvan_printer` 插件打印图片。

## 前置条件

1. 已完成蓝牙设备扫描和连接（参考 [README_CN.md](README_CN.md)）
2. 图片数据需要转换为 PNG 格式的 `Uint8List` 字节

## 基本用法

```dart
import 'package:supvan_printer/supvan_printer.dart';
import 'dart:typed_data';

final printer = SupvanPrinter.instance;

// 假设已连接打印机...

// 打印图片
await printer.print(PrintJob(
  labelWidth: 40,    // 标签宽度（mm）
  labelHeight: 30,   // 标签高度（mm）
  pages: [
    PrintPage(
      width: 40,
      height: 30,
      items: [
        PrintItem.image(
          x: 3,              // X 坐标（mm）
          y: 3,              // Y 坐标（mm）
          width: 10,         // 图片宽度（mm）
          height: 10,        // 图片高度（mm）
          imageBytes: imageBytes,  // PNG 格式字节
        ),
      ],
    ),
  ],
));
```

## 加载图片字节

### 从资源文件加载

1. 在 `pubspec.yaml` 中声明资源：

```yaml
flutter:
  assets:
    - assets/images/logo.png
```

2. 加载图片：

```dart
import 'package:flutter/services.dart';

Future<Uint8List> loadAssetImage() async {
  final ByteData data = await rootBundle.load('assets/images/logo.png');
  return data.buffer.asUint8List();
}
```

### 从网络加载

使用 `http` 或 `dio` 包：

```dart
import 'package:http/http.dart' as http;

Future<Uint8List?> loadNetworkImage(String url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return response.bodyBytes;
  }
  return null;
}
```

### 从本地文件加载

```dart
import 'dart:io';

Future<Uint8List> loadLocalImage(String path) async {
  final file = File(path);
  return await file.readAsBytes();
}
```

### 使用 image_picker 选择图片

```dart
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> pickImage() async {
  final picker = ImagePicker();
  final XFile? image = await picker.pickImage(source: ImageSource.gallery);
  if (image != null) {
    return await image.readAsBytes();
  }
  return null;
}
```

## 图片处理

### 缩放图片

使用 `image` 包处理图片：

```yaml
dependencies:
  image: ^4.0.0
```

```dart
import 'package:image/image.dart' as img;

Future<Uint8List> resizeImage(Uint8List bytes, int width, int height) async {
  final image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');
  
  final resized = img.copyResize(image, width: width, height: height);
  return Uint8List.fromList(img.encodePng(resized));
}
```

### 转换为灰度

```dart
Future<Uint8List> toGrayscale(Uint8List bytes) async {
  final image = img.decodeImage(bytes);
  if (image == null) throw Exception('Failed to decode image');
  
  final grayscale = img.grayscale(image);
  return Uint8List.fromList(img.encodePng(grayscale));
}
```

## 完整示例

```dart
import 'package:flutter/material.dart';
import 'package:supvan_printer/supvan_printer.dart';
import 'package:flutter/services.dart';

class ImagePrintPage extends StatefulWidget {
  const ImagePrintPage({super.key});

  @override
  State<ImagePrintPage> createState() => _ImagePrintPageState();
}

class _ImagePrintPageState extends State<ImagePrintPage> {
  final _printer = SupvanPrinter.instance;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await rootBundle.load('assets/images/logo.png');
    setState(() {
      _imageBytes = data.buffer.asUint8List();
    });
  }

  Future<void> _printImage() async {
    if (_imageBytes == null) return;
    
    final result = await _printer.print(PrintJob(
      labelWidth: 40,
      labelHeight: 30,
      copies: 1,
      density: 5,
      pages: [
        PrintPage(
          width: 40,
          height: 30,
          items: [
            PrintItem.image(
              x: 5,
              y: 5,
              width: 30,
              height: 20,
              imageBytes: _imageBytes!,
            ),
          ],
        ),
      ],
    ));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result ? '打印成功' : '打印失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('打印图片')),
      body: Center(
        child: _imageBytes == null
            ? const CircularProgressIndicator()
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.memory(_imageBytes!, width: 200),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _printImage,
                    icon: const Icon(Icons.print),
                    label: const Text('打印'),
                  ),
                ],
              ),
      ),
    );
  }
}
```

## 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `x` | double | 图片左上角 X 坐标（mm） |
| `y` | double | 图片左上角 Y 坐标（mm） |
| `width` | double | 图片打印宽度（mm） |
| `height` | double | 图片打印高度（mm） |
| `imageBytes` | Uint8List | PNG 格式图片字节 |
| `antiColor` | bool | 是否反色，默认 false |

## 注意事项

1. **图片格式**：仅支持 PNG 格式，其他格式需先转换
2. **图片大小**：建议使用适当的分辨率，过大会增加处理时间
3. **坐标单位**：所有坐标和尺寸单位均为毫米（mm）
4. **打印效果**：热敏打印为黑白打印，彩色图片会自动转换为灰度
5. **反色打印**：设置 `antiColor: true` 可打印反色效果

## 常见问题

### 图片打印模糊

- 提高图片分辨率
- 调整 `density` 参数（1-9，值越大越浓）
- 确保图片尺寸与打印区域匹配

### 图片打印位置偏移

- 检查 `x`、`y` 坐标设置
- 使用 `horizontalOffset` 和 `verticalOffset` 微调

### 图片无法打印

- 确认图片为有效 PNG 格式
- 检查打印机状态 `getStatus()`
- 确认打印机已正确连接
