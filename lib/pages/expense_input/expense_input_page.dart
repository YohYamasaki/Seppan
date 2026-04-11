import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../models/expense.dart';
import '../../providers/auth_provider.dart';
import '../../providers/balance_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../utils/formatters.dart';
import '../../widgets/avatar_icon.dart';
import '../settings/category_edit_page.dart';

class ExpenseInputPage extends ConsumerStatefulWidget {
  const ExpenseInputPage({super.key, this.editExpense});

  final Expense? editExpense;

  @override
  ConsumerState<ExpenseInputPage> createState() => _ExpenseInputPageState();
}

class _ExpenseInputPageState extends ConsumerState<ExpenseInputPage> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _memoController = TextEditingController();
  DateTime _date = DateTime.now();
  String? _payerUserId;
  double _ratio = 0.5;
  String _category = 'その他';
  bool _loading = false;
  bool get _isEditing => widget.editExpense != null;

  @override
  void initState() {
    super.initState();
    final edit = widget.editExpense;
    if (edit != null) {
      _amountController.text = edit.amount.toString();
      _memoController.text = edit.memo;
      _date = edit.date;
      _payerUserId = edit.paidBy;
      _ratio = edit.ratio;
      _category = edit.category;
    } else {
      final user = ref.read(currentUserProvider);
      _payerUserId = user?.id;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  void _onRatioGesture(double dx, double width, bool isMyPayment) {
    final rawMyShare = (dx / width).clamp(0.0, 1.0);
    final snapped = (rawMyShare * 10).round().clamp(0, 10) / 10;
    setState(() {
      _ratio = isMyPayment ? snapped : 1 - snapped;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('ja'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  /// Returns the partnership to associate with the expense.
  /// Uses active partnership first, falls back to pending, creates one if needed.
  Future<String> _resolvePartnershipId() async {
    final active = await ref.read(activePartnershipProvider.future);
    if (active != null) return active.id;

    final user = ref.read(currentUserProvider);
    if (user == null) throw StateError('Not logged in');

    final repo = ref.read(partnershipRepositoryProvider);
    final pending = await repo.getPendingPartnership(user.id);
    if (pending != null) return pending.id;

    await repo.archiveOldPendingPartnerships(user.id);
    final created = await repo.createPartnership(user.id);
    return created.id;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_payerUserId == null) return;

    setState(() => _loading = true);
    try {
      final partnershipId = await _resolvePartnershipId();
      final amount = int.parse(_amountController.text.replaceAll(',', ''));
      final expense = Expense(
        id: _isEditing ? widget.editExpense!.id : '',
        partnershipId: partnershipId,
        paidBy: _payerUserId!,
        amount: amount,
        ratio: _ratio,
        date: _date,
        category: _category,
        memo: _memoController.text.trim(),
        createdAt: _isEditing ? widget.editExpense!.createdAt : DateTime.now(),
      );

      if (_isEditing) {
        await ref.read(expenseRepositoryProvider).updateExpense(expense);
      } else {
        await ref.read(expenseRepositoryProvider).addExpense(expense);
      }
      ref.invalidate(recentExpensesProvider);
      ref.invalidate(balanceSummaryProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存に失敗しました: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final partnership = ref.watch(activePartnershipProvider).valueOrNull;
    final partnerProfile = ref.watch(partnerProfileProvider).valueOrNull;
    final categories = ref.watch(categoriesProvider);

    final myName = profile?.displayName ?? '自分';
    final myIconId = profile?.iconId ?? 1;
    final partnerName = partnerProfile?.displayName ?? 'パートナー';
    final partnerIconId = partnerProfile?.iconId ?? 1;
    final isMyPayment = _payerUserId == user?.id;
    final currentPayerName = isMyPayment ? myName : partnerName;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '支払を編集' : '支払を入力'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('日付'),
                trailing: TextButton(
                  onPressed: _pickDate,
                  child: Text(formatDate(_date)),
                ),
              ),
              const Divider(height: 1),
              const Gap(12),

              // Payer (only show selector when partner is linked)
              if (partnership?.user2Id != null) ...[
                const Text(
                  '支払者',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Gap(8),
                Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // Animated selection indicator
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOutCubic,
                        alignment: isMyPayment
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: FractionallySizedBox(
                          widthFactor: 0.5,
                          child: Container(
                            height: 40,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Segments
                      SizedBox.expand(child: Row(
                        children: [
                          // My segment
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  _payerUserId = user?.id;
                                });
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AvatarIcon(
                                      iconId: myIconId, radius: 10),
                                  const Gap(6),
                                  Text(
                                    myName,
                                    style: TextStyle(
                                      color: isMyPayment
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                      fontWeight: isMyPayment
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Partner segment
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                setState(() {
                                  final p = partnership;
                                  if (p != null) {
                                    _payerUserId = p.user1Id == user?.id
                                        ? p.user2Id
                                        : p.user1Id;
                                  }
                                });
                              },
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  AvatarIcon(
                                      iconId: partnerIconId, radius: 10),
                                  const Gap(6),
                                  Text(
                                    partnerName,
                                    style: TextStyle(
                                      color: !isMyPayment
                                          ? Colors.white
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                      fontWeight: !isMyPayment
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      )),
                    ],
                  ),
                ),
                const Gap(20),
              ],

              // Amount
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  labelText: '金額',
                  prefixText: '¥ ',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return '金額を入力してください';
                  final amount = int.tryParse(value.replaceAll(',', ''));
                  if (amount == null || amount <= 0) return '正しい金額を入力してください';
                  return null;
                },
              ),
              const Gap(20),

              // Ratio – segmented bar
              const Text('負担率', style: TextStyle(fontWeight: FontWeight.bold)),
              const Gap(12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final barWidth = constraints.maxWidth;
                  final colorScheme = Theme.of(context).colorScheme;
                  final theme = Theme.of(context);
                  final myPercent = isMyPayment ? _ratio : 1 - _ratio;
                  final partnerPercent = 1 - myPercent;
                  final myW = barWidth * myPercent;
                  const dur = Duration(milliseconds: 150);
                  const curve = Curves.easeOutExpo;
                  final desc = ratioDescription(_ratio, currentPayerName);
                  final atEdge = myPercent <= 0.05 || myPercent >= 0.95;
                  final gap = atEdge ? 0.0 : 4.0;
                  final innerR = Radius.circular(atEdge ? 24 : 4);

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => _onRatioGesture(
                      d.localPosition.dx,
                      barWidth,
                      isMyPayment,
                    ),
                    onHorizontalDragUpdate: (d) => _onRatioGesture(
                      d.localPosition.dx,
                      barWidth,
                      isMyPayment,
                    ),
                    child: Column(
                      children: [
                        // Avatars + names above segments
                        SizedBox(
                          height: 52,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              AnimatedPositioned(
                                duration: dur,
                                curve: curve,
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: myW.clamp(0.0, barWidth),
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AvatarIcon(iconId: myIconId, radius: 12),
                                      const Gap(2),
                                      Text(
                                        myName,
                                        style: theme.textTheme.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedPositioned(
                                duration: dur,
                                curve: curve,
                                left: myW.clamp(0.0, barWidth),
                                top: 0,
                                bottom: 0,
                                right: 0,
                                child: Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AvatarIcon(
                                        iconId: partnerIconId,
                                        radius: 12,
                                      ),
                                      const Gap(2),
                                      Text(
                                        partnerName,
                                        style: theme.textTheme.bodySmall,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(6),
                        // Bar with vertical divider
                        SizedBox(
                          height: 48,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // Left bar (my segment)
                              AnimatedPositioned(
                                duration: dur,
                                curve: curve,
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: (myW - gap).clamp(0.0, barWidth),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.primaryContainer,
                                    borderRadius: BorderRadius.horizontal(
                                      left: const Radius.circular(24),
                                      right: innerR,
                                    ),
                                  ),
                                ),
                              ),
                              // Right bar (partner segment)
                              AnimatedPositioned(
                                duration: dur,
                                curve: curve,
                                left: (myW + gap).clamp(0.0, barWidth),
                                top: 0,
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: colorScheme.tertiaryContainer,
                                    borderRadius: BorderRadius.horizontal(
                                      left: innerR,
                                      right: const Radius.circular(24),
                                    ),
                                  ),
                                ),
                              ),
                              // Vertical divider thumb
                              AnimatedPositioned(
                                duration: dur,
                                curve: curve,
                                left: myW.clamp(0.0, barWidth) - 2,
                                top: -3,
                                bottom: -3,
                                width: 4,
                                child: AnimatedOpacity(
                                  duration: dur,
                                  opacity:
                                      (myPercent > 0.05 && myPercent < 0.95)
                                      ? 1.0
                                      : 0.0,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                ),
                              ),
                              // My % text
                              AnimatedPositioned(
                                duration: dur,
                                curve: curve,
                                left: 0,
                                top: 0,
                                bottom: 0,
                                width: myW.clamp(0.0, barWidth),
                                child: Center(
                                  child: AnimatedOpacity(
                                    duration: dur,
                                    opacity: myPercent >= 0.2 ? 1.0 : 0.0,
                                    child: Text(
                                      '${(myPercent * 100).round()}%',
                                      style: TextStyle(
                                        color: colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              // Partner % text
                              AnimatedPositioned(
                                duration: dur,
                                curve: curve,
                                left: myW.clamp(0.0, barWidth),
                                top: 0,
                                bottom: 0,
                                right: 0,
                                child: Center(
                                  child: AnimatedOpacity(
                                    duration: dur,
                                    opacity: partnerPercent >= 0.2 ? 1.0 : 0.0,
                                    child: Text(
                                      '${(partnerPercent * 100).round()}%',
                                      style: TextStyle(
                                        color: colorScheme.onTertiaryContainer,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Gap(8),
                        // Amounts below bar, aligned to segments
                        ValueListenableBuilder(
                          valueListenable: _amountController,
                          builder: (context, _, _) {
                            final parsed = int.tryParse(
                              _amountController.text.replaceAll(',', ''),
                            );
                            final amount = parsed ?? 0;
                            final myBurden = isMyPayment
                                ? (amount * _ratio).round()
                                : (amount * (1 - _ratio)).round();
                            final partnerBurden = amount - myBurden;
                            return SizedBox(
                              height: 22,
                              child: Stack(
                                children: [
                                  AnimatedPositioned(
                                    duration: dur,
                                    curve: curve,
                                    left: 0,
                                    top: 0,
                                    bottom: 0,
                                    width: myW.clamp(0.0, barWidth),
                                    child: Center(
                                      child: Text(
                                        amount > 0 ? formatJpy(myBurden) : '',
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ),
                                  ),
                                  AnimatedPositioned(
                                    duration: dur,
                                    curve: curve,
                                    left: myW.clamp(0.0, barWidth),
                                    top: 0,
                                    bottom: 0,
                                    right: 0,
                                    child: Center(
                                      child: Text(
                                        amount > 0
                                            ? formatJpy(partnerBurden)
                                            : '',
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        // Description (fixed height to prevent layout shift)
                        SizedBox(
                          height: 22,
                          child: Center(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: desc.isNotEmpty ? 1.0 : 0.0,
                              child: Text(
                                desc.isNotEmpty ? desc : ' ',
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const Gap(20),

              // Category
              Row(
                children: [
                  const Text(
                    'ジャンル',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CategoryEditPage(),
                        ),
                      );
                      ref.invalidate(categoriesProvider);
                    },
                    child: const Text('編集'),
                  ),
                ],
              ),
              const Gap(8),
              categories.when(
                data: (cats) => Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: cats.map((cat) {
                    final isSelected = _category == cat.name;
                    return ChoiceChip(
                      label: Text(cat.name),
                      selected: isSelected,
                      showCheckmark: false,
                      selectedColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                      onSelected: (_) => setState(() => _category = cat.name),
                    );
                  }).toList(),
                ),
                loading: () => const Center(
                  child: SizedBox(
                    height: 32,
                    width: 32,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, _) => const Text('カテゴリの読み込みに失敗しました'),
              ),
              const Gap(20),

              // Memo
              TextFormField(
                controller: _memoController,
                decoration: const InputDecoration(
                  labelText: 'メモ（任意）',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const Gap(32),

              // Submit
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _isEditing ? '更新する' : '入力する',
                        style: const TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
