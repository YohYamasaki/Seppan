import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the "home → history-view → detail" navigation
/// flow.
///
/// HistoryPage is rendered in two places:
///   * `/history` — the bottom-nav tab inside the StatefulShellRoute
///   * `/history-view` — a root-navigator push from the home screen
///
/// Both instances can exist at the same time while the user is on
/// `/history-view`, because the shell's tab state is preserved. If
/// HistoryPage always pushes `/history/:id` (the in-shell detail
/// route), go_router tries to mount the detail page under the shell's
/// history branch while a HistoryPage is also on the root navigator.
/// This produces a `!keyReservation.contains(key)` assertion failure.
///
/// Fix:
///   * Router defines a sibling `/history-view/:id` route on the root
///     navigator.
///   * HistoryPage inspects the current matchedLocation and pushes to
///     `/history-view/:id` when it was reached from the home flow,
///     and `/history/:id` when it was reached from the shell tab.
///
/// These tests are structural — they grep the source files — so that
/// the guard sticks even if the actual widget wiring changes.
void main() {
  group('router.dart defines both history detail routes', () {
    late String routerSource;

    setUpAll(() {
      routerSource = File('lib/config/router.dart').readAsStringSync();
    });

    test('/history-view has a :id child route', () {
      // Capture everything between `path: '/history-view'` and the
      // matching closing of the GoRoute. The `:id` child must appear
      // within this block.
      final match = RegExp(
        r"path:\s*'/history-view'[\s\S]*?routes:\s*\[([\s\S]*?)\],\s*\),",
      ).firstMatch(routerSource);
      expect(
        match,
        isNotNull,
        reason:
            '/history-view must define a `routes:` child list (with a `:id` detail route) '
            'so pushes from the history-view flow stay on the root navigator.',
      );
      final childBlock = match!.group(1)!;
      expect(
        childBlock,
        contains("path: ':id'"),
        reason:
            '/history-view must have a `:id` child route on the root navigator. '
            'Without it, tapping a tile pushes /history/:id through the shell, '
            'colliding with the existing HistoryPage on the root navigator.',
      );
      expect(
        childBlock,
        contains('parentNavigatorKey: _rootNavigatorKey'),
        reason:
            'The /history-view/:id child must set parentNavigatorKey: '
            '_rootNavigatorKey so it stays on the root navigator '
            '(matching its parent).',
      );
    });

    test('/history (shell branch) still has a :id child route', () {
      // Sanity check — we should not have accidentally broken the
      // shell-scoped detail route in the process.
      expect(
        routerSource,
        contains("path: '/history'"),
        reason: 'The /history shell branch must still exist.',
      );
      // The `:id` child is inside the shell branch too — grep for
      // HistoryDetailPage usage to confirm it's wired up at all.
      expect(
        routerSource,
        contains('HistoryDetailPage('),
        reason: 'HistoryDetailPage must still be routed somewhere.',
      );
      // Expect TWO HistoryDetailPage builder sites: one for the shell
      // branch /history/:id, one for the root /history-view/:id.
      final count =
          'HistoryDetailPage('.allMatches(routerSource).length;
      expect(
        count,
        2,
        reason:
            'HistoryDetailPage should be wired in exactly 2 routes: '
            'the shell branch /history/:id and the root /history-view/:id. '
            'Found $count.',
      );
    });
  });

  group('HistoryPage picks the correct detail path based on location', () {
    late String historyPageSource;

    setUpAll(() {
      historyPageSource =
          File('lib/pages/history/history_page.dart').readAsStringSync();
    });

    test('uses GoRouterState.of(context).matchedLocation to branch', () {
      expect(
        historyPageSource,
        contains('GoRouterState.of(context).matchedLocation'),
        reason:
            'HistoryPage must inspect the current matched location to '
            'decide whether to push /history/:id or /history-view/:id. '
            'Without this branching, the tile onTap always targets the '
            'shell-branch detail route and causes a GlobalKey collision '
            'when accessed from the /history-view flow.',
      );
    });

    test('detail push uses /history-view/... when on /history-view', () {
      expect(
        historyPageSource,
        matches(
          RegExp(
            r"/history-view['/]",
          ),
        ),
        reason:
            'HistoryPage must push a /history-view/... path when reached '
            'from the home flow.',
      );
    });

    test('detail push still supports the shell /history/:id path', () {
      expect(
        historyPageSource,
        contains("'/history'"),
        reason:
            'HistoryPage must still use /history/... when running inside '
            'the shell tab, to avoid unnecessary cross-navigator pushes.',
      );
    });
  });
}
