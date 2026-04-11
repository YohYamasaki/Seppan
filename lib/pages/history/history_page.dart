import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../widgets/expense_tile.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _scrollController = ScrollController();
  final List<Expense> _expenses = [];
  bool _loading = false;
  bool _hasMore = true;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadExpenses();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _loadExpenses();
    }
  }

  Future<void> _loadExpenses() async {
    final partnership = await ref.read(activePartnershipProvider.future);
    if (partnership == null) return;

    setState(() => _loading = true);
    try {
      final newExpenses = await ref
          .read(expenseRepositoryProvider)
          .getExpenses(partnership.id, limit: 20, offset: _page * 20);
      setState(() {
        _expenses.addAll(newExpenses);
        _page++;
        _hasMore = newExpenses.length == 20;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _expenses.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadExpenses();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final partnerProfile = ref.watch(partnerProfileProvider).valueOrNull;
    final partnerName = partnerProfile?.displayName ?? 'パートナー';
    final partnerIconId = partnerProfile?.iconId ?? 1;

    return Scaffold(
      appBar: AppBar(title: const Text('履歴')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _expenses.isEmpty && !_loading
            ? const Center(child: Text('まだ支払いがありません'))
            : ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _expenses.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  if (index >= _expenses.length) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  final expense = _expenses[index];
                  final isMe = expense.paidBy == user?.id;
                  return ExpenseTile(
                    expense: expense,
                    payerName: isMe
                        ? (profile?.displayName ?? '')
                        : partnerName,
                    payerIconId: isMe ? (profile?.iconId ?? 1) : partnerIconId,
                    onTap: () => context.push('/history/${expense.id}'),
                  );
                },
              ),
      ),
    );
  }
}
