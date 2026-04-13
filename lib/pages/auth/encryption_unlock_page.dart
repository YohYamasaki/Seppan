import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/partnership_provider.dart';

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

    final success =
        await ref.read(encryptionKeyNotifierProvider.notifier).unlockWithPassword(
              partnershipId: partnership.id,
              userId: user.id,
              password: password,
            );

    if (!mounted) return;

    if (success) {
      context.go('/home');
    } else {
      setState(() => _unlocking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('パスワードが正しくありません')),
      );
    }
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
            const Icon(Icons.lock, size: 48, color: Colors.grey),
            const Gap(16),
            const Text(
              '暗号化パスワードを\n入力してください',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Gap(8),
            const Text(
              'このデバイスからデータにアクセスするにはパスワードが必要です。',
              style: TextStyle(color: Colors.grey),
            ),
            const Gap(24),
            TextField(
              controller: _passwordController,
              obscureText: _obscure,
              onSubmitted: (_) => _onUnlock(),
              decoration: InputDecoration(
                labelText: 'パスワード',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const Gap(24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _unlocking ? null : _onUnlock,
                style: FilledButton.styleFrom(
                  backgroundColor: seppanBrandColor,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _unlocking
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
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
