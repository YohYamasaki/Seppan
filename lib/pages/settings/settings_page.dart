import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';

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
            onTap: () => context.push('/settings/profile-edit'),
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
            icon: Icons.logout,
            title: 'ログアウト',
            onTap: () => _confirmLogout(context, ref),
          ),
          const SizedBox(height: 48),
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
              'この操作は取り消すことができません。\n\n'
              '本当に実行する場合は「削除」と入力してください。',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: '削除',
                border: OutlineInputBorder(),
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
        await ref.read(authRepositoryProvider).deleteAccount();
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
