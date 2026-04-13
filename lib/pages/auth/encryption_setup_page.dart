import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../models/partnership.dart';
import '../../providers/auth_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/partnership_provider.dart';

class EncryptionSetupPage extends ConsumerStatefulWidget {
  const EncryptionSetupPage({
    super.key,
    required this.partnership,
    required this.rawKey,
    this.nextRoute,
  });

  final Partnership partnership;
  final Uint8List rawKey;
  final String? nextRoute;

  @override
  ConsumerState<EncryptionSetupPage> createState() =>
      _EncryptionSetupPageState();
}

class _EncryptionSetupPageState extends ConsumerState<EncryptionSetupPage> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _saving = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (password.length < 8) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードは8文字以上で入力してください')));
      return;
    }

    if (password != confirm) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('パスワードが一致しません')));
      return;
    }

    setState(() => _saving = true);

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      await ref
          .read(encryptionKeyNotifierProvider.notifier)
          .setupEncryption(
            partnershipId: widget.partnership.id,
            userId: user.id,
            password: password,
            rawKey: widget.rawKey,
          );

      ref.invalidate(activePartnershipProvider);
      ref.invalidate(currentPartnershipProvider);

      if (mounted) {
        context.go(widget.nextRoute ?? '/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('エラーが発生しました: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('暗号化パスワード設定'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const Gap(16),
            const Text(
              'データを保護するパスワードを\n設定してください',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            Text(
              '支出データはAES-256-GCMで暗号化されます。このパスワードで暗号化鍵を保護し、別のデバイスからもデータにアクセスできるようにします。',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const Gap(24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red),
                  Gap(8),
                  Expanded(
                    child: Text(
                      'このパスワードを忘れると、データを復元できなくなります。サービス提供者を含め、誰もパスワードを復元することはできません。必ず安全な場所にメモしてください。',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(24),
            AutofillGroup(
              child: Column(
                children: [
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'パスワード',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                  ),
                  const Gap(16),
                  TextField(
                    controller: _confirmController,
                    obscureText: _obscureConfirm,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'パスワード（確認）',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Gap(8),
            Text(
              '8文字以上',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12),
            ),
            const Gap(32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _onSave,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('設定を完了', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
