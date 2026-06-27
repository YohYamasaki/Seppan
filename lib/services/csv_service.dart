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

  /// Maps CSV header labels to canonical field keys. Parsing is
  /// header-name driven (not positional) so that:
  ///   * Column order can change without breaking import.
  ///   * Columns this version doesn't recognise are simply ignored
  ///     (forward compatibility — a CSV exported by a future version
  ///     with extra columns still imports here).
  ///   * Optional columns missing from an older CSV fall back to a
  ///     default (backward compatibility).
  ///
  /// To keep already-shipped positional parsers working, new columns
  /// are *appended* to the export header (see [_exportHeader]) — never
  /// inserted in the middle.
  static const Map<String, String> _headerAliases = {
    '日付': 'date',
    '支払者': 'payer',
    '金額': 'amount',
    '通貨': 'currency',
    '負担率': 'ratio',
    'カテゴリ': 'category',
    '購入場所': 'place',
    'メモ': 'memo',
  };

  /// Header row used on export. Append-only — do not reorder/remove
  /// columns, to preserve compatibility with older clients that read by
  /// position.
  static const List<String> _exportHeader = [
    '日付',
    '支払者',
    '金額',
    '通貨',
    '負担率',
    'カテゴリ',
    'メモ',
    '購入場所',
  ];

  /// Canonical field keys that must be present for a row to be importable.
  static const List<String> _requiredFields = ['date', 'payer', 'amount'];

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
    final rows = <List<String>>[
      _exportHeader,
      ...expenses.map((e) => [
            _dateFormat.format(e.date),
            userNames[e.paidBy] ?? e.paidBy,
            e.amount.toString(),
            e.currency,
            e.ratio.toString(),
            e.category,
            e.memo,
            e.place,
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
  /// Columns are matched by header name (see [_headerAliases]), not by
  /// position, so unknown columns are ignored and optional columns may
  /// be absent. A row is skipped (with a reason recorded) if any of the
  /// following is true:
  ///   * A required field's cell is empty/missing
  ///   * Unknown payer name
  ///   * Invalid date format / out of plausible range
  ///   * Non-positive amount or amount exceeding the upper bound
  ///
  /// If the header itself lacks any required column, all data rows are
  /// skipped under a single reason.
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

    // Build a canonical-field → column-index map from the header row.
    // Unrecognised header labels are simply not mapped (= ignored).
    final colIndex = <String, int>{};
    final header = rows[0];
    for (var c = 0; c < header.length; c++) {
      final field = _headerAliases[header[c].toString().trim()];
      if (field != null) colIndex.putIfAbsent(field, () => c);
    }

    // If any required column is missing, no row can be imported.
    final missing =
        _requiredFields.where((f) => !colIndex.containsKey(f)).toList();
    if (missing.isNotEmpty) {
      final labels = _headerAliases.entries
          .where((e) => missing.contains(e.value))
          .map((e) => e.key)
          .join('/');
      for (var i = 1; i < rows.length; i++) {
        recordSkip(i, '必須列（$labels）が見つかりません');
      }
      return CsvParseResult(
        parsed: parsed,
        skipped: rows.length - 1,
        skipReasons: skipReasons,
      );
    }

    // Reads a cell by canonical field name, or null if the column is
    // absent / the row is too short.
    String? cellOf(List<dynamic> row, String field) {
      final idx = colIndex[field];
      if (idx == null || idx >= row.length) return null;
      return row[idx].toString();
    }

    // Skip header row (index 0)
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final rowNum = i; // 1-indexed, excluding header

      // Payer name → userId
      final name = cellOf(row, 'payer') ?? '';
      final userId = nameToUserId[name];
      if (userId == null) {
        recordSkip(rowNum, '未知の支払者「$name」');
        continue;
      }

      // Amount validation
      final amount = int.tryParse(cellOf(row, 'amount') ?? '');
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
        date = _dateFormat.parseStrict(cellOf(row, 'date') ?? '');
      } on FormatException {
        recordSkip(rowNum, '日付の形式が不正です（YYYY-MM-DD 形式が必要）');
        continue;
      }
      if (date.isBefore(_minDate) || date.isAfter(_maxDate)) {
        recordSkip(rowNum, '日付が範囲外です');
        continue;
      }

      final ratio =
          (double.tryParse(cellOf(row, 'ratio') ?? '') ?? 0.5).clamp(0.0, 1.0);

      parsed.add({
        'date': date,
        'paidBy': userId,
        'amount': amount,
        'currency': cellOf(row, 'currency') ?? 'JPY',
        'ratio': ratio,
        'category': cellOf(row, 'category') ?? '',
        'place': cellOf(row, 'place') ?? '',
        'memo': cellOf(row, 'memo') ?? '',
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
