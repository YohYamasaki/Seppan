import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../pages/loading_page.dart';
import '../pages/auth/encryption_setup_page.dart';
import '../pages/auth/encryption_unlock_page.dart';
import '../pages/auth/fingerprint_verification_page.dart';
import '../pages/auth/invite_page.dart';
import '../pages/auth/email_auth_page.dart';
import '../pages/auth/profile_setup_page.dart';
import '../pages/auth/qr_scanner_page.dart';
import '../pages/auth/sign_in_page.dart';
import '../models/partnership.dart';
import '../pages/history/history_detail_page.dart';
import '../pages/history/history_page.dart';
import '../pages/home/home_page.dart';
import '../pages/stats/category_detail_page.dart';
import '../pages/stats/stats_page.dart';
import '../pages/expense_input/expense_input_page.dart';
import '../pages/settings/category_edit_page.dart';
import '../pages/settings/partnership_manage_page.dart';
import '../pages/settings/encryption_settings_page.dart';
import '../pages/settings/privacy_policy_page.dart';
import '../pages/settings/profile_edit_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/settings/terms_page.dart';
import '../pages/shell/main_shell.dart';
import '../providers/auth_provider.dart';
import '../providers/encryption_provider.dart';
import '../utils/router_redirect.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(Ref ref) {
  // Use listen + refreshListenable so the GoRouter instance is created once.
  // ref.watch would recreate the entire GoRouter on every state change,
  // resetting navigation to initialLocation and causing screen flashes.
  final refreshNotifier = ValueNotifier<int>(0);
  ref.listen(authStateChangesProvider, (_, __) => refreshNotifier.value++);
  // Only refresh when profile loading completes (loading → data/error),
  // NOT on every state change. An invalidate (data → loading) must not
  // trigger a refresh — that would cause GoRouter to rebuild the route
  // tree and cancel in-progress navigation (e.g. context.pop).
  ref.listen(currentProfileProvider, (prev, next) {
    final wasLoading = prev == null || prev.isLoading;
    if (wasLoading && !next.isLoading) {
      refreshNotifier.value++;
    }
  });
  // Refresh router when encryption unlock check completes.
  // The encryptionUnlockRequiredProvider handles everything:
  // local cache restore, server check, and reactive re-evaluation.
  ref.listen<AsyncValue<bool>>(encryptionUnlockRequiredProvider, (prev, next) {
    debugPrint('[router] encryptionUnlock: $prev → $next');
    if (prev == null || prev.isLoading || prev.valueOrNull != next.valueOrNull) {
      debugPrint('[router] encryptionUnlock triggered refresh');
      refreshNotifier.value++;
    }
  });
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/loading',
    refreshListenable: refreshNotifier,
    observers: [
      FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
    ],
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      final profile = ref.read(currentProfileProvider);
      final unlockCheck = ref.read(encryptionUnlockRequiredProvider);
      debugPrint('[router] redirect: loc=${state.matchedLocation}, '
          'user=${user != null}, profileLoading=${profile.isLoading}, '
          'hasProfile=${profile.valueOrNull != null}, '
          'unlockCheck=$unlockCheck');
      final result = routerRedirect(
        location: state.matchedLocation,
        isLoggedIn: user != null,
        isProfileLoading: profile.isLoading,
        hasProfile: profile.valueOrNull != null,
        needsEncryptionUnlock: unlockCheck.valueOrNull == true,
        isEncryptionCheckLoading: unlockCheck.isLoading,
      );
      debugPrint('[router] redirect result: $result');
      return result;
    },
    routes: [
      // Loading / splash
      GoRoute(
        path: '/loading',
        builder: (context, state) => const LoadingPage(),
      ),

      // Auth flow
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const SignInPage(),
        routes: [
          GoRoute(
            path: 'email',
            builder: (context, state) => const EmailAuthPage(),
          ),
          GoRoute(
            path: 'qr-scan',
            builder: (context, state) => const QrScannerPage(),
          ),
        ],
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupPage(),
      ),
      GoRoute(
        path: '/invite',
        builder: (context, state) => const InvitePage(),
        routes: [
          GoRoute(
            path: 'qr-scan',
            builder: (context, state) => const QrScannerPage(),
          ),
        ],
      ),

      // Encryption flow
      GoRoute(
        path: '/fingerprint-verification',
        redirect: (context, state) =>
            state.extra == null ? '/home' : null,
        builder: (context, state) {
          final extra = state.extra! as Map<String, dynamic>;
          return FingerprintVerificationPage(
            partnership: extra['partnership'] as Partnership,
            myKeyPair: extra['myKeyPair'] as SimpleKeyPair,
            myPubKey: extra['myPubKey'] as SimplePublicKey,
            peerPubKey: extra['peerPubKey'] as SimplePublicKey,
            isInitiator: extra['isInitiator'] as bool,
          );
        },
      ),
      GoRoute(
        path: '/encryption-setup',
        redirect: (context, state) =>
            state.extra == null ? '/home' : null,
        builder: (context, state) {
          final extra = state.extra! as Map<String, dynamic>;
          return EncryptionSetupPage(
            partnership: extra['partnership'] as Partnership,
            rawKey: extra['rawKey'] as Uint8List,
            nextRoute: extra['nextRoute'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/encryption-unlock',
        builder: (context, state) => const EncryptionUnlockPage(),
      ),

      // Main shell with bottom navigation
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/home',
                builder: (context, state) => const HomePage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/stats',
                builder: (context, state) => const StatsPage(),
                routes: [
                  GoRoute(
                    path: 'category-detail',
                    builder: (context, state) => CategoryDetailPage(
                      category: state.uri.queryParameters['category'] ?? '',
                      year: int.parse(
                          state.uri.queryParameters['year'] ?? '2026'),
                      month: int.parse(
                          state.uri.queryParameters['month'] ?? '1'),
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (context, state) => const HistoryPage(),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => HistoryDetailPage(
                      expenseId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'profile-edit',
                    builder: (context, state) => const ProfileEditPage(),
                  ),
                  GoRoute(
                    path: 'category-edit',
                    builder: (context, state) => const CategoryEditPage(),
                  ),
                  GoRoute(
                    path: 'partnership',
                    builder: (context, state) =>
                        const PartnershipManagePage(),
                  ),
                  GoRoute(
                    path: 'privacy-policy',
                    builder: (context, state) =>
                        const PrivacyPolicyPage(),
                  ),
                  GoRoute(
                    path: 'terms',
                    builder: (context, state) =>
                        const TermsPage(),
                  ),
                  GoRoute(
                    path: 'encryption',
                    builder: (context, state) =>
                        const EncryptionSettingsPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),

      // Expense input (full-screen modal)
      GoRoute(
        path: '/expense-input',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ExpenseInputPage(),
      ),

      // History as full-screen push route (from home "もっと見る").
      // Pushed on root navigator so back navigation returns to home,
      // unlike the /history tab which switches tabs in the shell.
      GoRoute(
        path: '/history-view',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const HistoryPage(),
      ),

      // Stats as full-screen push route (from home's category card).
      // Same pattern as /history-view — pushed on root navigator so
      // back navigation returns to home.
      GoRoute(
        path: '/stats-view',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const StatsPage(),
        routes: [
          GoRoute(
            path: 'category-detail',
            parentNavigatorKey: _rootNavigatorKey,
            builder: (context, state) => CategoryDetailPage(
              category: state.uri.queryParameters['category'] ?? '',
              year: int.parse(
                  state.uri.queryParameters['year'] ?? '2026'),
              month: int.parse(
                  state.uri.queryParameters['month'] ?? '1'),
            ),
          ),
        ],
      ),
    ],
  );
}
