import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';

/// Result of a CSV parse operation — successfully-parsed rows plus a
/// breakdown of rows that were skipped and why.
class CsvParseResult {
  const CsvParseResult({
    required this.parsed,
    required this.skipped,
    required this.skipReasons,
  });

  /// Rows that passed all validation and are ready to import.
  final List<Map<String, dynamic>> parsed;

  /// Total number of rows (excluding header) that were skipped.
  final int skipped;

  /// Map of "reason" → row numbers (1-indexed, excluding header) that
  /// were skipped for that reason. Used to show details to the user.
  final Map<String, List<int>> skipReasons;
}

class CsvService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

  /// Reasonable upper bound on a single expense amount (in JPY).
  /// Prevents integer overflow / DoS via pathological CSV values.
  static const int _maxAmount = 100000000; // 100,000,000 JPY

  /// Earliest plausible expense date. Anything older is rejected.
  static DateTime get _minDate => DateTime(1970);

  /// Latest plausible expense date: 1 year into the future (to allow
  /// timezone skew / scheduled entries) but no further.
  static DateTime get _maxDate =>
      DateTime.now().add(const Duration(days: 365));

  /// Export expenses to CSV via OS save dialog.
  /// Returns `true` if saved, `false` if cancelled.
  static Future<bool> exportExpenses({
    required List<Expense> expenses,
    required Map<String, String> userNames,
  }) async {
    final header = ['日付', '支払者', '金額', '通貨', '負担率', 'カテゴリ', 'メモ'];
    final rows = <List<String>>[
      header,
      ...expenses.map((e) => [
            _dateFormat.format(e.date),
            userNames[e.paidBy] ?? e.paidBy,
            e.amount.toString(),
            e.currency,
            e.ratio.toString(),
            e.category,
            e.memo,
          ]),
    ];

    final csv = const ListToCsvConverter().convert(rows);
    final bytes = utf8.encode(csv);
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'CSVを保存',
      fileName: 'seppan_$timestamp.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes,
    );

    return result != null;
  }

  /// Parse CSV content into a [CsvParseResult] including per-row
  /// validation failures.
  ///
  /// Rows are skipped (with a reason recorded) if any of the following
  /// is true:
  ///   * Fewer than 7 columns
  ///   * Unknown payer name
  ///   * Invalid date format
  ///   * Date out of plausible range (before 1970 or more than 1 year
  ///     in the future)
  ///   * Non-positive amount or amount exceeding the upper bound
  static CsvParseResult parseExpenses({
    required String csvContent,
    required Map<String, String> nameToUserId,
  }) {
    // Normalize line endings: CsvToListConverter's default eol is '\r\n',
    // so files saved with Unix line endings (\n only) would be parsed as
    // a single row and rejected. Convert all variants to '\n' and tell
    // the parser to use '\n' as eol.
    final normalized =
        csvContent.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final rows = const CsvToListConverter(eol: '\n').convert(normalized);
    if (rows.length < 2) {
      return const CsvParseResult(parsed: [], skipped: 0, skipReasons: {});
    }

    final parsed = <Map<String, dynamic>>[];
    final skipReasons = <String, List<int>>{};

    void recordSkip(int rowNum, String reason) {
      skipReasons.putIfAbsent(reason, () => []).add(rowNum);
    }

    // Skip header row (index 0)
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i; // 1-indexed, excluding header

      if (row.length < 7) {
        recordSkip(rowNum, '列数が不足しています');
        continue;
      }

      // Payer name → userId
      final name = row[1].toString();
      final userId = nameToUserId[name];
      if (userId == null) {
        recordSkip(rowNum, '未知の支払者「$name」');
        continue;
      }

      // Amount validation
      final amount = int.tryParse(row[2].toString());
      if (amount == null) {
        recordSkip(rowNum, '金額が数値ではありません');
        continue;
      }
      if (amount <= 0) {
        recordSkip(rowNum, '金額が0以下です');
        continue;
      }
      if (amount > _maxAmount) {
        recordSkip(rowNum, '金額が上限（1億円）を超えています');
        continue;
      }

      // Date validation
      final DateTime date;
      try {
        date = _dateFormat.parseStrict(row[0].toString());
      } on FormatException {
        recordSkip(rowNum, '日付の形式が不正です（YYYY-MM-DD 形式が必要）');
        continue;
      }
      if (date.isBefore(_minDate) || date.isAfter(_maxDate)) {
        recordSkip(rowNum, '日付が範囲外です');
        continue;
      }

      final ratio =
          (double.tryParse(row[4].toString()) ?? 0.5).clamp(0.0, 1.0);

      parsed.add({
        'date': date,
        'paidBy': userId,
        'amount': amount,
        'currency': row[3].toString(),
        'ratio': ratio,
        'category': row[5].toString(),
        'memo': row[6].toString(),
      });
    }

    final totalSkipped =
        skipReasons.values.fold<int>(0, (sum, list) => sum + list.length);

    return CsvParseResult(
      parsed: parsed,
      skipped: totalSkipped,
      skipReasons: skipReasons,
    );
  }
}
