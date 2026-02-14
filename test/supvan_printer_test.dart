import 'package:flutter_test/flutter_test.dart';
import 'package:supvan_printer/supvan_printer.dart';

void main() {
  group('PrinterDevice', () {
    test('fromMap creates correct instance', () {
      final device = PrinterDevice.fromMap({
        'id': 'AA:BB:CC:DD:EE:FF',
        'name': 'T50Plus',
        'rssi': -65,
      });
      expect(device.id, 'AA:BB:CC:DD:EE:FF');
      expect(device.name, 'T50Plus');
      expect(device.rssi, -65);
    });

    test('toMap round-trips correctly', () {
      const device = PrinterDevice(
        id: 'test-id',
        name: 'test-name',
        rssi: -50,
      );
      final map = device.toMap();
      final restored = PrinterDevice.fromMap(map);
      expect(restored, device);
    });

    test('equality based on id', () {
      const a = PrinterDevice(id: '1', name: 'A');
      const b = PrinterDevice(id: '1', name: 'B');
      const c = PrinterDevice(id: '2', name: 'A');
      expect(a, b);
      expect(a, isNot(c));
    });
  });

  group('PrinterStatus', () {
    test('fromCode returns correct status', () {
      expect(PrinterStatus.fromCode(0), PrinterStatus.ready);
      expect(PrinterStatus.fromCode(3), PrinterStatus.materialNotLoaded);
      expect(PrinterStatus.fromCode(8), PrinterStatus.batteryLow);
      expect(PrinterStatus.fromCode(99), PrinterStatus.unknown);
    });
  });

  group('PrintJob', () {
    test('toMap serializes correctly', () {
      final job = PrintJob(
        labelWidth: 40,
        labelHeight: 30,
        copies: 2,
        density: 5,
        pages: [
          PrintPage(
            width: 40,
            height: 30,
            items: [
              const PrintItem.text(
                x: 5,
                y: 5,
                width: 30,
                height: 5,
                content: 'Hello',
                fontSize: 4,
              ),
              const PrintItem.barcode(
                x: 1,
                y: 10,
                width: 23,
                height: 3,
                content: '123456',
              ),
            ],
          ),
        ],
      );

      final map = job.toMap();
      expect(map['labelWidth'], 40);
      expect(map['copies'], 2);
      expect(map['density'], 5);

      final pages = map['pages'] as List;
      expect(pages.length, 1);

      final page = pages[0] as Map<String, dynamic>;
      final items = page['items'] as List;
      expect(items.length, 2);
      expect((items[0] as Map)['format'], 'TEXT');
      expect((items[1] as Map)['format'], 'CODE_128');
    });
  });
}
