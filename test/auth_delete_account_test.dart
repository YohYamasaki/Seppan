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
