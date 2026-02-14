import 'print_item.dart';

/// Paper type for the label material.
enum PaperType {
  /// Gap paper (default).
  gap(1),

  /// Standard black mark.
  blackMark(2),

  /// Black mark card.
  blackMarkCard(5);

  final int value;
  const PaperType(this.value);
}

/// A single page within a print job.
class PrintPage {
  /// Page width in mm.
  final int width;

  /// Page height in mm.
  final int height;

  /// How many times to repeat this page.
  final int repeat;

  /// Drawable items on this page.
  final List<PrintItem> items;

  const PrintPage({
    required this.width,
    required this.height,
    this.repeat = 1,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'width': width,
      'height': height,
      'repeat': repeat,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }
}

/// A complete print job describing what to print and how.
class PrintJob {
  /// Label material width in mm.
  final int labelWidth;

  /// Label material height in mm.
  final int labelHeight;

  /// Number of copies (1-99).
  final int copies;

  /// Print density (1-9, default 3).
  final int density;

  /// Rotation: 0=0, 1=90, 2=180, 3=270 degrees.
  final int rotate;

  /// Horizontal offset (-9 to 9).
  final int horizontalOffset;

  /// Vertical offset (-9 to 9).
  final int verticalOffset;

  /// Paper type.
  final PaperType paperType;

  /// Gap between labels in mm (0-8, default 3).
  final int gap;

  /// Whether to print one-by-one (collated).
  final bool oneByOne;

  /// Tail length in mm.
  final int tailLength;

  /// Pages to print.
  final List<PrintPage> pages;

  const PrintJob({
    required this.labelWidth,
    required this.labelHeight,
    this.copies = 1,
    this.density = 3,
    this.rotate = 0,
    this.horizontalOffset = 0,
    this.verticalOffset = 0,
    this.paperType = PaperType.gap,
    this.gap = 3,
    this.oneByOne = true,
    this.tailLength = 0,
    required this.pages,
  });

  Map<String, dynamic> toMap() {
    return {
      'labelWidth': labelWidth,
      'labelHeight': labelHeight,
      'copies': copies,
      'density': density,
      'rotate': rotate,
      'horizontalOffset': horizontalOffset,
      'verticalOffset': verticalOffset,
      'paperType': paperType.value,
      'gap': gap,
      'oneByOne': oneByOne,
      'tailLength': tailLength,
      'pages': pages.map((e) => e.toMap()).toList(),
    };
  }
}
