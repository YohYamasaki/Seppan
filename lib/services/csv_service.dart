import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';

class CsvService {
  static final _dateFormat = DateFormat('yyyy-MM-dd');

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

  /// Parse CSV content into expense data for import.
  /// Returns a list of maps with: date, paidBy, amount, currency, ratio,
  /// category, memo.
  static List<Map<String, dynamic>> parseExpenses({
    required String csvContent,
    required Map<String, String> nameToUserId,
  }) {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.length < 2) return []; // header only or empty

    final result = <Map<String, dynamic>>[];
    // Skip header row
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.length < 7) continue;

      final name = row[1].toString();
      final userId = nameToUserId[name];
      if (userId == null) continue; // unknown user, skip

      result.add({
        'date': _dateFormat.parse(row[0].toString()),
        'paidBy': userId,
        'amount': int.tryParse(row[2].toString()) ?? 0,
        'currency': row[3].toString(),
        'ratio': double.tryParse(row[4].toString()) ?? 0.5,
        'category': row[5].toString(),
        'memo': row[6].toString(),
      });
    }
    return result;
  }
}
