import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying that partner account deletion is handled:
/// 1. Server-side RPC archives partnerships when a user is deleted.
/// 2. Client-side pull-to-refresh detects the change.
/// 3. Router does NOT watch activePartnershipProvider (avoids animation bug
///    and allows safe invalidation on refresh).
void main() {
  final routerFile = File('lib/config/router.dart');
  final homeFile = File('lib/pages/home/home_page.dart');
  final authRepoFile = File('lib/repositories/auth_repository.dart');

  late String routerContent;
  late String homeContent;
  late String authRepoContent;

  setUpAll(() {
    routerContent = routerFile.readAsStringSync();
    homeContent = homeFile.readAsStringSync();
    authRepoContent = authRepoFile.readAsStringSync();
  });

  group('Router does not watch activePartnershipProvider', () {
    test('router.dart does not import partnership_provider', () {
      expect(
        routerContent.contains("partnership_provider.dart"),
        isFalse,
        reason: 'Router should not import partnership_provider. '
            'Watching activePartnershipProvider in the router causes '
            'transition animations on pull-to-refresh.',
      );
    });

    test('router does not watch activePartnershipProvider', () {
      expect(
        routerContent.contains('activePartnershipProvider'),
        isFalse,
        reason: 'Router must NOT watch activePartnershipProvider. '
            'The redirect logic only needs auth state and profile.',
      );
    });
  });

  group('Home page refresh detects partner deletion', () {
    test('pull-to-refresh invalidates activePartnershipProvider', () {
      expect(
        homeContent.contains('invalidate(activePartnershipProvider)'),
        isTrue,
        reason: 'Home page must invalidate activePartnershipProvider on '
            'pull-to-refresh so that partner deletion is detected.',
      );
    });

    test('pull-to-refresh invalidates currentPartnershipProvider', () {
      expect(
        homeContent.contains('invalidate(currentPartnershipProvider)'),
        isTrue,
        reason: 'Home page must invalidate currentPartnershipProvider on '
            'pull-to-refresh.',
      );
    });

    test('pull-to-refresh invalidates partnerProfileProvider', () {
      expect(
        homeContent.contains('invalidate(partnerProfileProvider)'),
        isTrue,
        reason: 'Home page must invalidate partnerProfileProvider on '
            'pull-to-refresh so stale partner info is cleared.',
      );
    });
  });

  group('Server-side deletion handles partnership cleanup', () {
    test('delete_user_data RPC is used for account deletion', () {
      expect(
        authRepoContent.contains("'delete_user_data'"),
        isTrue,
        reason: 'Account deletion must use the delete_user_data RPC which '
            'archives partnerships for the remaining partner.',
      );
    });
  });
}
