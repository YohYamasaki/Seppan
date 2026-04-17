import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying that HistoryPage._deleteSelected handles
/// errors per-item (try-catch inside the loop) and always invalidates
/// caches afterward.
void main() {
  final file = File('lib/pages/history/history_page.dart');
  late String content;

  setUpAll(() {
    content = file.readAsStringSync();
  });

  group('Bulk delete safety in HistoryPage', () {
    test('_deleteSelected method exists', () {
      expect(
        content.contains('_deleteSelected'),
        isTrue,
        reason: 'HistoryPage must have a _deleteSelected method '
            'for bulk-deleting expenses.',
      );
    });

    test('try-catch exists within the delete loop', () {
      // Find the delete loop region (between deleteExpense and invalidate)
      final deleteExpenseIdx = content.indexOf('deleteExpense');
      expect(
        deleteExpenseIdx,
        greaterThan(-1),
        reason: '_deleteSelected must call deleteExpense.',
      );

      // Find try { near deleteExpense
      final tryIdx = content.lastIndexOf('try {', deleteExpenseIdx);
      expect(
        tryIdx,
        greaterThan(-1),
        reason: 'A try block must wrap the deleteExpense call.',
      );

      // Find catch after deleteExpense
      final catchIdx = content.indexOf('catch', deleteExpenseIdx);
      expect(
        catchIdx,
        greaterThan(deleteExpenseIdx),
        reason: 'A catch block must follow the deleteExpense call '
            'to handle per-item errors gracefully.',
      );
    });

    test('cache invalidation happens after the loop', () {
      final deleteExpenseIdx = content.indexOf('deleteExpense');
      expect(deleteExpenseIdx, greaterThan(-1));

      final invalidateIdx = content.indexOf(
        'invalidate(recentExpensesProvider)',
        deleteExpenseIdx,
      );
      expect(
        invalidateIdx,
        greaterThan(deleteExpenseIdx),
        reason: 'recentExpensesProvider must be invalidated after '
            'the delete loop to refresh the UI.',
      );
    });
  });
}
