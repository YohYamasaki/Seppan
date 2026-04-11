import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../pages/auth/invite_page.dart';
import '../pages/auth/email_auth_page.dart';
import '../pages/auth/profile_setup_page.dart';
import '../pages/auth/qr_scanner_page.dart';
import '../pages/auth/sign_in_page.dart';
import '../pages/history/history_detail_page.dart';
import '../pages/history/history_page.dart';
import '../pages/home/home_page.dart';
import '../pages/stats/category_detail_page.dart';
import '../pages/stats/stats_page.dart';
import '../pages/expense_input/expense_input_page.dart';
import '../pages/settings/category_edit_page.dart';
import '../pages/settings/partnership_manage_page.dart';
import '../pages/settings/profile_edit_page.dart';
import '../pages/settings/settings_page.dart';
import '../pages/shell/main_shell.dart';
import '../providers/auth_provider.dart';
import '../providers/partnership_provider.dart';
import '../utils/router_redirect.dart';

part 'router.g.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@riverpod
GoRouter router(Ref ref) {
  // Watch these to rebuild router on auth/profile/partnership changes
  ref.watch(authStateChangesProvider);
  final profile = ref.watch(currentProfileProvider);
  ref.watch(activePartnershipProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/home',
    redirect: (context, state) {
      final user = ref.read(currentUserProvider);
      return routerRedirect(
        location: state.matchedLocation,
        isLoggedIn: user != null,
        isProfileLoading: profile.isLoading,
        hasProfile: profile.valueOrNull != null,
      );
    },
    routes: [
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
    ],
  );
}
