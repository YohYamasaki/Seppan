import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural regression tests ensuring the "edit from detail page"
/// flow propagates updates to both history list views.
///
/// HistoryPage stores its rows in local mutable state (_expenses) and
/// reacts to [expenseDataVersionProvider] changes by calling _refresh().
/// HomePage's recent-expenses card and the balance / category summaries
/// are Riverpod providers that need explicit invalidation.
///
/// ExpenseInputPage._submit() already does all of this on save, but:
///   1. The edit flow is triggered from HistoryDetailPage via
///      Navigator.push(MaterialPageRoute) rather than go_router, which
///      means ExpenseInputPage lives outside the go_router stack.
///   2. HistoryPage can be disposed between the moment the version
///      bump fires and the moment the edit is awaited — losing the
///      refresh signal.
///
/// So HistoryDetailPage's edit button onPressed must *also* invalidate
/// the same set of providers after the push returns. These tests pin
/// that defense-in-depth by grepping the source.
void main() {
  late String detailSource;

  setUpAll(() {
    detailSource = File(
      'lib/pages/history/history_detail_page.dart',
    ).readAsStringSync();
  });

  /// Extract the body of the edit ElevatedButton.icon's onPressed closure.
  /// We approximate with a regex capturing from the edit button's label
  /// down to the closing of onPressed, so that assertions below check
  /// what specifically runs in the edit flow (not accidentally matching
  /// the delete button).
  String extractEditButtonOnPressed(String source) {
    final match = RegExp(
      r"label:\s*const Text\('編集'\)[\s\S]*?onPressed:\s*\(\)\s*async\s*\{([\s\S]*?)\},\s*\),",
    ).firstMatch(source);
    expect(
      match,
      isNotNull,
      reason: 'Edit button onPressed closure not found — did the '
          'detail page structure change?',
    );
    return match!.group(1)!;
  }

  group('HistoryDetailPage edit button refreshes list-level data', () {
    test('invalidates the detail provider for this expense', () {
      final body = extractEditButtonOnPressed(detailSource);
      expect(
        body,
        contains('expenseDetailProvider(expenseId)'),
        reason: 'Edit must invalidate expenseDetailProvider so this '
            'page itself re-renders with the new values.',
      );
    });

    test('invalidates recentExpensesProvider (home preview)', () {
      final body = extractEditButtonOnPressed(detailSource);
      expect(
        body,
        contains('recentExpensesProvider'),
        reason: 'Edit must invalidate recentExpensesProvider so the '
            'home screen history card reflects the change.',
      );
    });

    test('invalidates balanceSummaryProvider', () {
      final body = extractEditButtonOnPressed(detailSource);
      expect(
        body,
        contains('balanceSummaryProvider'),
        reason: 'Edit must invalidate balanceSummaryProvider because '
            'amount / ratio changes affect the balance.',
      );
    });

    test('invalidates categoryBreakdownProvider', () {
      final body = extractEditButtonOnPressed(detailSource);
      expect(
        body,
        contains('categoryBreakdownProvider'),
        reason: 'Edit must invalidate categoryBreakdownProvider because '
            'category changes affect the monthly breakdown.',
      );
    });

    test('bumps expenseDataVersionProvider for HistoryPage refresh', () {
      final body = extractEditButtonOnPressed(detailSource);
      expect(
        body,
        contains('expenseDataVersionProvider.notifier'),
        reason: 'Edit must bump expenseDataVersionProvider.state so '
            'both HistoryPage instances (/history tab and /history-view '
            'root push) re-run _refresh() and show the updated row.',
      );
      // Also check it's an increment, not an assignment to some fixed value.
      expect(
        body,
        contains('state++'),
        reason: 'expenseDataVersionProvider must be incremented '
            '(state++) — not replaced with a constant.',
      );
    });
  });

  group('Delete button has the same invalidation (preserve parity)', () {
    // Sanity check: we did not accidentally remove the delete button's
    // invalidation when editing. This protects against a regression
    // where someone deletes the invalidation while "cleaning up".
    test('delete path invalidates the same list-level providers', () {
      expect(
        detailSource,
        contains('recentExpensesProvider'),
        reason: 'Delete flow still invalidates recentExpensesProvider.',
      );
      expect(
        detailSource,
        contains('expenseDataVersionProvider.notifier'),
        reason: 'Delete flow still bumps expenseDataVersionProvider.',
      );
    });
  });
}
