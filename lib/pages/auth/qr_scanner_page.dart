import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../providers/auth_provider.dart';
import '../../providers/encryption_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../services/encryption_service.dart';

class QrScannerPage extends ConsumerStatefulWidget {
  const QrScannerPage({super.key});

  @override
  ConsumerState<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    // Parse JSON QR format: {"pid":"...","pk":"..."}
    final Map<String, dynamic> qrData;
    try {
      qrData = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return; // Not a valid JSON QR
    }

    final partnershipId = qrData['pid'] as String?;
    final peerPubKeyB64 = qrData['pk'] as String?;
    if (partnershipId == null || peerPubKeyB64 == null) return;

    setState(() => _processing = true);

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    try {
      // Self-join guard: prevent pairing with your own partnership
      final partnershipRepo = ref.read(partnershipRepositoryProvider);
      final targetPartnership =
          await partnershipRepo.getPartnership(partnershipId);
      if (targetPartnership != null && targetPartnership.user1Id == user.id) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('自分自身のQRコードはスキャンできません')),
          );
          setState(() => _processing = false);
        }
        return;
      }

      // Remember joiner's old pending partnership for post-join migration
      final oldPending = await partnershipRepo.getPendingPartnership(user.id);

      // Generate ECDH key pair
      final myKeyPair = await EncryptionService.generateEcdhKeyPair();
      final myPubKey = await myKeyPair.extractPublicKey();
      final myPubKeyB64 = base64Url.encode(myPubKey.bytes);

      // Join partnership with our ECDH public key
      final result = await ref
          .read(partnershipRepositoryProvider)
          .joinPartnership(partnershipId, user.id, myPubKeyB64);

      if (!mounted) return;

      if (result != null) {
        // Migrate expenses & key after joining (RLS requires membership)
        if (oldPending != null) {
          await ref.read(expenseRepositoryProvider).migrateUserExpenses(
                oldPending.id,
                partnershipId,
                user.id,
              );
          await ref
              .read(encryptionKeyNotifierProvider.notifier)
              .migrateToPartnership(
                oldPartnershipId: oldPending.id,
                newPartnershipId: partnershipId,
                userId: user.id,
              );
          await partnershipRepo.archivePartnership(oldPending.id);
        }
        // Parse peer's public key
        final peerPubKeyBytes = base64Url.decode(peerPubKeyB64);
        final peerPubKey = SimplePublicKey(
          peerPubKeyBytes,
          type: KeyPairType.x25519,
        );

        // Navigate to fingerprint verification
        context.go('/fingerprint-verification', extra: {
          'partnership': result,
          'myKeyPair': myKeyPair,
          'myPubKey': myPubKey,
          'peerPubKey': peerPubKey,
          'isInitiator': false,
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('リンクに失敗しました。QRコードが無効か期限切れです。')),
        );
        setState(() => _processing = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
        setState(() => _processing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QRコードをスキャン')),
      body: MobileScanner(onDetect: _onDetect),
    );
  }
}
