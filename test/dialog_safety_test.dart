import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests to prevent common dialog-related bugs.
///
/// 1. TextEditingController.dispose() must NOT be called after showDialog.
///    When a dialog containing a TextField is dismissed, the TextField's
///    unmount triggers a focus change that accesses the controller. If the
///    controller is already disposed, it throws
///    "A TextEditingController was used after being disposed."
///    Local controllers are garbage-collected — manual dispose is unnecessary.
///
/// 2. Empty string must NOT be used as a UUID for Supabase inserts/upserts.
///    PostgreSQL rejects '' as invalid UUID syntax (error 22P02).
///    New records should omit the id field and let the DB generate it.
void main() {
  final dartFiles = Directory('lib/pages')
      .listSync(recursive: true)
      .whereType<File>()
      .where((f) => f.path.endsWith('.dart'))
      .toList();

  group('No controller.dispose() after showDialog', () {
    for (final file in dartFiles) {
      final content = file.readAsStringSync();
      if (!content.contains('showDialog')) continue;

      final relativePath =
          file.path.replaceFirst(RegExp(r'^.*/lib/'), 'lib/');

      test('$relativePath', () {
        // Find all showDialog blocks: look for controller.dispose()
        // occurring after showDialog and before the next method definition.
        //
        // Pattern: a local TextEditingController, then showDialog, then
        // controller.dispose() before another Future<void> or @override.
        final hasUnsafeDispose = RegExp(
          r'showDialog[\s\S]*?controller\.dispose\(\)',
        ).hasMatch(content);

        expect(
          hasUnsafeDispose,
          isFalse,
          reason: '$relativePath calls controller.dispose() after showDialog. '
              'This causes "TextEditingController was used after being disposed" '
              'because the dialog TextField still references the controller '
              'during unmount. Remove the dispose() call — local controllers '
              'are garbage-collected.',
        );
      });
    }
  });

  group('No empty string as UUID in Supabase operations', () {
    // Check that no code creates a model with id: '' and then sends it
    // to Supabase via upsert/insert.
    for (final file in dartFiles) {
      final content = file.readAsStringSync();

      // Only check files that interact with categories/expenses/partnerships
      if (!content.contains('upsertCategory') &&
          !content.contains('addExpense') &&
          !content.contains('upsertExpense')) continue;

      final relativePath =
          file.path.replaceFirst(RegExp(r'^.*/lib/'), 'lib/');

      test('$relativePath does not pass empty id to upsert', () {
        // Pattern: Category(id: '', ...) or Expense(id: '', ...) followed
        // by an upsert call in the same method scope.
        final hasEmptyIdUpsert = RegExp(
          r"id:\s*''[^;]*\)[\s\S]*?upsert",
        ).hasMatch(content);

        expect(
          hasEmptyIdUpsert,
          isFalse,
          reason:
              '$relativePath creates a model with id: \'\' and sends it to '
              'upsert. PostgreSQL rejects empty strings as UUIDs (error 22P02). '
              'Use insert without the id field for new records.',
        );
      });
    }
  });
}
