import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';
import '../../providers/expense_provider.dart';
import '../../providers/partnership_provider.dart';
import '../../utils/expense_stats.dart';
import '../../utils/formatters.dart';

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

class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});

  @override
  ConsumerState<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends ConsumerState<StatsPage> {
  late DateTime _month;
  List<CategoryAmount>? _breakdown;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _loadData();
  }

  Future<void> _loadData() async {
    final partnership = await ref.read(currentPartnershipProvider.future);
    final user = ref.read(currentUserProvider);
    if (partnership == null || user == null) return;

    setState(() => _loading = true);
    try {
      final breakdown = await ref
          .read(expenseRepositoryProvider)
          .getCategoryBreakdown(partnership.id, user.id, month: _month);
      if (mounted) {
        setState(() {
          _breakdown = breakdown;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
      _breakdown = null;
    });
    _loadData();
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final userName = profile?.displayName ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリ別出費')),
      body: Column(
        children: [
          // Month navigator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(Icons.chevron_left),
                ),
                Column(
                  children: [
                    Text(
                      '${_month.year}年${_month.month}月',
                      style: theme.textTheme.titleLarge,
                    ),
                    if (userName.isNotEmpty)
                      Text(
                        '$userNameさんの負担分',
                        style: theme.textTheme.bodySmall,
                      ),
                  ],
                ),
                IconButton(
                  onPressed: _isCurrentMonth ? null : () => _changeMonth(1),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _breakdown == null || _breakdown!.isEmpty
                    ? const Center(child: Text('データがありません'))
                    : _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    final breakdown = _breakdown!;
    final total = breakdown.fold<int>(0, (sum, e) => sum + e.amount);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Pie chart
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 44,
              sections: breakdown.asMap().entries.map((e) {
                final pct = total > 0 ? e.value.amount / total * 100 : 0.0;
                return PieChartSectionData(
                  value: pct,
                  color: _chartColors[e.key % _chartColors.length],
                  radius: 32,
                  showTitle: false,
                );
              }).toList(),
            ),
          ),
        ),
        const Gap(8),
        Center(
          child: Text(
            '合計 ${formatJpy(total)}',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const Gap(12),
        const Divider(),
        // Category list
        ...breakdown.asMap().entries.map((e) {
          final i = e.key;
          final item = e.value;
          final pct = total > 0 ? (item.amount / total * 100) : 0;
          return ListTile(
            onTap: () => context.push(
              '/stats/category-detail'
              '?category=${Uri.encodeComponent(item.category)}'
              '&year=${_month.year}'
              '&month=${_month.month}',
            ),
            leading: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _chartColors[i % _chartColors.length],
                shape: BoxShape.circle,
              ),
            ),
            title: Text(item.category),
            subtitle: Text('${pct.round()}%'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(formatJpy(item.amount), style: theme.textTheme.bodyLarge),
                const Gap(4),
                Icon(Icons.chevron_right, size: 20, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ],
            ),
          );
        }),
      ],
    );
  }
}
