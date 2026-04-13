import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../models/partnership.dart';
import '../../providers/auth_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../widgets/avatar_icon.dart';
import '../auth/invite_page.dart';

class PartnershipManagePage extends ConsumerWidget {
  const PartnershipManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnership = ref.watch(activePartnershipProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('パートナーシップ管理')),
      body: partnership.when(
        data: (p) {
          if (p == null) {
            return const InvitePage(showScaffold: false);
          }

          final profile = ref.watch(currentProfileProvider).valueOrNull;
          final partnerProfile =
              ref.watch(partnerProfileProvider).valueOrNull;
          final myName = profile?.displayName ?? '';
          final myIconId = profile?.iconId ?? 1;
          final partnerName = partnerProfile?.displayName ?? 'パートナー';
          final partnerIconId = partnerProfile?.iconId ?? 1;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Partner link card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // Avatars row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Column(
                              children: [
                                AvatarIcon(iconId: myIconId, radius: 32),
                                const Gap(8),
                                Text(myName,
                                    style: theme.textTheme.bodyLarge),
                              ],
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 24),
                              child: Icon(Icons.link,
                                  size: 28, color: colorScheme.primary),
                            ),
                            Column(
                              children: [
                                AvatarIcon(
                                    iconId: partnerIconId, radius: 32),
                                const Gap(8),
                                Text(partnerName,
                                    style: theme.textTheme.bodyLarge),
                              ],
                            ),
                          ],
                        ),
                        const Gap(16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'リンク済み',
                            style: TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Gap(16),

                const Spacer(),

                // Unlink button
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.link_off),
                  label: const Text('パートナーシップを解除'),
                  onPressed: () => _confirmArchive(context, ref, p),
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

  Future<void> _confirmArchive(
      BuildContext context, WidgetRef ref, Partnership partnership) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('パートナーシップを解除しますか？'),
        content: const Text('これまでに入力した支払い履歴はお互いのアカウントからすべて削除されます。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('解除'),
          ),
        ],
      ),
    );
    if (result == true) {
      final repo = ref.read(partnershipRepositoryProvider);

      try {
        // Delete all expenses for this partnership before archiving.
        final expenseRepo = ref.read(expenseRepositoryProvider);
        await expenseRepo.deleteAllExpenses(partnership.id);

        await repo.archivePartnership(partnership.id);

        ref.invalidate(activePartnershipProvider);
        ref.invalidate(currentPartnershipProvider);
        ref.invalidate(partnerProfileProvider);
        ref.invalidate(recentExpensesProvider);
        ref.invalidate(balanceSummaryProvider);
        ref.invalidate(categoryBreakdownProvider);
        if (context.mounted) {
          context.go('/home');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('パートナーシップの解除に失敗しました: $e')),
          );
        }
      }
    }
  }
}
