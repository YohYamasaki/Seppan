import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../repositories/expense_repository.dart';

class EncryptionUnlockPage extends ConsumerStatefulWidget {
  const EncryptionUnlockPage({super.key});

  @override
  ConsumerState<EncryptionUnlockPage> createState() =>
      _EncryptionUnlockPageState();
}

class _EncryptionUnlockPageState extends ConsumerState<EncryptionUnlockPage> {
  final _passwordController = TextEditingController();
  bool _unlocking = false;
  bool _obscure = true;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _onUnlock() async {
    final password = _passwordController.text;
    if (password.isEmpty) return;

    setState(() => _unlocking = true);

    final user = ref.read(currentUserProvider);
    final partnership = await ref.read(currentPartnershipProvider.future);
    if (user == null || partnership == null) return;

    final result = await ref
        .read(encryptionKeyNotifierProvider.notifier)
        .unlockWithPassword(
          partnershipId: partnership.id,
          userId: user.id,
          password: password,
        );

    if (!mounted) return;

    switch (result) {
      case UnlockSuccess():
        // Resume interrupted re-encryption if a pending old key exists
        await _resumeReencryptionIfNeeded(partnership, user.id);
        if (!mounted) return;
        context.go('/home');
      case UnlockWrongPassword():
        setState(() => _unlocking = false);
        _showError('パスワードが正しくありません。もう一度お試しください。');
      case UnlockNoWrappedKey():
        setState(() => _unlocking = false);
        _showError(
          '暗号化鍵が見つかりません。パートナーシップの設定が完了していない可能性があります。',
        );
      case UnlockNetworkError():
        setState(() => _unlocking = false);
        _showError(
          'サーバーに接続できませんでした。ネットワーク接続を確認してお試しください。',
        );
      case UnlockUnexpectedError(:final detail):
        setState(() => _unlocking = false);
        _showError('ロック解除に失敗しました: $detail');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
      ),
    );
  }

  /// If a previous re-encryption was interrupted (app crash during key
  /// exchange), resume it now that we have the new key in memory.
  Future<void> _resumeReencryptionIfNeeded(
    dynamic partnership,
    String userId,
  ) async {
    final notifier = ref.read(encryptionKeyNotifierProvider.notifier);
    final oldKey = await notifier.getPendingOldKey(partnership.id);
    if (oldKey == null) return; // No interrupted re-encryption

    final newKey = ref.read(encryptionKeyNotifierProvider);
    if (newKey == null) return;

    await ExpenseRepository(encryptionKey: newKey).reencryptUserExpenses(
      partnershipId: partnership.id,
      userId: userId,
      oldKey: oldKey,
      newKey: newKey,
    );
    await notifier.clearPendingOldKey(partnership.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('データのロック解除'),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
            child: const Text('ログアウト'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const Gap(16),
            const Text(
              '暗号化パスワードを\n入力してください',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            Text(
              'データの暗号化を解除するためにパスワードが必要です。',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            ),
            const Gap(24),
            AutofillGroup(
              onDisposeAction: AutofillContextAction.cancel,
              child: TextField(
                controller: _passwordController,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _onUnlock(),
                decoration: InputDecoration(
                  labelText: 'パスワード',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _unlocking ? null : _onUnlock,
                child: _unlocking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('ロック解除', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
