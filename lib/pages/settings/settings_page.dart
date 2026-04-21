import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
              final updated = await context.push<bool>(
                '/settings/profile-edit',
              );
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
            onTap: () async {
              final info = await PackageInfo.fromPlatform();
              if (!context.mounted) return;
              showAboutDialog(
                context: context,
                applicationName: 'Seppan',
                applicationVersion: info.version,
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
    // Warn user that exported CSV is plaintext (unencrypted).
    final proceed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('CSVエクスポートの注意'),
        content: const Text(
          'エクスポートされるCSVファイルは暗号化されていない平文です。\n\n'
          '金額、カテゴリ、メモ、パートナーの名前などが含まれますので、'
          '保存場所および共有先にはご注意ください。\n\n'
          '続行しますか？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('続行'),
          ),
        ],
      ),
    );
    if (proceed != true || !context.mounted) return;

    final partnership = await ref.read(currentPartnershipProvider.future);
    if (partnership == null) return;

    final repo = ref.read(expenseRepositoryProvider);
    final user = ref.read(currentUserProvider);
    final partnerProfile = await ref.read(partnerProfileProvider.future);
    final myProfile = await ref
        .read(profileRepositoryProvider)
        .getProfile(user!.id);

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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('CSVを保存しました')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エクスポートに失敗しました: $e')));
      }
    }
  }

  Future<void> _importCsv(BuildContext context, WidgetRef ref) async {
    // Resolve my/partner names for the sample CSV and for parsing.
    final user = ref.read(currentUserProvider);
    final partnerProfile = await ref.read(partnerProfileProvider.future);
    final myProfile = await ref
        .read(profileRepositoryProvider)
        .getProfile(user!.id);
    if (!context.mounted) return;

    final myName = myProfile?.displayName ?? '自分';
    final partnerName = partnerProfile?.displayName ?? 'パートナー';

    // Show info modal before opening file picker.
    final proceed = await _showImportInfoDialog(
      context,
      myName: myName,
      partnerName: partnerName,
    );
    if (proceed != true || !context.mounted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.single.path == null) return;

    final partnership = await ref.read(currentPartnershipProvider.future);
    if (partnership == null) return;

    final nameToUserId = <String, String>{};
    if (myProfile != null) nameToUserId[myProfile.displayName] = myProfile.id;
    if (partnerProfile != null) {
      nameToUserId[partnerProfile.displayName] = partnerProfile.id;
    }

    try {
      final csvContent =
          await File(result.files.single.path!).readAsString(encoding: utf8);
      final parseResult = CsvService.parseExpenses(
        csvContent: csvContent,
        nameToUserId: nameToUserId,
      );

      if (parseResult.parsed.isEmpty && parseResult.skipped == 0) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('インポートするデータがありません')),
          );
        }
        return;
      }

      // Check for potential duplicates against existing data
      final repo = ref.read(expenseRepositoryProvider);
      final existingExpenses = await repo.getAllExpenses(partnership.id);
      final existingKeys = <String>{};
      for (final e in existingExpenses) {
        existingKeys.add('${e.date.toIso8601String()}|${e.paidBy}|${e.amount}');
      }
      var duplicateCount = 0;
      for (final data in parseResult.parsed) {
        final key =
            '${(data['date'] as DateTime).toIso8601String()}|${data['paidBy']}|${data['amount']}';
        if (existingKeys.contains(key)) duplicateCount++;
      }

      if (!context.mounted) return;
      final confirm = await _showImportConfirmDialog(
        context: context,
        parseResult: parseResult,
        duplicateCount: duplicateCount,
      );
      if (confirm != true) return;

      // Track per-row import results.
      var successCount = 0;
      final failures = <String, int>{}; // reason → count
      for (final data in parseResult.parsed) {
        try {
          await repo.addExpense(
            Expense(
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
            ),
          );
          successCount++;
        } catch (e) {
          failures.update(
            e.toString(),
            (count) => count + 1,
            ifAbsent: () => 1,
          );
        }
      }

      ref.read(expenseDataVersionProvider.notifier).state++;

      if (context.mounted) {
        await _showImportResultDialog(
          context: context,
          successCount: successCount,
          skippedInParse: parseResult.skipReasons,
          saveFailures: failures,
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

  /// Confirmation dialog shown before importing — displays how many rows
  /// will be imported and how many were skipped during parsing.
  Future<bool?> _showImportConfirmDialog({
    required BuildContext context,
    required CsvParseResult parseResult,
    required int duplicateCount,
  }) {
    final skipped = parseResult.skipped;
    final parsed = parseResult.parsed.length;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('インポート確認'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$parsed 件のデータをインポートします。'),
              const SizedBox(height: 8),
              const Text('既存の履歴はそのまま保持されます。'),
              if (duplicateCount > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '⚠ $parsed 件中 $duplicateCount 件が既存データと'
                  '重複している可能性があります。',
                  style: const TextStyle(color: Colors.orange),
                ),
              ],
              if (skipped > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '$skipped 件は形式不正のためスキップされます:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...parseResult.skipReasons.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text('・${e.key}（${e.value.length} 件）'),
                    )),
              ],
            ],
          ),
        ),
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
  }

  /// Result dialog shown after the import completes — shows success
  /// count and any per-row failures (parse-skipped + save-failed).
  Future<void> _showImportResultDialog({
    required BuildContext context,
    required int successCount,
    required Map<String, List<int>> skippedInParse,
    required Map<String, int> saveFailures,
  }) {
    final totalSkipped = skippedInParse.values
        .fold<int>(0, (sum, list) => sum + list.length);
    final totalFailed =
        saveFailures.values.fold<int>(0, (sum, count) => sum + count);
    final totalErrors = totalSkipped + totalFailed;

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('インポート結果'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✓ $successCount 件のインポートに成功しました',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (totalErrors > 0) ...[
                const SizedBox(height: 12),
                Text(
                  '✗ $totalErrors 件は取り込めませんでした',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '内訳:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...skippedInParse.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text('・${e.key}（${e.value.length} 件）'),
                    )),
                ...saveFailures.entries.map((e) => Padding(
                      padding: const EdgeInsets.only(left: 8, top: 2),
                      child: Text('・保存失敗: ${e.key}（${e.value} 件）'),
                    )),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }

  /// Info dialog shown before the file picker. Explains the required CSV
  /// format, offers a sample download, and requires the user to confirm
  /// that their names match exactly.
  Future<bool?> _showImportInfoDialog(
    BuildContext context, {
    required String myName,
    required String partnerName,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: const Text('CSVインポートについて'),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CSVファイルは以下のフォーマットで作成されている必要があります。'
                'フォーマットが異なる場合、インポートできません。',
              ),
              const SizedBox(height: 8),
              // Format summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '列: 日付, 支払者, 金額, 通貨, 負担率, カテゴリ, メモ',
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Sample download button
              OutlinedButton.icon(
                icon: const Icon(Icons.download_outlined, size: 18),
                label: const Text('サンプルCSVをダウンロード'),
                onPressed: () => _downloadSampleCsv(
                  context,
                  myName: myName,
                  partnerName: partnerName,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
              const SizedBox(height: 16),
              // Name matching warning
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CSV内の「支払者」は、現在のプロフィール名と完全に一致'
                        'している必要があります（「$myName」または「$partnerName」）。'
                        '一致しない行はスキップされます。',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
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
              onPressed: () => Navigator.pop(context, true),
              child: const Text('インポート'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadSampleCsv(
    BuildContext context, {
    required String myName,
    required String partnerName,
  }) async {
    // Use current profile names so the sample is ready-to-import as-is.
    final csv = '日付,支払者,金額,通貨,負担率,カテゴリ,メモ\n'
        '2026-04-01,$myName,1200,JPY,0.5,食費,ランチ\n'
        '2026-04-03,$partnerName,3500,JPY,0.5,日用品,洗剤\n'
        '2026-04-05,$myName,800,JPY,0.75,交通費,バス往復\n';

    try {
      final saved = await FilePicker.platform.saveFile(
        dialogTitle: 'サンプルCSVを保存',
        fileName: 'seppan_sample.csv',
        type: FileType.custom,
        allowedExtensions: ['csv'],
        bytes: utf8.encode(csv),
      );
      if (saved != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('サンプルCSVを保存しました')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存に失敗しました: $e')),
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
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canConfirm = controller.text == '削除';
            return AlertDialog(
              title: const Text('アカウント削除'),
              scrollable: true,
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ユーザーデータ、入力された支払い履歴がすべて消去されます。\n'
                    'パートナーとのリンクは自動的に解除され、プライバシー保護のため'
                    'リンク相手が入力した履歴もすべて削除されます。\n'
                    'この操作は取り消すことができません。',
                  ),
                  const SizedBox(height: 12),
                  // Backup recommendation
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer
                          .withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            '履歴データを残したい場合は、事前にCSVエクスポートして'
                            'バックアップしておくことをおすすめします。',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('本当に実行する場合は「削除」と入力してください。'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setDialogState(() {}),
                    decoration: InputDecoration(
                      hintText: '削除',
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: colorScheme.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: colorScheme.primary,
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
                  style: TextButton.styleFrom(
                    foregroundColor:
                        canConfirm ? Colors.red : colorScheme.outline,
                  ),
                  onPressed: canConfirm
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: const Text('削除'),
                ),
              ],
            );
          },
        );
      },
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
        // clearAll() must run BEFORE deleteAccount() because
        // deleteAccount() calls signOut() internally, which triggers
        // router navigation and disposes this widget — making ref invalid.
        await ref.read(encryptionKeyNotifierProvider.notifier).clearAll();
        await ref.read(authRepositoryProvider).deleteAccount();
        if (context.mounted) context.go('/sign-in');
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('アカウント削除に失敗しました: $e')));
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
