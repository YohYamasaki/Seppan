import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'encryption_provider.dart';
import 'partnership_provider.dart';

part 'expense_provider.g.dart';

/// Incremented on tab switch to trigger data refresh in stateful pages.
final expenseDataVersionProvider = StateProvider<int>((ref) => 0);

@riverpod
ExpenseRepository expenseRepository(Ref ref) {
  final key = ref.watch(encryptionKeyNotifierProvider);
  return ExpenseRepository(encryptionKey: key);
}

@riverpod
Future<List<Expense>> recentExpenses(Ref ref) async {
  final partnership = await ref.watch(currentPartnershipProvider.future);
  if (partnership == null) return [];
  return ref.watch(expenseRepositoryProvider).getExpenses(
        partnership.id,
        limit: 5,
      );
}

@riverpod
Future<Expense?> expenseDetail(Ref ref, String expenseId) async {
  return ref.watch(expenseRepositoryProvider).getExpense(expenseId);
}

/// Distinct, non-empty purchase places from past expenses, most recent
/// first. Used to populate the place dropdown on the input screen.
/// Decryption happens client-side, so suggestions are derived from the
/// fully-decrypted expense list.
@riverpod
Future<List<String>> placeSuggestions(Ref ref) async {
  final partnership = await ref.watch(currentPartnershipProvider.future);
  if (partnership == null) return [];
  final all =
      await ref.watch(expenseRepositoryProvider).getAllExpenses(partnership.id);
  final seen = <String>{};
  final result = <String>[];
  // getAllExpenses returns ascending order; reverse for most-recent-first.
  for (final e in all.reversed) {
    final p = e.place.trim();
    if (p.isNotEmpty && seen.add(p)) result.add(p);
  }
  return result;
}
