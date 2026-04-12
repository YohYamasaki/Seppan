import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../utils/expense_stats.dart';
import 'auth_provider.dart';
import 'expense_provider.dart';
import 'partnership_provider.dart';

part 'balance_provider.g.dart';

/// Net balance for current user.
/// Positive = partner owes you. Negative = you owe partner.
@riverpod
Future<int> balanceSummary(Ref ref) async {
  final partnership = await ref.watch(currentPartnershipProvider.future);
  final user = ref.watch(currentUserProvider);
  if (partnership == null || user == null) return 0;
  return ref.watch(expenseRepositoryProvider).getBalanceSummary(
        partnership.id,
        user.id,
      );
}

/// Category breakdown for current month (current user's burden).
@riverpod
Future<List<CategoryAmount>> categoryBreakdown(Ref ref) async {
  final partnership = await ref.watch(currentPartnershipProvider.future);
  final user = ref.watch(currentUserProvider);
  if (partnership == null || user == null) return [];
  return ref.watch(expenseRepositoryProvider).getCategoryBreakdown(
        partnership.id,
        user.id,
        month: DateTime.now(),
      );
}
