import 'package:flutter_test/flutter_test.dart';
import 'package:supvan_printer_example/main.dart';

void main() {
  testWidgets('App renders without crash', (tester) async {
    await tester.pumpWidget(const MyApp());
    expect(find.text('Supvan Printer Demo'), findsOneWidget);
    expect(find.text('Tap scan to find printers'), findsOneWidget);
  });
}
