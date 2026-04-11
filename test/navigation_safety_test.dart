import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural test to prevent go_router duplicate page key errors.
///
/// Pages rendered on the root navigator (e.g. /expense-input) must NOT use
/// context.push() or context.go() to navigate to shell-nested routes
/// (e.g. /settings/category-edit). Doing so causes a
/// '!keyReservation.contains(key)' assertion error because go_router tries
/// to mount a shell branch route on the root navigator.
///
/// Instead, use Navigator.of(context).push(MaterialPageRoute(...)) to bypass
/// go_router for these cross-navigator navigations.
void main() {
  // Pages that are mounted on the root navigator (parentNavigatorKey: _rootNavigatorKey)
  // and must not use context.push/go to shell-nested routes.
  const rootNavigatorPages = [
    'lib/pages/expense_input/expense_input_page.dart',
  ];

  // Shell-nested route prefixes that must not be targeted via context.push/go
  // from root navigator pages.
  const shellRoutePrefixes = [
    '/settings/',
    '/history/',
    '/home',
  ];

  group('Root navigator pages must not use context.push to shell routes', () {
    for (final pagePath in rootNavigatorPages) {
      test('$pagePath does not context.push to shell routes', () {
        final file = File(pagePath);
        expect(file.existsSync(), isTrue, reason: '$pagePath should exist');

        final content = file.readAsStringSync();
        for (final prefix in shellRoutePrefixes) {
          // Match context.push('/settings/...') or context.go('/settings/...')
          final pushPattern = RegExp("context\\.push\\('$prefix");
          final goPattern = RegExp("context\\.go\\('$prefix");

          expect(
            pushPattern.hasMatch(content),
            isFalse,
            reason:
                '$pagePath must not use context.push to shell route $prefix — '
                'use Navigator.of(context).push(MaterialPageRoute(...)) instead',
          );
          expect(
            goPattern.hasMatch(content),
            isFalse,
            reason:
                '$pagePath must not use context.go to shell route $prefix — '
                'use Navigator.of(context).push(MaterialPageRoute(...)) instead',
          );
        }
      });
    }
  });
}
