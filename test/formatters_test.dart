import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/utils/formatters.dart';

void main() {
  group('formatJpy', () {
    test('formats zero', () {
      expect(formatJpy(0), '¥0');
    });

    test('formats small amount', () {
      expect(formatJpy(1), '¥1');
    });

    test('formats hundreds without comma', () {
      expect(formatJpy(999), '¥999');
    });

    test('formats thousands with comma', () {
      expect(formatJpy(1000), '¥1,000');
    });

    test('formats ten-thousands', () {
      expect(formatJpy(12345), '¥12,345');
    });

    test('formats large amount', () {
      expect(formatJpy(1000000), '¥1,000,000');
    });
  });

  group('ratioLabel', () {
    test('0%', () {
      expect(ratioLabel(0.0), '0%');
    });

    test('25%', () {
      expect(ratioLabel(0.25), '25%');
    });

    test('50%', () {
      expect(ratioLabel(0.5), '50%');
    });

    test('75%', () {
      expect(ratioLabel(0.75), '75%');
    });

    test('100%', () {
      expect(ratioLabel(1.0), '100%');
    });
  });

  group('ratioDescription', () {
    test('100% is おごり', () {
      expect(ratioDescription(1.0, '太郎'), '太郎さんのおごり');
    });

    test('0% is 立て替え', () {
      expect(ratioDescription(0.0, '太郎'), '太郎さんが立て替え');
    });

    test('50% returns empty', () {
      expect(ratioDescription(0.5, '太郎'), '');
    });

    test('25% returns empty', () {
      expect(ratioDescription(0.25, '太郎'), '');
    });

    test('75% returns empty', () {
      expect(ratioDescription(0.75, '太郎'), '');
    });
  });
}
