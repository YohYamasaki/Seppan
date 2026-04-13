import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests for account deletion safety.
void main() {
  final settingsFile = File('lib/pages/settings/settings_page.dart');
  final authRepoFile = File('lib/repositories/auth_repository.dart');

  group('Account deletion', () {
    late String settingsContent;
    late String authRepoContent;

    setUpAll(() {
      settingsContent = settingsFile.readAsStringSync();
      authRepoContent = authRepoFile.readAsStringSync();
    });

    test('settings page calls deleteAccount, not just signOut', () {
      expect(
        settingsContent.contains('deleteAccount'),
        isTrue,
        reason: 'Settings page should call deleteAccount() for account '
            'deletion, not just signOut() or deleteProfile().',
      );
    });

    test('settings page does not call deleteProfile directly', () {
      final deleteSection = RegExp(
        r'_confirmDelete[\s\S]*?^\s*\}',
        multiLine: true,
      ).firstMatch(settingsContent)?.group(0) ?? '';

      expect(
        deleteSection.contains('deleteProfile'),
        isFalse,
        reason: 'Settings page should not call deleteProfile directly. '
            'AuthRepository.deleteAccount() handles data cleanup.',
      );
    });

    test('navigates to sign-in after account deletion', () {
      expect(
        settingsContent.contains("context.go('/sign-in')"),
        isTrue,
        reason: 'After account deletion, user should be navigated to '
            'the sign-in page.',
      );
    });

    test('account deletion has error handling', () {
      final hasErrorHandling = RegExp(
        r'try\s*\{[\s\S]*?deleteAccount[\s\S]*?catch',
      ).hasMatch(settingsContent);

      expect(
        hasErrorHandling,
        isTrue,
        reason: 'Account deletion should be wrapped in try-catch.',
      );
    });

    test('AuthRepository has deleteAccount method', () {
      expect(
        authRepoContent.contains('Future<void> deleteAccount()'),
        isTrue,
        reason: 'AuthRepository should have a deleteAccount() method.',
      );
    });
  });

  group('Account deletion uses server-side RPC', () {
    late String authRepoContent;

    setUpAll(() {
      authRepoContent = authRepoFile.readAsStringSync();
    });

    test('uses delete_user_data RPC', () {
      expect(
        authRepoContent.contains("supabase.rpc"),
        isTrue,
        reason: 'deleteAccount must use supabase.rpc() to call a '
            'SECURITY DEFINER function for FK-safe deletion.',
      );
      expect(
        authRepoContent.contains("'delete_user_data'"),
        isTrue,
        reason: 'deleteAccount must call the delete_user_data RPC.',
      );
    });

    test('does not attempt client-side partnerships delete', () {
      // Client-side DELETE/UPDATE on partnerships fails due to RLS.
      // All cleanup must go through the RPC.
      final deleteAccountBody = RegExp(
        r'Future<void> deleteAccount\(\)[\s\S]*?^  \}',
        multiLine: true,
      ).firstMatch(authRepoContent)?.group(0) ?? '';

      expect(
        deleteAccountBody.contains("from('partnerships')"),
        isFalse,
        reason: 'deleteAccount must NOT do client-side '
            'partnerships delete/update. RLS blocks user2 from '
            'modifying partnerships they do not own. '
            'All cleanup must go through the SECURITY DEFINER RPC.',
      );
    });

    test('does not attempt client-side profiles delete', () {
      final deleteAccountBody = RegExp(
        r'Future<void> deleteAccount\(\)[\s\S]*?^  \}',
        multiLine: true,
      ).firstMatch(authRepoContent)?.group(0) ?? '';

      expect(
        deleteAccountBody.contains("from('profiles')"),
        isFalse,
        reason: 'deleteAccount must NOT do client-side profiles delete. '
            'FK constraints require partnerships to be cleaned up first, '
            'which can only be done reliably via the RPC.',
      );
    });

    test('signs out after RPC call', () {
      final deleteAccountBody = RegExp(
        r'Future<void> deleteAccount\(\)[\s\S]*?^  \}',
        multiLine: true,
      ).firstMatch(authRepoContent)?.group(0) ?? '';

      final rpcIdx = deleteAccountBody.indexOf('supabase.rpc');
      final signOutIdx = deleteAccountBody.indexOf('signOut');
      expect(rpcIdx, greaterThan(-1));
      expect(signOutIdx, greaterThan(rpcIdx),
          reason: 'signOut must happen after RPC completes.');
    });
  });

  group('Partner data preservation on account deletion', () {
    final partnershipRepoFile =
        File('lib/repositories/partnership_repository.dart');
    final expenseRepoFile = File('lib/repositories/expense_repository.dart');
    final partnershipProviderFile =
        File('lib/providers/partnership_provider.dart');

    late String settingsContent;
    late String partnershipRepoContent;
    late String expenseRepoContent;
    late String providerContent;

    setUpAll(() {
      settingsContent = settingsFile.readAsStringSync();
      partnershipRepoContent = partnershipRepoFile.readAsStringSync();
      expenseRepoContent = expenseRepoFile.readAsStringSync();
      providerContent = partnershipProviderFile.readAsStringSync();
    });

    test('detachUserFromPartnership method exists', () {
      expect(
        partnershipRepoContent.contains('detachUserFromPartnership'),
        isTrue,
        reason: 'PartnershipRepository must have detachUserFromPartnership '
            'to remove the deleting user from the partnership.',
      );
    });

    test('detachUserFromPartnership clears user2_id', () {
      final methodStart =
          partnershipRepoContent.indexOf('detachUserFromPartnership');
      final area = partnershipRepoContent.substring(
        methodStart,
        (methodStart + 800).clamp(0, partnershipRepoContent.length),
      );
      expect(area.contains('user2_id'), isTrue,
          reason: 'Must clear user2_id to protect partner data from RPC.');
    });

    test('detachUserFromPartnership does not change user1_id', () {
      // Changing user1_id would violate RLS — the current user is
      // removed from the row mid-update, causing a policy error.
      final methodStart = partnershipRepoContent.indexOf(
        'Future<void> detachUserFromPartnership',
      );
      final nextMethod = partnershipRepoContent.indexOf(
        'Stream<Partnership>',
        methodStart,
      );
      final methodBody = partnershipRepoContent.substring(
        methodStart,
        nextMethod,
      );
      expect(
        methodBody.contains("'user1_id'"),
        isFalse,
        reason: 'Must NOT update user1_id — that violates RLS.',
      );
    });

    test('detachUserFromPartnership archives the partnership', () {
      final methodStart =
          partnershipRepoContent.indexOf('detachUserFromPartnership');
      final area = partnershipRepoContent.substring(
        methodStart,
        (methodStart + 800).clamp(0, partnershipRepoContent.length),
      );
      expect(area.contains("'archived'"), isTrue,
          reason: 'Must set status to archived so lazy migration works.');
    });

    test('deleteUserExpenses method exists', () {
      expect(
        expenseRepoContent.contains('deleteUserExpenses'),
        isTrue,
        reason: 'ExpenseRepository must have deleteUserExpenses to '
            'delete only the user\'s own expenses from a partnership.',
      );
    });

    test('deleteUserExpenses filters by paid_by', () {
      final methodStart =
          expenseRepoContent.indexOf('deleteUserExpenses');
      final area = expenseRepoContent.substring(
        methodStart,
        (methodStart + 300).clamp(0, expenseRepoContent.length),
      );
      expect(area.contains('paid_by'), isTrue,
          reason: 'Must filter by paid_by to only delete user\'s expenses.');
    });

    test('settings page does not do client-side partnership cleanup', () {
      // All cleanup is handled by the server-side RPC (delete_user_data).
      // Client-side calls would be fragile and redundant.
      final deleteSection = RegExp(
        r'_confirmDelete[\s\S]*?^\s*\}',
        multiLine: true,
      ).firstMatch(settingsContent)?.group(0) ?? '';

      expect(
        deleteSection.contains('detachUserFromPartnership'),
        isFalse,
        reason: 'Settings page must NOT call detachUserFromPartnership. '
            'The RPC handles partnership cleanup server-side.',
      );
    });

    test('settings page does not do client-side expense cleanup', () {
      final deleteSection = RegExp(
        r'_confirmDelete[\s\S]*?^\s*\}',
        multiLine: true,
      ).firstMatch(settingsContent)?.group(0) ?? '';

      expect(
        deleteSection.contains('deleteUserExpenses'),
        isFalse,
        reason: 'Settings page must NOT call deleteUserExpenses. '
            'The RPC handles expense cleanup server-side.',
      );
    });

    test('lazy migration handles partner after account deletion', () {
      // The partner will have no active/pending partnership after deletion.
      // currentPartnershipProvider must check archived and migrate.
      expect(providerContent.contains('getLastArchivedPartnership'), isTrue,
          reason: 'Provider must check archived partnerships for lazy '
              'migration when partner\'s account is deleted.');
      expect(providerContent.contains('migrateUserExpenses'), isTrue,
          reason: 'Provider must migrate expenses from archived partnership.');
    });
  });

  group('Google sign-in account selection', () {
    late String authRepoContent;

    setUpAll(() {
      authRepoContent = authRepoFile.readAsStringSync();
    });

    test('Google sign-in includes select_account prompt', () {
      expect(
        authRepoContent.contains("'prompt': 'select_account'"),
        isTrue,
        reason: 'Google OAuth should include prompt: select_account.',
      );
    });

    test('Google sign-in uses external application launch mode', () {
      expect(
        authRepoContent.contains('LaunchMode.externalApplication'),
        isTrue,
        reason: 'Google OAuth should use externalApplication launch mode.',
      );
    });
  });
}
