import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/services/csv_service.dart';

const userA = 'user-a-id';
const userB = 'user-b-id';
const nameToUserId = {'Alice': userA, 'Bob': userB};

String buildCsv(List<List<String>> rows) {
  final header = '日付,支払者,金額,通貨,負担率,カテゴリ,メモ';
  if (rows.isEmpty) return header;
  final dataLines = rows.map((r) => r.join(',')).join('\r\n');
  return '$header\r\n$dataLines';
}

void main() {
  group('parseExpenses', () {
    test('valid CSV parses correctly', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '0.5', '食費', 'ランチ'],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, hasLength(1));
      expect(result[0]['paidBy'], userA);
      expect(result[0]['amount'], 1000);
      expect(result[0]['currency'], 'JPY');
      expect(result[0]['ratio'], 0.5);
      expect(result[0]['category'], '食費');
      expect(result[0]['memo'], 'ランチ');
      expect(result[0]['date'], DateTime(2024, 1, 15));
    });

    test('zero amount rows are skipped', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '0', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, isEmpty);
    });

    test('negative amount rows are skipped', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '-500', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, isEmpty);
    });

    test('non-numeric amount defaults to 0 and is skipped', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', 'abc', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, isEmpty);
    });

    test('ratio > 1.0 is clamped to 1.0', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '1.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, hasLength(1));
      expect(result[0]['ratio'], 1.0);
    });

    test('ratio < 0.0 is clamped to 0.0', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '-0.3', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, hasLength(1));
      expect(result[0]['ratio'], 0.0);
    });

    test('missing ratio defaults to 0.5', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, hasLength(1));
      expect(result[0]['ratio'], 0.5);
    });

    test('empty CSV returns empty list', () {
      final result = CsvService.parseExpenses(
        csvContent: '',
        nameToUserId: nameToUserId,
      );
      expect(result, isEmpty);
    });

    test('header-only CSV returns empty list', () {
      final csv = buildCsv([]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, isEmpty);
    });

    test('rows with fewer than 7 columns are skipped', () {
      final csv = '日付,支払者,金額,通貨,負担率,カテゴリ,メモ\r\n'
          '2024-01-15,Alice,1000,JPY,0.5';
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, isEmpty);
    });

    test('unknown user names are skipped', () {
      final csv = buildCsv([
        ['2024-01-15', 'Charlie', '1000', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result, isEmpty);
    });
  });
}
