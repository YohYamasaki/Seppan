import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../services/csv_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: ListView(
        children: [
          _SettingsTile(
            icon: Icons.face,
            title: '名前・アイコンの変更',
            onTap: () async {
              final updated =
                  await context.push<bool>('/settings/profile-edit');
              if (updated == true) {
                ref.invalidate(currentProfileProvider);
              }
            },
          ),
          _SettingsTile(
            icon: Icons.list,
            title: 'ジャンルの編集',
            onTap: () => context.push('/settings/category-edit'),
          ),
          _SettingsTile(
            icon: Icons.people,
            title: 'パートナーシップ管理',
            onTap: () => context.push('/settings/partnership'),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'パスワードの変更',
            onTap: () => context.push('/settings/encryption'),
          ),
          _SettingsTile(
            icon: Icons.file_download_outlined,
            title: '履歴をCSVエクスポート',
            onTap: () => _exportCsv(context, ref),
          ),
          _SettingsTile(
            icon: Icons.file_upload_outlined,
            title: 'CSVから履歴をインポート',
            onTap: () => _importCsv(context, ref),
          ),
          _SettingsTile(
            icon: Icons.logout,
            title: 'ログアウト',
            onTap: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: 48),
          _SettingsTile(
            icon: Icons.shield_outlined,
            title: 'プライバシーポリシー',
            onTap: () => context.push('/settings/privacy-policy'),
          ),
          _SettingsTile(
            icon: Icons.description_outlined,
            title: '利用規約',
            onTap: () => context.push('/settings/terms'),
          ),
          _SettingsTile(
            icon: Icons.info_outline,
            title: '概要・ライセンス情報',
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'Seppan',
                applicationVersion: '1.0.0',
                applicationLegalese: '2026 Yoh Yamasaki',
              );
            },
          ),
          const SizedBox(height: 48),
          _SettingsTile(
            icon: Icons.delete_forever,
            title: 'アカウント削除',
            textColor: Colors.red,
            onTap: () => _confirmDelete(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context, WidgetRef ref) async {
    final partnership = await ref.read(currentPartnershipProvider.future);
    if (partnership == null) return;

    final repo = ref.read(expenseRepositoryProvider);
    final user = ref.read(currentUserProvider);
    final partnerProfile = await ref.read(partnerProfileProvider.future);
    final myProfile = await ref.read(profileRepositoryProvider).getProfile(user!.id);

    final userNames = <String, String>{};
    if (myProfile != null) userNames[myProfile.id] = myProfile.displayName;
    if (partnerProfile != null) {
      userNames[partnerProfile.id] = partnerProfile.displayName;
    }

    try {
      final expenses = await repo.getAllExpenses(partnership.id);
      final saved = await CsvService.exportExpenses(
        expenses: expenses,
        userNames: userNames,
      );
      if (saved && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CSVを保存しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エクスポートに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return;

    final partnership = await ref.read(currentPartnershipProvider.future);
    if (partnership == null) return;

    final user = ref.read(currentUserProvider);
    final partnerProfile = await ref.read(partnerProfileProvider.future);
    final myProfile = await ref.read(profileRepositoryProvider).getProfile(user!.id);

    final nameToUserId = <String, String>{};
    if (myProfile != null) nameToUserId[myProfile.displayName] = myProfile.id;
    if (partnerProfile != null) {
      nameToUserId[partnerProfile.displayName] = partnerProfile.id;
    }

    try {
      final csvContent = await File(result.files.single.path!).readAsString();
      final parsed = CsvService.parseExpenses(
        csvContent: csvContent,
        nameToUserId: nameToUserId,
      );

      if (parsed.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('インポートするデータがありません')),
          );
        }
        return;
      }

      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('インポート確認'),
          content: Text('${parsed.length}件のデータをインポートしますか？\n既存の履歴はそのまま保持されます。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('キャンセル'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('インポート'),
            ),
          ],
        ),
      );
      if (confirm != true) return;

      final repo = ref.read(expenseRepositoryProvider);
      for (final data in parsed) {
        await repo.addExpense(Expense(
          id: '',
          partnershipId: partnership.id,
          paidBy: data['paidBy'] as String,
          amount: data['amount'] as int,
          currency: data['currency'] as String,
          ratio: data['ratio'] as double,
          date: data['date'] as DateTime,
          category: data['category'] as String,
          memo: data['memo'] as String,
          createdAt: DateTime.now(),
        ));
      }

      ref.read(expenseDataVersionProvider.notifier).state++;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${parsed.length}件をインポートしました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('インポートに失敗しました: $e')),
        );
      }
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ログアウトしますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ログアウト'),
          ),
        ],
      ),
    );
    if (result == true) {
      await ref.read(encryptionKeyNotifierProvider.notifier).clearAll();
      await ref.read(authRepositoryProvider).signOut();
    }
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウント削除'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'ユーザーデータ、入力された支払い履歴がすべて消去されます。\n'
              'パートナーとのリンクは自動的に解除され、リンク相手があなたの代わりに入力した履歴もすべて削除されます。\n'
              'この操作は取り消すことができません。\n\n'
              '本当に実行する場合は「削除」と入力してください。',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: '削除',
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () {
              if (controller.text == '削除') {
                Navigator.pop(context, true);
              }
            },
            child: const Text('削除'),
          ),
        ],
      ),
    );
    // Do NOT dispose controller here — the dialog's TextField may still
    // reference it during unmount (focus change → clearComposing).

    if (result == true && context.mounted) {
      try {
        // The server-side RPC (delete_user_data) handles everything:
        //   - deletes only this user's expenses (paid_by)
        //   - detaches user from partnerships (archives them)
        //   - deletes solo partnerships + categories
        //   - deletes profile
        // No client-side pre-processing needed.
        await ref.read(authRepositoryProvider).deleteAccount();
        await ref.read(encryptionKeyNotifierProvider.notifier).clearAll();
        if (context.mounted) context.go('/sign-in');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('アカウント削除に失敗しました: $e')),
          );
        }
      }
    }
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.textColor,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(width: 1, color: CupertinoColors.systemGrey5),
        ),
      ),
      child: ListTile(
        leading: Icon(icon, color: textColor),
        title: Text(title, style: TextStyle(color: textColor)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}
