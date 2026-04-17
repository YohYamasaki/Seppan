import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/balance_provider.dart';
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
  final Set<String> _selectedIds = {};

  bool get _isSelecting => _selectedIds.isNotEmpty;

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
    final partnership = await ref.read(currentPartnershipProvider.future);
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
      _selectedIds.clear();
    });
    await _loadExpenses();
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedIds.length == _expenses.length) {
        _selectedIds.clear();
      } else {
        _selectedIds.addAll(_expenses.map((e) => e.id));
      }
    });
  }

  Future<void> _deleteSelected() async {
    final count = _selectedIds.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('まとめて削除'),
        content: Text('$count件の履歴を削除しますか？\nこの操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final repo = ref.read(expenseRepositoryProvider);
    var deleted = 0;
    for (final id in _selectedIds) {
      try {
        await repo.deleteExpense(id);
        deleted++;
      } catch (_) {
        // Continue deleting remaining items
      }
    }

    // Always invalidate caches even on partial success
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(balanceSummaryProvider);
    ref.invalidate(categoryBreakdownProvider);
    ref.read(expenseDataVersionProvider.notifier).state++;

    if (mounted) {
      final failed = count - deleted;
      if (failed > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deleted件を削除しました（$failed件は失敗）')),
        );
      }
    }
    // _refresh is triggered by expenseDataVersionProvider listener
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(expenseDataVersionProvider, (_, __) => _refresh());

    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final partnerProfile = ref.watch(partnerProfileProvider).valueOrNull;
    final partnerName = partnerProfile?.displayName ?? 'パートナー';
    final partnerIconId = partnerProfile?.iconId ?? 1;

    return Scaffold(
      appBar: _isSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedIds.clear()),
              ),
              title: Text('${_selectedIds.length}件選択中'),
              actions: [
                IconButton(
                  icon: Icon(
                    _selectedIds.length == _expenses.length
                        ? Icons.deselect
                        : Icons.select_all,
                  ),
                  tooltip: _selectedIds.length == _expenses.length
                      ? '全解除'
                      : '全選択',
                  onPressed: _selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: '削除',
                  onPressed: _deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: const Text('履歴'),
              actions: [
                if (_expenses.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.checklist),
                    tooltip: '選択',
                    onPressed: () => setState(() {
                      _selectedIds.add(_expenses.first.id);
                    }),
                  ),
              ],
            ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _expenses.isEmpty && !_loading
            ? const Center(child: Text('まだ支払いがありません'))
            : ListView.separated(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: _expenses.length + (_hasMore ? 1 : 0),
                separatorBuilder: (_, __) => const Divider(height: 1),
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
                    selected: _selectedIds.contains(expense.id),
                    selectionMode: _isSelecting,
                    onTap: _isSelecting
                        ? () => _toggleSelection(expense.id)
                        : () => context.push('/history/${expense.id}'),
                    onLongPress: () => _toggleSelection(expense.id),
                  );
                },
              ),
      ),
    );
  }
}
