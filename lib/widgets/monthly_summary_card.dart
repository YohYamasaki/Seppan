import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../utils/expense_stats.dart';
import '../utils/formatters.dart';
import 'main_card.dart';

class MonthlySummaryCard extends StatelessWidget {
  const MonthlySummaryCard({
    super.key,
    required this.summary,
    required this.myName,
    required this.partnerName,
    required this.month,
  });

  final MonthlySummary summary;
  final String myName;
  final String partnerName;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final myRatio =
        summary.total > 0 ? summary.myTotal / summary.total : 0.5;

    return MainCard(
      header: Text(
        '${month.month}月のサマリー',
        style: theme.textTheme.displayMedium,
      ),
      child: Column(
        children: [
          // Total amount
          Text(
            formatJpy(summary.total),
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          Text('合計支出', style: theme.textTheme.bodySmall),
          const Gap(16),

          // Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(
                    flex: (myRatio * 100).round().clamp(1, 99),
                    child: Container(color: colorScheme.primary),
                  ),
                  Expanded(
                    flex: ((1 - myRatio) * 100).round().clamp(1, 99),
                    child: Container(color: colorScheme.tertiary),
                  ),
                ],
              ),
            ),
          ),
          const Gap(12),

          // Legend row
          Row(
            children: [
              _legendDot(colorScheme.primary),
              const Gap(6),
              Expanded(
                child: Text(myName, style: theme.textTheme.bodyMedium),
              ),
              Text(
                formatJpy(summary.myTotal),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
          const Gap(6),
          Row(
            children: [
              _legendDot(colorScheme.tertiary),
              const Gap(6),
              Expanded(
                child: Text(partnerName, style: theme.textTheme.bodyMedium),
              ),
              Text(
                formatJpy(summary.partnerTotal),
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
