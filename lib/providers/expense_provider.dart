import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/expense.dart';
import '../repositories/expense_repository.dart';
import 'encryption_provider.dart';
import 'partnership_provider.dart';

part 'expense_provider.g.dart';

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
