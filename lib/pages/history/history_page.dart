import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/expense.dart';
import '../../models/profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/avatar_icon.dart';
import '../../widgets/expense_tile.dart';

/// Sort options for search results.
enum _SortOrder {
  dateDesc('日付（新しい順）'),
  dateAsc('日付（古い順）'),
  amountDesc('金額（高い順）'),
  amountAsc('金額（安い順）');

  const _SortOrder(this.label);
  final String label;
}

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

  bool _searchMode = false;
  final _searchController = TextEditingController();
  String _query = '';
  List<Expense>? _allExpenses;
  bool _searchLoading = false;

  // Filters (applied client-side over the decrypted full list).
  DateTimeRange? _dateRange;
  final Set<String> _payerFilter = {}; // paidBy user ids
  final Set<String> _categoryFilter = {};
  final Set<String> _placeFilter = {};
  _SortOrder _sortOrder = _SortOrder.dateDesc;

  bool get _isSelecting => _selectedIds.isNotEmpty;

  bool get _hasActiveFilters =>
      _dateRange != null ||
      _payerFilter.isNotEmpty ||
      _categoryFilter.isNotEmpty ||
      _placeFilter.isNotEmpty;

  /// Number of active filter groups, used for the filter button badge.
  int get _activeFilterCount =>
      (_dateRange != null ? 1 : 0) +
      (_payerFilter.isNotEmpty ? 1 : 0) +
      (_categoryFilter.isNotEmpty ? 1 : 0) +
      (_placeFilter.isNotEmpty ? 1 : 0);

  bool get _hasActiveSearch => _query.trim().isNotEmpty || _hasActiveFilters;

  /// Distinct non-empty categories present in the loaded data.
  List<String> get _availableCategories {
    final s = <String>{};
    for (final e in _allExpenses ?? const <Expense>[]) {
      if (e.category.isNotEmpty) s.add(e.category);
    }
    return s.toList()..sort();
  }

  /// Distinct non-empty places present in the loaded data.
  List<String> get _availablePlaces {
    final s = <String>{};
    for (final e in _allExpenses ?? const <Expense>[]) {
      if (e.place.isNotEmpty) s.add(e.place);
    }
    return s.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadExpenses();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
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
      // Drop the cached full list so search reloads fresh data after edits.
      _allExpenses = null;
    });
    await _loadExpenses();
    if (_searchMode) await _loadAllExpenses();
  }

  /// Loads (and caches) every expense for client-side search. Server-side
  /// search is impossible because the searchable fields (memo, category,
  /// amount) are E2E-encrypted, so filtering happens on decrypted data.
  Future<void> _loadAllExpenses() async {
    if (_allExpenses != null) return;
    final partnership = await ref.read(currentPartnershipProvider.future);
    if (partnership == null) return;

    setState(() => _searchLoading = true);
    try {
      final all = await ref
          .read(expenseRepositoryProvider)
          .getAllExpenses(partnership.id);
      // getAllExpenses returns ascending order; show newest first.
      all.sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
      });
      if (mounted) {
        setState(() {
          _allExpenses = all;
          _searchLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searchLoading = false);
    }
  }

  List<Expense> get _searchResults {
    final q = _query.trim().toLowerCase();
    final dr = _dateRange;
    final list = (_allExpenses ?? const <Expense>[]).where((e) {
      if (q.isNotEmpty) {
        final hay =
            '${e.memo} ${e.category} ${e.place} ${e.amount}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      if (dr != null && (e.date.isBefore(dr.start) || e.date.isAfter(dr.end))) {
        return false;
      }
      if (_payerFilter.isNotEmpty && !_payerFilter.contains(e.paidBy)) {
        return false;
      }
      if (_categoryFilter.isNotEmpty && !_categoryFilter.contains(e.category)) {
        return false;
      }
      if (_placeFilter.isNotEmpty && !_placeFilter.contains(e.place)) {
        return false;
      }
      return true;
    }).toList();
    list.sort(_compareForSort);
    return list;
  }

  int _compareForSort(Expense a, Expense b) {
    switch (_sortOrder) {
      case _SortOrder.dateDesc:
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      case _SortOrder.dateAsc:
        final c = a.date.compareTo(b.date);
        return c != 0 ? c : a.createdAt.compareTo(b.createdAt);
      case _SortOrder.amountDesc:
        return b.amount.compareTo(a.amount);
      case _SortOrder.amountAsc:
        return a.amount.compareTo(b.amount);
    }
  }

  void _enterSearch() {
    setState(() {
      _searchMode = true;
      _selectedIds.clear();
    });
    _loadAllExpenses();
  }

  void _exitSearch() {
    setState(() {
      _searchMode = false;
      _query = '';
      _searchController.clear();
      _clearFilters();
    });
  }

  void _clearFilters() {
    _dateRange = null;
    _payerFilter.clear();
    _categoryFilter.clear();
    _placeFilter.clear();
    _sortOrder = _SortOrder.dateDesc;
  }

  Future<void> _openFilterSheet(List<_PayerOption> payerOptions) async {
    final result = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      // Cap the height so it reads as a sheet rising from the bottom
      // rather than covering the whole screen; content scrolls inside.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        initial: _FilterResult(
          dateRange: _dateRange,
          payers: Set.of(_payerFilter),
          categories: Set.of(_categoryFilter),
          places: Set.of(_placeFilter),
          sort: _sortOrder,
        ),
        payerOptions: payerOptions,
        categoryOptions: _availableCategories,
        placeOptions: _availablePlaces,
      ),
    );
    if (result == null) return;
    setState(() {
      _dateRange = result.dateRange;
      _payerFilter
        ..clear()
        ..addAll(result.payers);
      _categoryFilter
        ..clear()
        ..addAll(result.categories);
      _placeFilter
        ..clear()
        ..addAll(result.places);
      _sortOrder = result.sort;
    });
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

    // Payer filter options (me + partner if linked).
    final payerOptions = <_PayerOption>[
      if (user != null)
        _PayerOption(user.id, profile?.displayName ?? '自分', profile?.iconId ?? 1),
      if (partnerProfile != null)
        _PayerOption(partnerProfile.id, partnerName, partnerIconId),
    ];

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
          : _searchMode
              ? AppBar(
                  leading: IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: _exitSearch,
                  ),
                  title: TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'メモ・ジャンル・購入場所・金額で検索',
                      border: InputBorder.none,
                    ),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  actions: [
                    if (_query.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _query = '';
                          _searchController.clear();
                        }),
                      ),
                    IconButton(
                      icon: Badge.count(
                        count: _activeFilterCount,
                        isLabelVisible: _activeFilterCount > 0,
                        child: const Icon(Icons.tune),
                      ),
                      tooltip: 'フィルタ',
                      onPressed: () => _openFilterSheet(payerOptions),
                    ),
                  ],
                )
              : AppBar(
                  title: const Text('履歴'),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: '検索',
                      onPressed: _enterSearch,
                    ),
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
      body: _searchMode
          ? _buildSearchBody(
              user?.id, profile, partnerName, partnerIconId, payerOptions)
          : RefreshIndicator(
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
                          payerIconId:
                              isMe ? (profile?.iconId ?? 1) : partnerIconId,
                          selected: _selectedIds.contains(expense.id),
                          selectionMode: _isSelecting,
                          onTap: _isSelecting
                              ? () => _toggleSelection(expense.id)
                              : () {
                                  // Use the parent route matching the current
                                  // location so that back navigation stays
                                  // consistent (e.g. /history-view when pushed
                                  // from home, /history when on the history
                                  // tab). Using the wrong parent causes a
                                  // navigator GlobalKey collision on push.
                                  final loc =
                                      GoRouterState.of(context).matchedLocation;
                                  final base = loc.startsWith('/history-view')
                                      ? '/history-view'
                                      : '/history';
                                  context.push('$base/${expense.id}');
                                },
                          onLongPress: () => _toggleSelection(expense.id),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildSearchBody(
    String? userId,
    Profile? profile,
    String partnerName,
    int partnerIconId,
    List<_PayerOption> payerOptions,
  ) {
    if (_searchLoading && _allExpenses == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final results = _searchResults;

    Widget listArea;
    if (!_hasActiveSearch) {
      listArea = const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'キーワードを入力するか、フィルタで絞り込んでください',
            textAlign: TextAlign.center,
          ),
        ),
      );
    } else if (results.isEmpty) {
      listArea = const Center(child: Text('該当する履歴がありません'));
    } else {
      listArea = ListView.separated(
        itemCount: results.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final expense = results[index];
          final isMe = expense.paidBy == userId;
          return ExpenseTile(
            expense: expense,
            payerName: isMe ? (profile?.displayName ?? '') : partnerName,
            payerIconId: isMe ? (profile?.iconId ?? 1) : partnerIconId,
            onTap: () {
              final loc = GoRouterState.of(context).matchedLocation;
              final base = loc.startsWith('/history-view')
                  ? '/history-view'
                  : '/history';
              context.push('$base/${expense.id}');
            },
          );
        },
      );
    }

    return Column(
      children: [
        if (_hasActiveSearch) _buildResultHeader(results, payerOptions),
        Expanded(child: listArea),
      ],
    );
  }

  /// Result count + total + active filter chips shown above the list.
  Widget _buildResultHeader(
    List<Expense> results,
    List<_PayerOption> payerOptions,
  ) {
    final theme = Theme.of(context);
    final total = results.fold<int>(0, (sum, e) => sum + e.amount);
    final payerNames = {for (final p in payerOptions) p.id: p.name};

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${results.length}件 ・ 合計 ${formatJpy(total)}',
                  style: theme.textTheme.bodyMedium),
              const Spacer(),
              Text(_sortOrder.label, style: theme.textTheme.bodySmall),
            ],
          ),
          if (_hasActiveFilters) ...[
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (_dateRange != null)
                  _filterChip(
                    '${formatDate(_dateRange!.start)}〜'
                    '${formatDate(_dateRange!.end)}',
                    () => setState(() => _dateRange = null),
                  ),
                for (final id in _payerFilter)
                  _filterChip(
                    payerNames[id] ?? '不明',
                    () => setState(() => _payerFilter.remove(id)),
                  ),
                for (final c in _categoryFilter)
                  _filterChip(c, () => setState(() => _categoryFilter.remove(c))),
                for (final p in _placeFilter)
                  _filterChip(p, () => setState(() => _placeFilter.remove(p))),
                TextButton(
                  onPressed: () => setState(_clearFilters),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  child: const Text('すべてクリア'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterChip(String label, VoidCallback onDeleted) {
    return InputChip(
      label: Text(label),
      onDeleted: onDeleted,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

/// A selectable payer option for the filter sheet.
class _PayerOption {
  const _PayerOption(this.id, this.name, this.iconId);
  final String id;
  final String name;
  final int iconId;
}

/// Immutable bundle of filter values exchanged with [_FilterSheet].
class _FilterResult {
  const _FilterResult({
    this.dateRange,
    required this.payers,
    required this.categories,
    required this.places,
    required this.sort,
  });

  final DateTimeRange? dateRange;
  final Set<String> payers;
  final Set<String> categories;
  final Set<String> places;
  final _SortOrder sort;
}

/// Bottom sheet for choosing date range, payer/category/place filters,
/// and sort order. Edits a local copy and returns it on apply.
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.initial,
    required this.payerOptions,
    required this.categoryOptions,
    required this.placeOptions,
  });

  final _FilterResult initial;
  final List<_PayerOption> payerOptions;
  final List<String> categoryOptions;
  final List<String> placeOptions;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late DateTimeRange? _dateRange = widget.initial.dateRange;
  late final Set<String> _payers = Set.of(widget.initial.payers);
  late final Set<String> _categories = Set.of(widget.initial.categories);
  late final Set<String> _places = Set.of(widget.initial.places);
  late _SortOrder _sort = widget.initial.sort;

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: _dateRange,
      locale: const Locale('ja'),
    );
    if (picked != null) setState(() => _dateRange = picked);
  }

  void _applyPreset(DateTimeRange range) => setState(() => _dateRange = range);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final thisMonth = DateTimeRange(
      start: DateTime(now.year, now.month),
      end: DateTime(now.year, now.month + 1, 0),
    );
    final lastMonth = DateTimeRange(
      start: DateTime(now.year, now.month - 1),
      end: DateTime(now.year, now.month, 0),
    );
    final thisYear = DateTimeRange(
      start: DateTime(now.year),
      end: DateTime(now.year, 12, 31),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('絞り込み', style: theme.textTheme.titleLarge),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _dateRange = null;
                      _payers.clear();
                      _categories.clear();
                      _places.clear();
                      _sort = _SortOrder.dateDesc;
                    }),
                    child: const Text('リセット'),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Date range
              _sectionLabel('期間'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  _dateRange == null
                      ? 'カレンダーで期間を選択'
                      : '${formatDate(_dateRange!.start)}〜'
                          '${formatDate(_dateRange!.end)}',
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  ActionChip(
                    label: const Text('今月'),
                    onPressed: () => _applyPreset(thisMonth),
                  ),
                  ActionChip(
                    label: const Text('先月'),
                    onPressed: () => _applyPreset(lastMonth),
                  ),
                  ActionChip(
                    label: const Text('今年'),
                    onPressed: () => _applyPreset(thisYear),
                  ),
                  if (_dateRange != null)
                    ActionChip(
                      label: const Text('期間をクリア'),
                      onPressed: () => setState(() => _dateRange = null),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // Payer
              if (widget.payerOptions.isNotEmpty) ...[
                _sectionLabel('支払者'),
                ...widget.payerOptions.map(
                  (p) => CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _payers.contains(p.id),
                    secondary: AvatarIcon(iconId: p.iconId, radius: 16),
                    title: Text(p.name),
                    onChanged: (v) => setState(() {
                      if (v == true) {
                        _payers.add(p.id);
                      } else {
                        _payers.remove(p.id);
                      }
                    }),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Category
              if (widget.categoryOptions.isNotEmpty) ...[
                _sectionLabel('ジャンル'),
                const SizedBox(height: 8),
                _checkboxWrap(widget.categoryOptions, _categories),
                const SizedBox(height: 16),
              ],

              // Place
              if (widget.placeOptions.isNotEmpty) ...[
                _sectionLabel('購入場所'),
                const SizedBox(height: 8),
                _checkboxWrap(widget.placeOptions, _places),
                const SizedBox(height: 16),
              ],

              // Sort
              _sectionLabel('並び替え'),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _SortOrder.values
                    .map((s) => ChoiceChip(
                          label: Text(s.label),
                          selected: _sort == s,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _sort = s),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(
                    context,
                    _FilterResult(
                      dateRange: _dateRange,
                      payers: _payers,
                      categories: _categories,
                      places: _places,
                      sort: _sort,
                    ),
                  ),
                  child: const Text('適用'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
      );

  /// A wrap of FilterChips acting as a multi-select checkbox group.
  Widget _checkboxWrap(List<String> options, Set<String> selected) {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: options
          .map((o) => FilterChip(
                label: Text(o),
                selected: selected.contains(o),
                onSelected: (v) => setState(() {
                  if (v) {
                    selected.add(o);
                  } else {
                    selected.remove(o);
                  }
                }),
              ))
          .toList(),
    );
  }
}
