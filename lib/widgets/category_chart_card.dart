import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../utils/expense_stats.dart';
import '../utils/formatters.dart';
import 'main_card.dart';

/// Fixed palette for up to 8 categories; wraps around for more.
const _chartColors = [
  Color(0xFFFF8D00), // orange (primary)
  Color(0xFF4CAF50), // green
  Color(0xFF2196F3), // blue
  Color(0xFFE91E63), // pink
  Color(0xFF9C27B0), // purple
  Color(0xFF00BCD4), // cyan
  Color(0xFFFF5722), // deep orange
  Color(0xFF607D8B), // blue grey
];

class CategoryChartCard extends StatelessWidget {
  const CategoryChartCard({
    super.key,
    required this.breakdown,
    required this.month,
    required this.userName,
  });

  final List<CategoryAmount> breakdown;
  final DateTime month;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (breakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final total =
        breakdown.fold<int>(0, (sum, e) => sum + e.amount);

    return MainCard(
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'カテゴリ別出費',
            style: theme.textTheme.displayMedium,
          ),
          Text(
            '${month.month}月 · $userNameさんの負担分',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
      child: Column(
        children: [
          // Pie chart
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 36,
                sections: _buildSections(total),
              ),
            ),
          ),
          const Gap(16),

          // Legend
          ...breakdown.asMap().entries.map((e) {
            final i = e.key;
            final item = e.value;
            final pct = total > 0 ? (item.amount / total * 100) : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _colorAt(i),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: Text(item.category,
                        style: theme.textTheme.bodyMedium),
                  ),
                  Text(
                    '${pct.round()}%',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Gap(8),
                  Text(
                    formatJpy(item.amount),
                    style: theme.textTheme.bodyLarge,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections(int total) {
    return breakdown.asMap().entries.map((e) {
      final i = e.key;
      final item = e.value;
      final pct = total > 0 ? item.amount / total * 100 : 0.0;
      return PieChartSectionData(
        value: pct,
        color: _colorAt(i),
        radius: 28,
        showTitle: false,
      );
    }).toList();
  }

  Color _colorAt(int index) => _chartColors[index % _chartColors.length];
}
