import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/balance_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          if (index != navigationShell.currentIndex) {
            // Invalidate reactive providers (home auto-refreshes via ref.watch)
            ref.invalidate(recentExpensesProvider);
            ref.invalidate(balanceSummaryProvider);
            ref.invalidate(categoryBreakdownProvider);
            ref.invalidate(partnerProfileProvider);
            // Bump version to trigger refresh in stateful pages
            ref.read(expenseDataVersionProvider.notifier).state++;
          }
          // Settings tab (index 3): always reset to /settings top
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex || index == 3,
          );
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: 'ホーム',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.chart_pie),
            label: '統計',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.doc_text),
            label: '履歴',
          ),
          BottomNavigationBarItem(icon: Icon(CupertinoIcons.gear), label: '設定'),
        ],
      ),
    );
  }
}
