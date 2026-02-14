import 'dart:typed_data';

/// The type of content to print.
enum PrintItemType {
  /// Plain text.
  text,

  /// CODE_128 barcode.
  barcode,

  /// QR code.
  qrCode,

  /// Bitmap image (provide [imageBytes]).
  image,
}

/// Font style flags (can be combined with bitwise OR).
class FontStyle {
  static const int normal = 0;
  static const int bold = 1;
  static const int italic = 2;
  static const int underline = 4;
  static const int strikethrough = 8;
}

/// A single drawable element on a print label.
class PrintItem {
  /// Content type.
  final PrintItemType type;

  /// X coordinate in mm.
  final double x;

  /// Y coordinate in mm.
  final double y;

  /// Width in mm.
  final double width;

  /// Height in mm.
  final double height;

  /// Text content (for [PrintItemType.text], [PrintItemType.barcode],
  /// [PrintItemType.qrCode]).
  final String? content;

  /// Font size in mm (for text type).
  final int? fontSize;

  /// Font style flags (see [FontStyle]).
  final int fontStyle;

  /// Font name. Defaults to platform default.
  final String? fontName;

  /// Whether to invert colors.
  final bool antiColor;

  /// Image bytes in PNG format (for [PrintItemType.image]).
  final Uint8List? imageBytes;

  const PrintItem({
    required this.type,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    this.content,
    this.fontSize,
    this.fontStyle = FontStyle.normal,
    this.fontName,
    this.antiColor = false,
    this.imageBytes,
  });

  /// Convenience constructor for text items.
  const PrintItem.text({
    required double x,
    required double y,
    required double width,
    required double height,
    required String content,
    int? fontSize,
    int fontStyle = FontStyle.normal,
    String? fontName,
    bool antiColor = false,
  }) : this(
          type: PrintItemType.text,
          x: x,
          y: y,
          width: width,
          height: height,
          content: content,
          fontSize: fontSize,
          fontStyle: fontStyle,
          fontName: fontName,
          antiColor: antiColor,
        );

  /// Convenience constructor for barcode items.
  const PrintItem.barcode({
    required double x,
    required double y,
    required double width,
    required double height,
    required String content,
    bool antiColor = false,
  }) : this(
          type: PrintItemType.barcode,
          x: x,
          y: y,
          width: width,
          height: height,
          content: content,
          antiColor: antiColor,
        );

  /// Convenience constructor for QR code items.
  const PrintItem.qrCode({
    required double x,
    required double y,
    required double width,
    required double height,
    required String content,
    bool antiColor = false,
  }) : this(
          type: PrintItemType.qrCode,
          x: x,
          y: y,
          width: width,
          height: height,
          content: content,
          antiColor: antiColor,
        );

  /// Convenience constructor for image items.
  const PrintItem.image({
    required double x,
    required double y,
    required double width,
    required double height,
    required Uint8List imageBytes,
    bool antiColor = false,
  }) : this(
          type: PrintItemType.image,
          x: x,
          y: y,
          width: width,
          height: height,
          imageBytes: imageBytes,
          antiColor: antiColor,
        );

  String get _formatString {
    switch (type) {
      case PrintItemType.text:
        return 'TEXT';
      case PrintItemType.barcode:
        return 'CODE_128';
      case PrintItemType.qrCode:
        return 'QR_CODE';
      case PrintItemType.image:
        return 'IMAGE';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'format': _formatString,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'content': content ?? '',
      'fontSize': fontSize ?? 3,
      'fontStyle': fontStyle,
      'fontName': fontName ?? '',
      'antiColor': antiColor,
      if (imageBytes != null) 'imageBytes': imageBytes,
    };
  }
}
