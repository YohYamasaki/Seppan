import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../services/encryption_service.dart';

class EncryptionSettingsPage extends ConsumerStatefulWidget {
  const EncryptionSettingsPage({super.key});

  @override
  ConsumerState<EncryptionSettingsPage> createState() =>
      _EncryptionSettingsPageState();
}

class _EncryptionSettingsPageState
    extends ConsumerState<EncryptionSettingsPage> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _changing = false;
  bool _showCurrentPassword = false;
  bool _showNewPassword = false;
  bool _showConfirmPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (newPassword.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新しいパスワードは8文字以上で入力してください')),
      );
      return;
    }

    if (newPassword != confirmPassword) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('新しいパスワードが一致しません')),
      );
      return;
    }

    setState(() => _changing = true);

    try {
      final user = ref.read(currentUserProvider);
      final partnership =
          await ref.read(currentPartnershipProvider.future);
      if (user == null || partnership == null) return;

      // First, verify current password by trying to unwrap
      final repo = ref.read(encryptionKeyRepositoryProvider);
      final data = await repo.getWrappedKey(partnership.id, user.id);
      if (data == null) throw StateError('No encryption key found');

      final rawKey = await EncryptionService.unwrapKey(
        data['wrapped_key'] as String,
        data['key_salt'] as String,
        data['key_nonce'] as String,
        currentPassword,
      );

      // Re-wrap with new password
      final result = await EncryptionService.wrapKey(rawKey, newPassword);
      await repo.storeWrappedKey(
        partnershipId: partnership.id,
        userId: user.id,
        wrappedKey: result.wrappedKey,
        salt: result.salt,
        nonce: result.nonce,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パスワードを変更しました')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _changing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('現在のパスワードが正しくありません')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('パスワードの変更')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '支出データはAES-256-GCMで暗号化されています。サーバーは暗号文のみを保持し、平文データにアクセスできません。',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const Gap(24),
            TextField(
              controller: _currentPasswordController,
              obscureText: !_showCurrentPassword,
              decoration: InputDecoration(
                labelText: '現在のパスワード',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showCurrentPassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(
                      () => _showCurrentPassword = !_showCurrentPassword),
                ),
              ),
            ),
            const Gap(12),
            TextField(
              controller: _newPasswordController,
              obscureText: !_showNewPassword,
              decoration: InputDecoration(
                labelText: '新しいパスワード',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showNewPassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () =>
                      setState(() => _showNewPassword = !_showNewPassword),
                ),
              ),
            ),
            const Gap(12),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: '新しいパスワード（確認）',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirmPassword
                      ? Icons.visibility_off
                      : Icons.visibility),
                  onPressed: () => setState(
                      () => _showConfirmPassword = !_showConfirmPassword),
                ),
              ),
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _changing ? null : _changePassword,
                style: FilledButton.styleFrom(
                  backgroundColor: seppanBrandColor,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _changing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('パスワードを変更'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
