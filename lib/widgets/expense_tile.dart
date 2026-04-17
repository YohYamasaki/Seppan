import 'package:flutter/material.dart';

import '../models/expense.dart';
import '../utils/formatters.dart';
import 'avatar_icon.dart';

class ExpenseTile extends StatelessWidget {
  const ExpenseTile({
    super.key,
    required this.expense,
    required this.payerName,
    required this.payerIconId,
    this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selectionMode = false,
  });

  final Expense expense;
  final String payerName;
  final int payerIconId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selectionMode;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: selectionMode
          ? Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? colorScheme.primary : colorScheme.outline,
            )
          : AvatarIcon(iconId: payerIconId, radius: 20),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(payerName, style: Theme.of(context).textTheme.bodyLarge),
          Text(formatDate(expense.date),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      subtitle: Text(
        '${formatJpy(expense.amount)} (${ratioLabel(expense.ratio)}) '
        '${expense.category.isNotEmpty ? expense.category : ''}'
        '${expense.memo.isNotEmpty ? ' - ${expense.memo}' : ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: selectionMode ? null : const Icon(Icons.chevron_right, size: 20),
      selected: selected,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.3),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class ExpenseSimpleTile extends StatelessWidget {
  const ExpenseSimpleTile({
    super.key,
    required this.payerName,
    required this.payerIconId,
    required this.amount,
    required this.burdenPercent,
  });

  final String payerName;
  final int payerIconId;
  final int amount;
  /// Current user's burden percentage (0–100).
  final int burdenPercent;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: AvatarIcon(iconId: payerIconId, radius: 16),
      title: Text(payerName),
      subtitle: Text('あなたの負担 $burdenPercent%',
          style: Theme.of(context).textTheme.bodySmall),
      trailing: Text(
        formatJpy(amount),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
