import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';

class QrScannerPage extends ConsumerStatefulWidget {
  const QrScannerPage({super.key});

  @override
  ConsumerState<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends ConsumerState<QrScannerPage> {
  bool _processing = false;

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final code = capture.barcodes.firstOrNull?.rawValue;
    if (code == null || code.length != 6) return;

    setState(() => _processing = true);

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    // Look up pending partnership before joining (it won't be pending after)
    final pending = await ref
        .read(partnershipRepositoryProvider)
        .getPendingPartnership(user.id);

    final result = await ref
        .read(partnershipRepositoryProvider)
        .joinPartnership(code.toUpperCase(), user.id);

    if (!mounted) return;

    if (result != null) {
      // Migrate expenses from old pending partnership to the new active one
      if (pending != null && pending.id != result.id) {
        await ref.read(expenseRepositoryProvider).migrateExpenses(
              pending.id,
              result.id,
            );
        await ref
            .read(partnershipRepositoryProvider)
            .archivePartnership(pending.id);
      }
      ref.invalidate(activePartnershipProvider);
      ref.invalidate(currentPartnershipProvider);
      ref.invalidate(recentExpensesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('リンクが完了しました！')),
      );
      context.go('/home');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('該当するコードが見つかりません')),
      );
      setState(() => _processing = false);
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
