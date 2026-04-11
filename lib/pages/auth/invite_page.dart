import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/partnership.dart';
import '../../providers/auth_provider.dart';
import '../../providers/partnership_provider.dart';

class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  Partnership? _partnership;
  bool _loading = true;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initPartnership();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initPartnership() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final repo = ref.read(partnershipRepositoryProvider);

    try {
      // Check for existing pending partnership
      final existing = await _findPendingPartnership(user.id);
      if (existing != null) {
        setState(() {
          _partnership = existing;
          _loading = false;
        });
      } else {
        // Archive any stale pending partnerships before creating new
        await repo.archiveOldPendingPartnerships(user.id);
        final created = await repo.createPartnership(user.id);
        setState(() {
          _partnership = created;
          _loading = false;
        });
      }

      // Watch for partner joining
      if (_partnership != null) {
        _watchPartnership(_partnership!.id);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  Future<Partnership?> _findPendingPartnership(String userId) async {
    final repo = ref.read(partnershipRepositoryProvider);
    return repo.getPendingPartnership(userId);
  }

  void _watchPartnership(String partnershipId) {
    ref
        .read(partnershipRepositoryProvider)
        .watchPartnership(partnershipId)
        .listen((partnership) {
      if (partnership.status == 'active' && mounted) {
        ref.invalidate(activePartnershipProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('パートナーとリンクしました！')),
        );
      }
    });
  }

  Future<void> _joinWithCode() async {
    final code = _codeController.text.trim().toUpperCase();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('6桁のコードを入力してください')),
      );
      return;
    }

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final result = await ref
        .read(partnershipRepositoryProvider)
        .joinPartnership(code, user.id);

    if (result != null && mounted) {
      ref.invalidate(activePartnershipProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクが完了しました！')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('該当するコードが見つかりません')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final inviteCode = _partnership?.inviteCode ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('パートナーとリンク'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
            },
            child: const Text('ログアウト'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Text('あなたの招待コード',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const Gap(16),
            QrImageView(
              data: inviteCode,
              size: 200,
              backgroundColor: Colors.white,
            ),
            const Gap(16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  inviteCode,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: inviteCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('コピーしました')),
                    );
                  },
                ),
              ],
            ),
            const Gap(8),
            const Text(
              'パートナーにこのコードを共有してください',
              style: TextStyle(color: Colors.grey),
            ),
            const Gap(32),
            const Divider(),
            const Gap(24),
            const Text('パートナーのコードを入力',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const Gap(16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      hintText: '6桁のコード',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const Gap(12),
                ElevatedButton(
                  onPressed: _joinWithCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(80, 48),
                  ),
                  child: const Text('リンク'),
                ),
              ],
            ),
            const Gap(16),
            OutlinedButton.icon(
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('QRコードをスキャン'),
              onPressed: () => context.push('/invite/qr-scan'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
