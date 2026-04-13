import 'dart:async';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../models/partnership.dart';
import '../../providers/auth_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../repositories/expense_repository.dart';
import '../../services/encryption_service.dart';

class FingerprintVerificationPage extends ConsumerStatefulWidget {
  const FingerprintVerificationPage({
    super.key,
    required this.partnership,
    required this.myKeyPair,
    required this.myPubKey,
    required this.peerPubKey,
    required this.isInitiator,
  });

  final Partnership partnership;
  final SimpleKeyPair myKeyPair;
  final SimplePublicKey myPubKey;
  final SimplePublicKey peerPubKey;
  final bool isInitiator;

  @override
  ConsumerState<FingerprintVerificationPage> createState() =>
      _FingerprintVerificationPageState();
}

class _FingerprintVerificationPageState
    extends ConsumerState<FingerprintVerificationPage> {
  String _fingerprint = '';
  bool _loading = true;
  bool _confirming = false;
  StreamSubscription<Partnership>? _watchSub;
  Timer? _timeout;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _computeFingerprint();
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    _timeout?.cancel();
    super.dispose();
  }

  Future<void> _computeFingerprint() async {
    final SimplePublicKey pubKeyA;
    final SimplePublicKey pubKeyB;
    if (widget.isInitiator) {
      pubKeyA = widget.myPubKey;
      pubKeyB = widget.peerPubKey;
    } else {
      pubKeyA = widget.peerPubKey;
      pubKeyB = widget.myPubKey;
    }

    final fp = await EncryptionService.generateFingerprint(pubKeyA, pubKeyB);
    setState(() {
      _fingerprint = fp;
      _loading = false;
    });
  }

  // ── A (initiator) confirm ──────────────────────────────────────
  //
  // 1. Re-fetch partnership → verify B is still present
  // 2. Wrap key with ECDH shared secret → store (status stays 'pending')
  // 3. Watch partnership for:
  //    - status='active'    → link complete → /home
  //    - user2EcdhPub=null  → B cancelled   → error → /home
  // 4. Timeout 2 min → error → /home
  Future<void> _onConfirmInitiator() async {
    final repo = ref.read(partnershipRepositoryProvider);
    try {
      // Verify joiner is still present
      final latest = await repo.getPartnership(widget.partnership.id);
      if (latest == null || latest.user2EcdhPub == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('相手がリンクをキャンセルしました')),
          );
          context.go('/home');
        }
        return;
      }

      final rawKey = ref.read(encryptionKeyNotifierProvider);
      if (rawKey == null) throw StateError('Encryption key not available');

      final sharedSecret = await EncryptionService.deriveSharedSecret(
        widget.myKeyPair,
        widget.peerPubKey,
      );
      final wrappedKey = await EncryptionService.wrapKeyWithSharedSecret(
        rawKey,
        sharedSecret,
      );

      // Store wrapped key — status stays 'pending'.
      // B will set status='active' after receiving the key.
      await repo.storeWrappedPartnershipKey(
          widget.partnership.id, wrappedKey);

      if (!mounted) return;

      // Watch for B's activation or cancellation
      _watchSub = repo
          .watchPartnership(widget.partnership.id)
          .listen(
        (p) => _handleInitiatorUpdate(p),
        onError: (_) {},
      );

      // Polling fallback
      _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        try {
          final p = await repo.getPartnership(widget.partnership.id);
          if (p != null) _handleInitiatorUpdate(p);
        } catch (_) {}
      });

      _timeout = Timer(const Duration(minutes: 2), () {
        if (mounted) {
          _cleanup();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('相手の確認がタイムアウトしました')),
          );
          context.go('/home');
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクに失敗しました')),
        );
        context.go('/home');
      }
    }
  }

  void _handleInitiatorUpdate(Partnership p) {
    if (!mounted) return;
    if (p.status == 'active') {
      _cleanup();
      ref.invalidate(activePartnershipProvider);
      ref.invalidate(currentPartnershipProvider);
      context.go('/home');
    } else if (p.user2EcdhPub == null) {
      _cleanup();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('相手がリンクをキャンセルしました')),
      );
      context.go('/home');
    }
  }

  // ── B (joiner) confirm ─────────────────────────────────────────
  //
  // 1. Watch for wrapped_partnership_key to appear
  // 2. Unwrap key with ECDH shared secret
  // 3. Cache key locally + set in memory
  // 4. Set status='active'
  // 5. Go to /home
  // 6. Timeout 2 min → error → /home
  void _onConfirmJoiner() {
    final repo = ref.read(partnershipRepositoryProvider);

    _watchSub = repo
        .watchPartnership(widget.partnership.id)
        .listen(
      (partnership) => _handleJoinerUpdate(partnership),
      onError: (_) {},
    );

    // Polling fallback
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final p = await repo.getPartnership(widget.partnership.id);
        if (p != null) _handleJoinerUpdate(p);
      } catch (_) {}
    });

    _timeout = Timer(const Duration(minutes: 2), () {
      if (mounted) {
        _cleanup();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('相手の確認がタイムアウトしました')),
        );
        context.go('/home');
      }
    });
  }

  Future<void> _handleJoinerUpdate(Partnership partnership) async {
    if (partnership.wrappedPartnershipKey == null || !mounted) return;

    // A cancelled: empty string signals cancellation
    if (partnership.wrappedPartnershipKey!.isEmpty) {
      _cleanup();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('相手がリンクをキャンセルしました')),
      );
      context.go('/home');
      return;
    }

    _cleanup();

    try {
      final sharedSecret = await EncryptionService.deriveSharedSecret(
        widget.myKeyPair,
        widget.peerPubKey,
      );

      final rawKey = await EncryptionService.unwrapKeyWithSharedSecret(
        partnership.wrappedPartnershipKey!,
        sharedSecret,
      );

      if (!mounted) return;

      // Keep old key for re-encryption before switching to initiator's key
      final oldKey = ref.read(encryptionKeyNotifierProvider);
      final user = ref.read(currentUserProvider);
      final userId = user?.id ?? '';

      // Save initiator's key to memory + secure storage cache
      await ref
          .read(encryptionKeyNotifierProvider.notifier)
          .saveReceivedKey(
            partnershipId: partnership.id,
            userId: userId,
            rawKey: rawKey,
          );

      // Re-encrypt joiner's existing expenses from old key to new key
      if (oldKey != null) {
        await ExpenseRepository(encryptionKey: rawKey)
            .reencryptUserExpenses(
          partnershipId: partnership.id,
          userId: userId,
          oldKey: oldKey,
          newKey: rawKey,
        );
      }

      // B activates the partnership — this is the final handshake
      await ref
          .read(partnershipRepositoryProvider)
          .activatePartnership(partnership.id);

      if (!mounted) return;

      // キャッシュ済みの導出鍵で再ラップしてサーバーに保存
      // （パスワード再入力不要）
      await ref
          .read(encryptionKeyNotifierProvider.notifier)
          .rewrapForPartnership(
            partnershipId: partnership.id,
            userId: userId,
          );

      if (!mounted) return;

      ref.invalidate(activePartnershipProvider);
      ref.invalidate(currentPartnershipProvider);
      context.go('/home');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクに失敗しました')),
        );
        context.go('/home');
      }
    }
  }

  Future<void> _onConfirm() async {
    if (_confirming) return;
    setState(() => _confirming = true);

    if (widget.isInitiator) {
      await _onConfirmInitiator();
    } else {
      _onConfirmJoiner();
    }
  }

  Future<void> _onCancel() async {
    _cleanup();

    final repo = ref.read(partnershipRepositoryProvider);
    try {
      if (widget.isInitiator) {
        // Clear wrapped key so B can't receive it after we leave
        await repo.storeWrappedPartnershipKey(widget.partnership.id, '');
      } else {
        // Undo the join so A's watch detects user2EcdhPub=null
        await repo.unjoinPartnership(widget.partnership.id);
      }
    } catch (_) {
      // Best-effort — navigate home regardless
    }
    if (!context.mounted) return;
    context.go('/home');
  }

  Widget _buildFingerprintGrid() {
    final groups = _fingerprint.split(' ');
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < 2; r++)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var c = 0; c < 2; c++) ...[
                if (c > 0) const SizedBox(width: 20),
                Text(
                  groups[r * 2 + c],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }

  void _cleanup() {
    _watchSub?.cancel();
    _watchSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _timeout?.cancel();
    _timeout = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('セキュリティ確認'),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.fingerprint, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const Gap(24),
                  const Text(
                    'セキュリティコード',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Gap(8),
                  Text(
                    '相手の画面に表示されている番号と\n一致することを確認してください',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                  ),
                  const Gap(32),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _buildFingerprintGrid(),
                  ),
                  const Gap(16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.amber),
                        Gap(8),
                        Expanded(
                          child: Text(
                            '番号が一致しない場合は、第三者による攻撃の可能性があります。リンクを中止してください。',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (_confirming)
                    Column(
                      children: [
                        const CircularProgressIndicator(),
                        const Gap(12),
                        Text(
                          '相手の確認を待っています...',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _onConfirm,
                        child: const Text(
                          '一致を確認しました',
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),
                  const Gap(16),
                  TextButton(
                    onPressed: _confirming ? null : _onCancel,
                    child: const Text('キャンセル'),
                  ),
                ],
              ),
            ),
    );
  }
}
