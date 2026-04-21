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
  group('parseExpenses — happy path', () {
    test('parses Unix line endings (\\n)', () {
      // Regression test: CsvToListConverter's default eol is '\r\n',
      // which caused files with Unix line endings to be treated as
      // a single row and rejected as empty.
      const csv = '日付,支払者,金額,通貨,負担率,カテゴリ,メモ\n'
          '2024-01-15,Alice,1000,JPY,0.5,食費,ランチ\n'
          '2024-01-16,Bob,2000,JPY,0.5,交通費,電車';
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(2));
      expect(result.parsed[0]['amount'], 1000);
      expect(result.parsed[1]['amount'], 2000);
      expect(result.skipped, 0);
    });

    test('parses CRLF line endings (\\r\\n)', () {
      const csv = '日付,支払者,金額,通貨,負担率,カテゴリ,メモ\r\n'
          '2024-01-15,Alice,1000,JPY,0.5,食費,ランチ\r\n'
          '2024-01-16,Bob,2000,JPY,0.5,交通費,電車';
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(2));
    });

    test('parses mixed/lone CR line endings (\\r)', () {
      const csv = '日付,支払者,金額,通貨,負担率,カテゴリ,メモ\r'
          '2024-01-15,Alice,1000,JPY,0.5,食費,ランチ';
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(1));
    });

    test('valid CSV parses correctly', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '0.5', '食費', 'ランチ'],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(1));
      expect(result.parsed[0]['paidBy'], userA);
      expect(result.parsed[0]['amount'], 1000);
      expect(result.parsed[0]['currency'], 'JPY');
      expect(result.parsed[0]['ratio'], 0.5);
      expect(result.parsed[0]['category'], '食費');
      expect(result.parsed[0]['memo'], 'ランチ');
      expect(result.parsed[0]['date'], DateTime(2024, 1, 15));
    });
  });

  group('parseExpenses — amount validation', () {
    test('zero amount rows are skipped with reason', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '0', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipped, 1);
      expect(result.skipReasons.keys, contains('金額が0以下です'));
    });

    test('negative amount rows are skipped', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '-500', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipReasons.keys, contains('金額が0以下です'));
    });

    test('non-numeric amount is reported distinctly', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', 'abc', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipReasons.keys, contains('金額が数値ではありません'));
    });

    test('amount over upper bound (1 億円) is skipped', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '100000001', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipReasons.keys, contains('金額が上限（1億円）を超えています'));
    });

    test('amount exactly at upper bound (1 億円) is accepted', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '100000000', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(1));
    });

    test('integer-overflow-ish value is rejected without crashing', () {
      // Larger than int64 max — int.tryParse returns null.
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '99999999999999999999', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipReasons.keys, contains('金額が数値ではありません'));
    });
  });

  group('parseExpenses — date validation', () {
    test('strict date parsing: invalid date format is skipped', () {
      final csv = buildCsv([
        ['invalid-date', 'Alice', '1000', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(
        result.skipReasons.keys,
        contains('日付の形式が不正です（YYYY-MM-DD 形式が必要）'),
      );
    });

    test('date far in the future is skipped', () {
      final csv = buildCsv([
        ['9999-12-31', 'Alice', '1000', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipReasons.keys, contains('日付が範囲外です'));
    });

    test('date before 1970 is skipped', () {
      final csv = buildCsv([
        ['1950-01-01', 'Alice', '1000', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipReasons.keys, contains('日付が範囲外です'));
    });

    test('recent past date is accepted', () {
      final csv = buildCsv([
        ['2020-01-01', 'Alice', '1000', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(1));
    });
  });

  group('parseExpenses — ratio handling', () {
    test('ratio > 1.0 is clamped to 1.0', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '1.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(1));
      expect(result.parsed[0]['ratio'], 1.0);
    });

    test('ratio < 0.0 is clamped to 0.0', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '-0.3', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(1));
      expect(result.parsed[0]['ratio'], 0.0);
    });

    test('missing ratio defaults to 0.5', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(1));
      expect(result.parsed[0]['ratio'], 0.5);
    });
  });

  group('parseExpenses — edge cases', () {
    test('empty CSV returns empty result', () {
      final result = CsvService.parseExpenses(
        csvContent: '',
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipped, 0);
    });

    test('header-only CSV returns empty result', () {
      final csv = buildCsv([]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
    });

    test('rows with fewer than 7 columns are skipped with reason', () {
      final csv = '日付,支払者,金額,通貨,負担率,カテゴリ,メモ\r\n'
          '2024-01-15,Alice,1000,JPY,0.5';
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      expect(result.skipReasons.keys, contains('列数が不足しています'));
    });

    test('unknown user names are skipped with specific reason', () {
      final csv = buildCsv([
        ['2024-01-15', 'Charlie', '1000', 'JPY', '0.5', '食費', ''],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, isEmpty);
      // Reason includes the offending name
      expect(
        result.skipReasons.keys.any((k) => k.contains('Charlie')),
        isTrue,
      );
    });

    test('mix of valid + invalid rows: valid kept, invalid tracked', () {
      final csv = buildCsv([
        ['2024-01-15', 'Alice', '1000', 'JPY', '0.5', '食費', 'ok'],
        ['2024-01-16', 'Alice', '0', 'JPY', '0.5', '食費', 'bad amount'],
        ['2024-01-17', 'Charlie', '500', 'JPY', '0.5', '食費', 'unknown user'],
        ['2024-01-18', 'Bob', '300', 'JPY', '0.5', '食費', 'ok'],
      ]);
      final result = CsvService.parseExpenses(
        csvContent: csv,
        nameToUserId: nameToUserId,
      );
      expect(result.parsed, hasLength(2));
      expect(result.skipped, 2);
      // Both skip reasons should be present
      expect(result.skipReasons.keys.length, 2);
    });
  });
}
