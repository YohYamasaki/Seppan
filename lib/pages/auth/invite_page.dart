import 'dart:async';
import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../models/partnership.dart';
import '../../providers/auth_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../services/encryption_service.dart';

class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key, this.showScaffold = true});

  final bool showScaffold;

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  Partnership? _partnership;
  bool _loading = true;
  bool _expired = false;
  SimpleKeyPair? _ecdhKeyPair;
  String _qrData = '';
  Timer? _expiryTimer;
  StreamSubscription<Partnership>? _watchSub;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _initPartnership();
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _watchSub?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _initPartnership() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final repo = ref.read(partnershipRepositoryProvider);
    final notifier = ref.read(encryptionKeyNotifierProvider.notifier);

    try {
      // Get old pending partnership before archiving (for key migration)
      final oldPending = await repo.getPendingPartnership(user.id);

      // Archive any stale pending partnerships before creating new
      await repo.archiveOldPendingPartnerships(user.id);
      final created = await repo.createPartnership(user.id);

      // Ensure encryption key is available
      var key = ref.read(encryptionKeyNotifierProvider);

      if (key == null) {
        // Try restoring from secure storage (app restart case)
        if (oldPending != null) {
          await notifier.tryRestoreFromCache(oldPending.id);
        }
        if (ref.read(encryptionKeyNotifierProvider) == null) {
          await notifier.tryRestoreFromCache(created.id);
        }
        key = ref.read(encryptionKeyNotifierProvider);
      }

      if (key == null) {
        final rawKey = await EncryptionService.generatePartnershipKey();
        if (mounted) {
          context.go('/encryption-setup', extra: {
            'partnership': created,
            'rawKey': rawKey,
            'nextRoute': '/invite',
          });
        }
        return;
      }

      // Migrate encryption key and expenses to new partnership if needed
      if (oldPending != null) {
        await notifier.migrateToPartnership(
          oldPartnershipId: oldPending.id,
          newPartnershipId: created.id,
          userId: user.id,
        );
        await ref.read(expenseRepositoryProvider).migrateUserExpenses(
              oldPending.id,
              created.id,
              user.id,
            );
      } else {
        // No old partnership to migrate from — ensure key is cached
        // under the new partnership ID so it survives app restart.
        await notifier.ensureCached(created.id);
      }

      // Generate ECDH key pair
      final keyPair = await EncryptionService.generateEcdhKeyPair();
      final pubKey = await keyPair.extractPublicKey();
      final pubKeyB64 = base64Url.encode(pubKey.bytes);

      // Save public key to server
      await repo.updateEcdhPub(created.id, 'user1_ecdh_pub', pubKeyB64);

      // Build QR data
      final qrJson = jsonEncode({
        'pid': created.id,
        'pk': pubKeyB64,
      });

      // Sync currentPartnershipProvider with the newly created partnership.
      // Without this, the provider holds a stale (archived) partnership ID,
      // and expenses would be saved against the wrong partnership.
      ref.invalidate(currentPartnershipProvider);

      setState(() {
        _partnership = created;
        _ecdhKeyPair = keyPair;
        _qrData = qrJson;
        _loading = false;
      });

      // Start 30-minute expiry timer
      _startExpiryTimer();

      // Watch for partner joining (user2_ecdh_pub being set)
      _watchForPartner(created.id);
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  void _startExpiryTimer() {
    _expiryTimer = Timer(const Duration(minutes: 30), () {
      if (mounted) {
        _watchSub?.cancel();
        _pollTimer?.cancel();
        setState(() => _expired = true);
      }
    });
  }

  Future<void> _refreshQr() async {
    if (_partnership != null) {
      await ref
          .read(partnershipRepositoryProvider)
          .archivePartnership(_partnership!.id);
    }
    _expiryTimer?.cancel();
    _watchSub?.cancel();
    _pollTimer?.cancel();
    setState(() {
      _loading = true;
      _expired = false;
    });
    _initPartnership();
  }

  void _watchForPartner(String partnershipId) {
    // Realtime stream
    _watchSub = ref
        .read(partnershipRepositoryProvider)
        .watchPartnership(partnershipId)
        .listen(
      (partnership) => _handlePartnerJoined(partnership),
      onError: (_) {
        // Realtime failed — polling fallback will handle detection
      },
    );

    // Polling fallback: Realtime may silently drop events
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      try {
        final partnership = await ref
            .read(partnershipRepositoryProvider)
            .getPartnership(partnershipId);
        if (partnership != null) {
          _handlePartnerJoined(partnership);
        }
      } catch (_) {
        // Ignore polling errors — next tick will retry
      }
    });
  }

  Future<void> _handlePartnerJoined(Partnership partnership) async {
    if (partnership.user2EcdhPub == null ||
        _ecdhKeyPair == null ||
        !mounted) {
      return;
    }

    // Prevent duplicate navigation
    _watchSub?.cancel();
    _watchSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _expiryTimer?.cancel();

    final peerPubKeyBytes = base64Url.decode(partnership.user2EcdhPub!);
    final peerPubKey =
        SimplePublicKey(peerPubKeyBytes, type: KeyPairType.x25519);

    final myPubKey = await _ecdhKeyPair!.extractPublicKey();

    if (!mounted) return;
    context.go('/fingerprint-verification', extra: {
      'partnership': partnership,
      'myKeyPair': _ecdhKeyPair,
      'myPubKey': myPubKey,
      'peerPubKey': peerPubKey,
      'isInitiator': true,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      if (!widget.showScaffold) {
        return const Center(child: CircularProgressIndicator());
      }
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          if (_expired) ...[
            Icon(Icons.timer_off, size: 48, color: Theme.of(context).colorScheme.onSurfaceVariant),
            const Gap(16),
            const Text(
              'QRコードの有効期限が切れました',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Gap(24),
            FilledButton.icon(
              onPressed: _refreshQr,
              icon: const Icon(Icons.refresh),
              label: const Text('QRコードを更新'),
            ),
          ] else ...[
            const Text(
              'パートナーに下のQRコードを\nスキャンしてもらってください',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
            const Gap(8),
            Text(
              'Seppanアプリ内のQRリーダー（下の「パートナーのQRコードをスキャン」）から読み取る必要があります。カメラアプリでは読み取れません。',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant
                    .withValues(alpha: 0.7),
                fontSize: 13,
              ),
            ),
            const Gap(24),
            QrImageView(
              data: _qrData,
              size: 240,
              backgroundColor: Colors.white,
            ),
            const Gap(24),
            Text(
              'QRコードにはあなたの公開鍵のみが含まれています。\n秘密情報は含まれていません。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 12),
            ),
          ],
          const Gap(32),
          const Divider(),
          const Gap(24),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('パートナーのQRコードをスキャン'),
            onPressed: () => context.push('/invite/qr-scan'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
          ),
          if (widget.showScaffold) ...[
            const Gap(16),
            TextButton(
              onPressed: () => context.go('/home'),
              child: const Text('リンクせず進める'),
            ),
          ],
        ],
      ),
    );

    if (!widget.showScaffold) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('パートナーとリンク'),
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      body: body,
    );
  }
}
