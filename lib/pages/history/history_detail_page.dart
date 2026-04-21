import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/avatar_icon.dart';
import '../../widgets/ratio_bar.dart';
import '../expense_input/expense_input_page.dart';

class HistoryDetailPage extends ConsumerWidget {
  const HistoryDetailPage({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenseFuture = ref.watch(expenseDetailProvider(expenseId));

    return Scaffold(
      appBar: AppBar(title: const Text('詳細')),
      body: expenseFuture.when(
        data: (expense) {
          if (expense == null) {
            return const Center(child: Text('データが見つかりません'));
          }
          final user = ref.read(currentUserProvider);
          final profile = ref.read(currentProfileProvider).valueOrNull;
          final partnerProfile = ref.read(partnerProfileProvider).valueOrNull;
          final isMe = expense.paidBy == user?.id;
          final payerName = isMe
              ? (profile?.displayName ?? '')
              : (partnerProfile?.displayName ?? 'パートナー');
          final payerIconId = isMe
              ? (profile?.iconId ?? 1)
              : (partnerProfile?.iconId ?? 1);
          final myName = profile?.displayName ?? '';
          final myIconId = profile?.iconId ?? 1;
          final partnerName = partnerProfile?.displayName ?? 'パートナー';
          final partnerIconId = partnerProfile?.iconId ?? 1;
          final myPercent = isMe ? expense.ratio : 1 - expense.ratio;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date
                _DetailRow(label: '日付', value: formatDate(expense.date)),
                const Divider(),
                const Gap(8),

                // Payer
                Row(
                  children: [
                    AvatarIcon(iconId: payerIconId, radius: 28),
                    const Gap(16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('支払者',
                            style: Theme.of(context).textTheme.bodySmall),
                        Text(payerName,
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ],
                ),
                const Gap(16),

                // Amount
                _DetailRow(label: '金額', value: formatJpy(expense.amount)),
                const Gap(8),
                Text('負担率',
                    style: Theme.of(context).textTheme.bodySmall),
                const Gap(8),
                RatioBar(
                  myPercent: myPercent,
                  myName: myName,
                  myIconId: myIconId,
                  partnerName: partnerName,
                  partnerIconId: partnerIconId,
                  amount: expense.amount,
                ),
                const Gap(8),
                if (expense.category.isNotEmpty)
                  _DetailRow(label: 'ジャンル', value: expense.category),
                if (expense.memo.isNotEmpty)
                  _DetailRow(label: 'メモ', value: expense.memo),

                const Spacer(),

                // Edit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('編集'),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ExpenseInputPage(editExpense: expense),
                        ),
                      );
                      // Refresh everything that could reflect an edit:
                      // detail view (this page), home previews, monthly
                      // breakdown / balance summaries, and both HistoryPage
                      // instances (/history tab + /history-view root push)
                      // via the version-bump signal.
                      //
                      // ExpenseInputPage._submit() already does this on
                      // successful save, but we re-invalidate here as a
                      // safety net — harmless if the user just cancelled
                      // (nothing changed in the DB), essential if the
                      // listener timing is off (e.g. HistoryPage widget
                      // was not mounted when the save fired).
                      ref.invalidate(expenseDetailProvider(expenseId));
                      ref.invalidate(recentExpensesProvider);
                      ref.invalidate(balanceSummaryProvider);
                      ref.invalidate(categoryBreakdownProvider);
                      ref.read(expenseDataVersionProvider.notifier).state++;
                    },
                  ),
                ),
                const Gap(12),

                // Delete button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size.fromHeight(48),
                    ),
                    icon: const Icon(Icons.delete),
                    label: const Text('削除'),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('本当に削除しますか？'),
                          content: const Text('この操作は取り消せません。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('キャンセル'),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                  foregroundColor: Colors.red),
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('削除'),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref
                            .read(expenseRepositoryProvider)
                            .deleteExpense(expenseId);
                        ref.invalidate(recentExpensesProvider);
                        ref.invalidate(balanceSummaryProvider);
                        ref.invalidate(categoryBreakdownProvider);
                        ref.read(expenseDataVersionProvider.notifier).state++;
                        if (context.mounted) context.pop();
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('エラー: $e')),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
