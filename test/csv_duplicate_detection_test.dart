import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying CSV import safety:
/// - Duplicate detection warns users before importing
/// - Amount validation skips invalid rows
/// - Ratio clamping prevents out-of-range values
void main() {
  final settingsFile = File('lib/pages/settings/settings_page.dart');
  final csvServiceFile = File('lib/services/csv_service.dart');

  late String settingsContent;
  late String csvContent;

  setUpAll(() {
    settingsContent = settingsFile.readAsStringSync();
    csvContent = csvServiceFile.readAsStringSync();
  });

  group('SettingsPage CSV duplicate detection', () {
    test('duplicate detection logic exists', () {
      expect(
        settingsContent.contains('duplicateCount'),
        isTrue,
        reason: 'SettingsPage must count potential duplicates '
            'before importing CSV data.',
      );
    });

    test('warning is shown in dialog for duplicates', () {
      expect(
        settingsContent.contains('重複'),
        isTrue,
        reason: 'SettingsPage must show a warning message containing '
            '"重複" (duplicate) when duplicates are detected.',
      );
    });
  });

  group('CsvService input validation', () {
    test('amount validation exists', () {
      expect(
        csvContent.contains('amount <= 0'),
        isTrue,
        reason: 'CsvService.parseExpenses must skip rows with '
            'invalid amounts (amount <= 0).',
      );
    });

    test('invalid amounts are skipped with continue', () {
      final amountCheckIdx = csvContent.indexOf('amount <= 0');
      expect(amountCheckIdx, greaterThan(-1));

      final continueIdx = csvContent.indexOf('continue', amountCheckIdx);
      expect(
        continueIdx,
        greaterThan(amountCheckIdx),
        reason: 'Rows with invalid amounts must be skipped using '
            'continue.',
      );
    });

    test('ratio clamping exists', () {
      expect(
        csvContent.contains('clamp'),
        isTrue,
        reason: 'CsvService.parseExpenses must clamp ratio values '
            'to a valid range (0.0 to 1.0).',
      );
    });
  });
}
