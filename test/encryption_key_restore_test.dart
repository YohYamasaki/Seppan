import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/models/expense.dart';
import 'package:seppan/providers/encryption_provider.dart';
import 'package:seppan/providers/expense_provider.dart';
import 'package:seppan/repositories/expense_repository.dart';

void main() {
  group('ExpenseRepository with null encryption key', () {
    late ExpenseRepository repo;

    setUp(() {
      repo = ExpenseRepository(encryptionKey: null);
    });

    test('getExpenses returns empty list', () async {
      final result = await repo.getExpenses('any-partnership-id');
      expect(result, isEmpty);
    });

    test('getExpense returns null', () async {
      final result = await repo.getExpense('any-expense-id');
      expect(result, isNull);
    });

    test('getBalanceSummary returns 0', () async {
      final result =
          await repo.getBalanceSummary('any-partnership-id', 'any-user-id');
      expect(result, equals(0));
    });

    test('getMonthlyExpenseRows returns empty list', () async {
      final result = await repo.getMonthlyExpenseRows(
        'any-partnership-id',
        month: DateTime(2026, 4),
      );
      expect(result, isEmpty);
    });

    test('getExpensesByMonth returns empty list', () async {
      final result = await repo.getExpensesByMonth(
        'any-partnership-id',
        month: DateTime(2026, 4),
      );
      expect(result, isEmpty);
    });

    test('getCategoryBreakdown returns empty list', () async {
      final result = await repo.getCategoryBreakdown(
        'any-partnership-id',
        'any-user-id',
        month: DateTime(2026, 4),
      );
      expect(result, isEmpty);
    });

    test('addExpense still throws when key is null', () async {
      expect(
        () => repo.addExpense(_dummyExpense()),
        throwsStateError,
      );
    });

    test('updateExpense still throws when key is null', () async {
      expect(
        () => repo.updateExpense(_dummyExpense()),
        throwsStateError,
      );
    });
  });

  group('Encryption key auto-restore', () {
    test('key restored from cache is picked up by new ExpenseRepository', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially null
      expect(container.read(encryptionKeyNotifierProvider), isNull);

      // Simulate cache restore setting the key
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;

      // expenseRepositoryProvider watches encryptionKeyNotifierProvider,
      // so a new read should get a repository with the key
      final repo = container.read(expenseRepositoryProvider);
      expect(repo.encryptionKey, equals(key));
    });

    test('expenseRepository rebuilds when key becomes available', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // First read: key is null
      final repo1 = container.read(expenseRepositoryProvider);
      expect(repo1.encryptionKey, isNull);

      // Key becomes available
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;

      // Second read: new repository instance with key
      final repo2 = container.read(expenseRepositoryProvider);
      expect(repo2.encryptionKey, equals(key));
      expect(identical(repo1, repo2), isFalse);
    });
  });
}

Expense _dummyExpense() {
  return Expense(
    id: 'fake-id',
    partnershipId: 'fake-partnership',
    paidBy: 'fake-user',
    amount: 1000,
    date: DateTime(2026, 4, 13),
    createdAt: DateTime(2026, 4, 13),
  );
}
