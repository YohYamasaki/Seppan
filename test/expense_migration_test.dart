import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying that expense migration logic exists
/// in the join flows (invite page and QR scanner).
void main() {
  final invitePageFile = File('lib/pages/auth/invite_page.dart');
  final qrScannerFile = File('lib/pages/auth/qr_scanner_page.dart');
  final expenseRepoFile = File('lib/repositories/expense_repository.dart');

  late String inviteContent;
  late String qrContent;
  late String expenseRepoContent;

  setUpAll(() {
    inviteContent = invitePageFile.readAsStringSync();
    qrContent = qrScannerFile.readAsStringSync();
    expenseRepoContent = expenseRepoFile.readAsStringSync();
  });

  group('ExpenseRepository.migrateExpenses', () {
    test('method exists', () {
      expect(
        expenseRepoContent.contains('Future<void> migrateExpenses'),
        isTrue,
        reason: 'ExpenseRepository must have a migrateExpenses method '
            'to move expenses between partnerships.',
      );
    });

    test('updates partnership_id', () {
      expect(
        expenseRepoContent.contains("'partnership_id'"),
        isTrue,
        reason: 'migrateExpenses should update the partnership_id column.',
      );
    });
  });

  group('InvitePage migrates expenses on join', () {
    test('calls migrateExpenses after joining', () {
      expect(
        inviteContent.contains('migrateExpenses'),
        isTrue,
        reason: 'InvitePage must migrate expenses from the old pending '
            'partnership to the new active one after joining.',
      );
    });

    test('archives old pending partnership after migration', () {
      // migrateExpenses must come before archivePartnership
      final migrateIdx = inviteContent.indexOf('migrateExpenses');
      final archiveIdx = inviteContent.indexOf(
        'archivePartnership',
        migrateIdx,
      );
      expect(migrateIdx, greaterThan(-1));
      expect(
        archiveIdx,
        greaterThan(migrateIdx),
        reason: 'Old pending partnership should be archived after '
            'expenses are migrated.',
      );
    });

    test('invalidates currentPartnershipProvider after join', () {
      expect(
        inviteContent.contains('invalidate(currentPartnershipProvider)'),
        isTrue,
        reason: 'Must invalidate currentPartnershipProvider so the app '
            'reloads data from the new active partnership.',
      );
    });

    test('invalidates recentExpensesProvider after join', () {
      expect(
        inviteContent.contains('invalidate(recentExpensesProvider)'),
        isTrue,
        reason: 'Must invalidate recentExpensesProvider so migrated '
            'expenses appear in the new partnership.',
      );
    });
  });

  group('QrScannerPage migrates expenses on join', () {
    test('calls migrateExpenses after joining', () {
      expect(
        qrContent.contains('migrateExpenses'),
        isTrue,
        reason: 'QrScannerPage must migrate expenses from the old pending '
            'partnership to the new active one after joining.',
      );
    });

    test('looks up pending partnership before joining', () {
      // getPendingPartnership must come before joinPartnership
      final pendingIdx = qrContent.indexOf('getPendingPartnership');
      final joinIdx = qrContent.indexOf('joinPartnership');
      expect(pendingIdx, greaterThan(-1));
      expect(
        pendingIdx,
        lessThan(joinIdx),
        reason: 'Must look up pending partnership before joining, '
            'because after joining it is no longer pending.',
      );
    });

    test('invalidates currentPartnershipProvider after join', () {
      expect(
        qrContent.contains('invalidate(currentPartnershipProvider)'),
        isTrue,
        reason: 'Must invalidate currentPartnershipProvider after join.',
      );
    });
  });
}
