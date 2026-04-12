import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../widgets/expense_tile.dart';

class CategoryDetailPage extends ConsumerStatefulWidget {
  const CategoryDetailPage({
    super.key,
    required this.category,
    required this.year,
    required this.month,
  });

  final String category;
  final int year;
  final int month;

  @override
  ConsumerState<CategoryDetailPage> createState() =>
      _CategoryDetailPageState();
}

class _CategoryDetailPageState extends ConsumerState<CategoryDetailPage> {
  List<Expense>? _expenses;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final partnership = await ref.read(currentPartnershipProvider.future);
    if (partnership == null) return;

    setState(() => _loading = true);
    try {
      final expenses = await ref
          .read(expenseRepositoryProvider)
          .getExpensesByMonth(
            partnership.id,
            month: DateTime(widget.year, widget.month),
            category: widget.category,
          );
      if (mounted) {
        setState(() {
          _expenses = expenses;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final partnerProfile = ref.watch(partnerProfileProvider).valueOrNull;
    final partnerName = partnerProfile?.displayName ?? 'パートナー';
    final partnerIconId = partnerProfile?.iconId ?? 1;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category),
      ),
      body: Column(
        children: [
          // Month subtitle
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${widget.year}年${widget.month}月',
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          // Expense list
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _expenses == null || _expenses!.isEmpty
                    ? const Center(child: Text('データがありません'))
                    : ListView.separated(
                        itemCount: _expenses!.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final expense = _expenses![index];
                          final isMe = expense.paidBy == user?.id;
                          return ExpenseTile(
                            expense: expense,
                            payerName: isMe
                                ? (profile?.displayName ?? '')
                                : partnerName,
                            payerIconId: isMe
                                ? (profile?.iconId ?? 1)
                                : partnerIconId,
                            onTap: () =>
                                context.push('/history/${expense.id}'),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
