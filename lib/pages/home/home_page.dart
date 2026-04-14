import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../widgets/balance_card.dart';
import '../../widgets/category_chart_card.dart';
import '../../widgets/expense_tile.dart';
import '../../widgets/main_card.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final profile = ref.watch(currentProfileProvider);
    final partnerProfile = ref.watch(partnerProfileProvider);
    final partnership = ref.watch(activePartnershipProvider);
    final currentPship = ref.watch(currentPartnershipProvider);
    final balance = ref.watch(balanceSummaryProvider);
    final recentExpenses = ref.watch(recentExpensesProvider);
    final categoryBreakdown = ref.watch(categoryBreakdownProvider);

    final isPartnershipLoading = partnership.isLoading && !partnership.hasValue;
    final hasActivePartnership = partnership.valueOrNull != null;
    final hasAnyPartnership = currentPship.valueOrNull != null;
    final myProfile = profile.valueOrNull;
    final myName = myProfile?.displayName ?? '';
    final myIconId = myProfile?.iconId ?? 1;
    final partnerName = partnerProfile.valueOrNull?.displayName ?? 'パートナー';
    final partnerIconId = partnerProfile.valueOrNull?.iconId ?? 1;
    final now = DateTime.now();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activePartnershipProvider);
            ref.invalidate(currentPartnershipProvider);
            ref.invalidate(balanceSummaryProvider);
            ref.invalidate(recentExpensesProvider);
            ref.invalidate(partnerProfileProvider);
            ref.invalidate(categoryBreakdownProvider);
            // Wait for key data to reload before dismissing the indicator
            await Future.wait([
              ref.read(recentExpensesProvider.future),
              ref.read(balanceSummaryProvider.future),
            ]);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const Gap(8),

              // Loading placeholder while partnership state resolves
              if (isPartnershipLoading) const _LoadingCard(),

              // Partnership link prompt
              if (!isPartnershipLoading && !hasActivePartnership)
                MainCard(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 48,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                        const Gap(12),
                        const Text(
                          'リンクされていません',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          'パートナーとリンクしてください',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        const Gap(12),
                        TextButton(
                          onPressed: () => context.push('/invite'),
                          child: const Text('リンクはこちら'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Balance card (A1) — only when linked
              if (hasActivePartnership)
                balance.when(
                  data: (bal) => BalanceCard(
                    myName: myName,
                    myIconId: myIconId,
                    partnerName: partnerName,
                    partnerIconId: partnerIconId,
                    balance: bal,
                  ),
                  loading: () {
                    // Show previous data while refreshing
                    final prev = balance.valueOrNull;
                    if (prev != null) {
                      return BalanceCard(
                        myName: myName,
                        myIconId: myIconId,
                        partnerName: partnerName,
                        partnerIconId: partnerIconId,
                        balance: prev,
                      );
                    }
                    return const _LoadingCard();
                  },
                  error: (e, _) => Center(child: Text('エラー: $e')),
                ),

              // Category chart (C2) — show even when pending
              if (hasAnyPartnership)
                categoryBreakdown.when(
                  data: (breakdown) => breakdown.isNotEmpty
                      ? CategoryChartCard(
                          breakdown: breakdown,
                          month: now,
                          userName: myName,
                          onTap: () => context.go('/stats'),
                        )
                      : const SizedBox.shrink(),
                  loading: () {
                    final prev = categoryBreakdown.valueOrNull;
                    if (prev != null && prev.isNotEmpty) {
                      return CategoryChartCard(
                        breakdown: prev,
                        month: now,
                        userName: myName,
                        onTap: () => context.go('/stats'),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  error: (e, _) => Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('カテゴリ取得エラー: $e'),
                  ),
                ),

              // Recent history
              MainCard(
                onTap: () => context.go('/history'),
                header: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '履歴',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    Row(
                      children: [
                        Text(
                          'もっと見る',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const Gap(4),
                        Icon(
                          Icons.chevron_right,
                          size: 20,
                          color: colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                child: recentExpenses.when(
                  data: (expenses) {
                    if (expenses.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('まだ支払いがありません')),
                      );
                    }
                    final currentUser = ref.read(currentUserProvider);
                    final currentProfile = profile.valueOrNull;
                    return Column(
                      children: expenses.map((expense) {
                        final isMe = expense.paidBy == currentUser?.id;
                        final myBurdenPct = isMe
                            ? (expense.ratio * 100).round()
                            : ((1 - expense.ratio) * 100).round();
                        return ExpenseSimpleTile(
                          payerName: isMe
                              ? (currentProfile?.displayName ?? '')
                              : partnerName,
                          payerIconId: isMe ? myIconId : partnerIconId,
                          amount: expense.amount,
                          burdenPercent: myBurdenPct,
                        );
                      }).toList(),
                    );
                  },
                  loading: () {
                    final prev = recentExpenses.valueOrNull;
                    if (prev != null && prev.isNotEmpty) {
                      final currentUser = ref.read(currentUserProvider);
                      final currentProfile = profile.valueOrNull;
                      return Column(
                        children: prev.map((expense) {
                          final isMe = expense.paidBy == currentUser?.id;
                          final myBurdenPct = isMe
                              ? (expense.ratio * 100).round()
                              : ((1 - expense.ratio) * 100).round();
                          return ExpenseSimpleTile(
                            payerName: isMe
                                ? (currentProfile?.displayName ?? '')
                                : partnerName,
                            payerIconId: isMe ? myIconId : partnerIconId,
                            amount: expense.amount,
                            burdenPercent: myBurdenPct,
                          );
                        }).toList(),
                      );
                    }
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  },
                  error: (e, _) => Center(child: Text('エラー: $e')),
                ),
              ),
              const Gap(80),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/expense-input'),
        icon: const Icon(CupertinoIcons.pencil),
        label: const Text('支払を入力する'),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const MainCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
