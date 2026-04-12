import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying that expense history is preserved for BOTH
/// partners when a partnership is unlinked.
///
/// Two scenarios:
/// 1. The user who initiates the unlink — handled directly in _confirmArchive.
/// 2. The partner who was unlinked — handled lazily by currentPartnershipProvider.
void main() {
  final partnershipManageFile =
      File('lib/pages/settings/partnership_manage_page.dart');
  final partnershipProviderFile =
      File('lib/providers/partnership_provider.dart');
  final partnershipRepoFile =
      File('lib/repositories/partnership_repository.dart');
  final expenseRepoFile = File('lib/repositories/expense_repository.dart');

  late String manageContent;
  late String providerContent;
  late String repoContent;
  late String expenseRepoContent;

  setUpAll(() {
    manageContent = partnershipManageFile.readAsStringSync();
    providerContent = partnershipProviderFile.readAsStringSync();
    repoContent = partnershipRepoFile.readAsStringSync();
    expenseRepoContent = expenseRepoFile.readAsStringSync();
  });

  group('ExpenseRepository.migrateUserExpenses', () {
    test('method exists', () {
      expect(
        expenseRepoContent.contains('Future<void> migrateUserExpenses'),
        isTrue,
        reason: 'ExpenseRepository must have migrateUserExpenses to move '
            'only a specific user\'s expenses between partnerships.',
      );
    });

    test('filters by paid_by', () {
      // The method must filter by paid_by to only move the user's own expenses.
      // Check a 500-char window after the method declaration.
      final methodStart =
          expenseRepoContent.indexOf('Future<void> migrateUserExpenses');
      final end = (methodStart + 500).clamp(0, expenseRepoContent.length);
      final methodArea = expenseRepoContent.substring(methodStart, end);
      expect(
        methodArea.contains('paid_by'),
        isTrue,
        reason: 'migrateUserExpenses must filter by paid_by column.',
      );
    });
  });

  group('Unlink initiator (partnership_manage_page)', () {
    test('creates new pending partnership for user', () {
      expect(
        manageContent.contains('createPartnership'),
        isTrue,
        reason: 'Must create a new pending partnership for the unlinking user.',
      );
    });

    test('migrates user expenses to new partnership', () {
      expect(
        manageContent.contains('migrateUserExpenses'),
        isTrue,
        reason: 'Must migrate the unlinking user\'s expenses to their new '
            'pending partnership.',
      );
    });

    test('archives old partnership after migration', () {
      final migrateIdx = manageContent.indexOf('migrateUserExpenses');
      final archiveIdx = manageContent.indexOf(
        'archivePartnership',
        migrateIdx,
      );
      expect(migrateIdx, greaterThan(-1));
      expect(
        archiveIdx,
        greaterThan(migrateIdx),
        reason: 'Old partnership must be archived after expenses are migrated.',
      );
    });

    test('does NOT create partnership for partner (RLS prevents it)', () {
      // Count occurrences of createPartnership — should be exactly one
      final matches =
          RegExp(r'createPartnership').allMatches(manageContent).length;
      expect(
        matches,
        equals(1),
        reason: 'Only ONE createPartnership call should exist (for the '
            'current user). Partner-side is handled lazily by the provider.',
      );
    });
  });

  group('Unlinked partner (lazy migration in currentPartnershipProvider)', () {
    test('provider checks for archived partnership when none found', () {
      expect(
        providerContent.contains('getLastArchivedPartnership'),
        isTrue,
        reason: 'currentPartnershipProvider must check for archived '
            'partnerships when no active/pending partnership exists.',
      );
    });

    test('provider creates new partnership for orphaned user', () {
      expect(
        providerContent.contains('createPartnership'),
        isTrue,
        reason: 'currentPartnershipProvider must create a new pending '
            'partnership when the user has been unlinked.',
      );
    });

    test('provider migrates expenses from archived partnership', () {
      expect(
        providerContent.contains('migrateUserExpenses'),
        isTrue,
        reason: 'currentPartnershipProvider must migrate the user\'s expenses '
            'from the archived partnership to the new pending one.',
      );
    });

    test('migration happens after partnership creation', () {
      final createIdx = providerContent.indexOf('createPartnership');
      final migrateIdx = providerContent.indexOf(
        'migrateUserExpenses',
        createIdx,
      );
      expect(createIdx, greaterThan(-1));
      expect(
        migrateIdx,
        greaterThan(createIdx),
        reason: 'Expenses must be migrated after the new partnership is '
            'created (need a target partnership_id).',
      );
    });
  });

  group('PartnershipRepository.getLastArchivedPartnership', () {
    test('method exists', () {
      expect(
        repoContent.contains('Future<Partnership?> getLastArchivedPartnership'),
        isTrue,
        reason: 'PartnershipRepository must have getLastArchivedPartnership '
            'to find archived partnerships for the lazy migration.',
      );
    });

    test('queries archived status', () {
      final methodStart =
          repoContent.indexOf('getLastArchivedPartnership');
      final methodBody = repoContent.substring(
        methodStart,
        repoContent.indexOf('}', methodStart + 50) + 1,
      );
      expect(
        methodBody.contains("'archived'"),
        isTrue,
        reason: 'Must filter by archived status.',
      );
    });

    test('checks both user1_id and user2_id', () {
      final methodStart =
          repoContent.indexOf('getLastArchivedPartnership');
      final methodBody = repoContent.substring(
        methodStart,
        repoContent.indexOf('}', methodStart + 50) + 1,
      );
      expect(
        methodBody.contains('user1_id') && methodBody.contains('user2_id'),
        isTrue,
        reason: 'Must check both user1_id and user2_id since the unlinked '
            'partner could be either one.',
      );
    });
  });
}
