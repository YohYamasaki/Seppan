import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../providers/partnership_provider.dart';
import '../auth/invite_page.dart';

class PartnershipManagePage extends ConsumerWidget {
  const PartnershipManagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partnership = ref.watch(activePartnershipProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('パートナーシップ管理')),
      body: partnership.when(
        data: (p) {
          if (p == null) {
            return const InvitePage();
          }
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ステータス',
                            style: Theme.of(context).textTheme.bodySmall),
                        const Gap(4),
                        Text(p.status,
                            style: Theme.of(context).textTheme.titleLarge),
                        const Gap(16),
                        Text('招待コード',
                            style: Theme.of(context).textTheme.bodySmall),
                        const Gap(4),
                        Text(p.inviteCode,
                            style: const TextStyle(
                                fontSize: 20, letterSpacing: 4)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.link_off),
                  label: const Text('パートナーシップを解除'),
                  onPressed: () => _confirmArchive(context, ref, p.id),
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
      BuildContext context, WidgetRef ref, String partnershipId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('パートナーシップを解除しますか？'),
        content: const Text('解除すると支払い履歴は閲覧できなくなります。'),
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
      await ref
          .read(partnershipRepositoryProvider)
          .archivePartnership(partnershipId);
      ref.invalidate(activePartnershipProvider);
      ref.invalidate(partnerProfileProvider);
      if (context.mounted) {
        context.go('/home');
      }
    }
  }
}
