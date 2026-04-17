import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../config/supabase.dart';
import '../models/expense.dart';
import '../services/encryption_service.dart';
import '../utils/balance.dart';
import '../utils/expense_stats.dart';

class ExpenseRepository {
  ExpenseRepository({this.encryptionKey});

  final Uint8List? encryptionKey;

  static const _table = 'expenses';
  static const _uuid = Uuid();

  Future<void> addExpense(Expense expense) async {
    final key = encryptionKey;
    if (key == null) throw StateError('Encryption key not available');

    final id = _uuid.v4();
    final encryptedData = await EncryptionService.encryptExpenseFields(
      key: key,
      expenseId: id,
      partnershipId: expense.partnershipId,
      amount: expense.amount,
      currency: expense.currency,
      ratio: expense.ratio,
      category: expense.category,
      memo: expense.memo,
    );

    await supabase.from(_table).insert({
      'id': id,
      'partnership_id': expense.partnershipId,
      'paid_by': expense.paidBy,
      'date': expense.date.toIso8601String().substring(0, 10),
      'encrypted_data': encryptedData,
    });
  }

  Future<List<Expense>> getExpenses(
    String partnershipId, {
    int limit = 20,
    int offset = 0,
  }) async {
    if (encryptionKey == null) return [];
    final data = await supabase
        .from(_table)
        .select()
        .eq('partnership_id', partnershipId)
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return Future.wait(data.map((e) => _decryptRow(e, partnershipId)));
  }

  Future<List<Expense>> getAllExpenses(String partnershipId) async {
    if (encryptionKey == null) return [];
    final data = await supabase
        .from(_table)
        .select()
        .eq('partnership_id', partnershipId)
        .order('date', ascending: true)
        .order('created_at', ascending: true);
    return Future.wait(data.map((e) => _decryptRow(e, partnershipId)));
  }

  Future<Expense?> getExpense(String expenseId) async {
    if (encryptionKey == null) return null;
    final data = await supabase
        .from(_table)
        .select()
        .eq('id', expenseId)
        .maybeSingle();
    if (data == null) return null;
    return _decryptRow(data, data['partnership_id'] as String);
  }

  Future<void> updateExpense(Expense expense) async {
    final key = encryptionKey;
    if (key == null) throw StateError('Encryption key not available');

    final encryptedData = await EncryptionService.encryptExpenseFields(
      key: key,
      expenseId: expense.id,
      partnershipId: expense.partnershipId,
      amount: expense.amount,
      currency: expense.currency,
      ratio: expense.ratio,
      category: expense.category,
      memo: expense.memo,
    );

    await supabase.from(_table).update({
      'paid_by': expense.paidBy,
      'date': expense.date.toIso8601String().substring(0, 10),
      'encrypted_data': encryptedData,
    }).eq('id', expense.id);
  }

  Future<void> deleteExpense(String expenseId) async {
    await supabase.from(_table).delete().eq('id', expenseId);
  }

  Future<void> deleteUserExpenses(
    String partnershipId,
    String userId,
  ) async {
    await supabase
        .from(_table)
        .delete()
        .eq('partnership_id', partnershipId)
        .eq('paid_by', userId);
  }

  Future<void> deleteAllExpenses(String partnershipId) async {
    await supabase
        .from(_table)
        .delete()
        .eq('partnership_id', partnershipId);
  }

  /// Migrate expenses to a new partnership, re-encrypting with the new AAD.
  /// If no encryption key is available, skips migration entirely — plain
  /// migration (changing partnership_id without re-encrypting) would
  /// permanently corrupt the data due to AAD mismatch.
  Future<void> migrateUserExpenses(
    String fromPartnershipId,
    String toPartnershipId,
    String userId,
  ) async {
    final key = encryptionKey;
    if (key == null) {
      // No key — skip migration. Plain migration would corrupt AAD-bound
      // ciphertext. The caller must restore the key first.
      return;
    }

    // Read all user's expenses from the old partnership
    final rows = await supabase
        .from(_table)
        .select()
        .eq('partnership_id', fromPartnershipId)
        .eq('paid_by', userId);

    // Re-encrypt each expense with the new partnership ID in AAD
    for (final row in rows) {
      final expenseId = row['id'] as String;
      final encryptedData = row['encrypted_data'] as String?;
      if (encryptedData == null) continue;

      final fields = await EncryptionService.decryptExpenseFields(
        key: key,
        expenseId: expenseId,
        partnershipId: fromPartnershipId,
        encryptedData: encryptedData,
      );

      final newEncryptedData = await EncryptionService.encryptExpenseFields(
        key: key,
        expenseId: expenseId,
        partnershipId: toPartnershipId,
        amount: (fields['amount'] as num).toInt(),
        currency: fields['currency'] as String? ?? 'JPY',
        ratio: (fields['ratio'] as num).toDouble(),
        category: fields['category'] as String? ?? '',
        memo: fields['memo'] as String? ?? '',
      );

      await supabase.from(_table).update({
        'partnership_id': toPartnershipId,
        'encrypted_data': newEncryptedData,
      }).eq('id', expenseId);
    }
  }

  /// Re-encrypt all of a user's expenses with a new key (same partnership).
  /// Used after ECDH key exchange when the joiner receives the initiator's key.
  Future<void> reencryptUserExpenses({
    required String partnershipId,
    required String userId,
    required Uint8List oldKey,
    required Uint8List newKey,
  }) async {
    final rows = await supabase
        .from(_table)
        .select()
        .eq('partnership_id', partnershipId)
        .eq('paid_by', userId);

    for (final row in rows) {
      final expenseId = row['id'] as String;
      final encryptedData = row['encrypted_data'] as String?;
      if (encryptedData == null) continue;

      final fields = await EncryptionService.decryptExpenseFields(
        key: oldKey,
        expenseId: expenseId,
        partnershipId: partnershipId,
        encryptedData: encryptedData,
      );

      final newEncryptedData = await EncryptionService.encryptExpenseFields(
        key: newKey,
        expenseId: expenseId,
        partnershipId: partnershipId,
        amount: (fields['amount'] as num).toInt(),
        currency: fields['currency'] as String? ?? 'JPY',
        ratio: (fields['ratio'] as num).toDouble(),
        category: fields['category'] as String? ?? '',
        memo: fields['memo'] as String? ?? '',
      );

      await supabase.from(_table).update({
        'encrypted_data': newEncryptedData,
      }).eq('id', expenseId);
    }
  }

  Future<int> getBalanceSummary(
    String partnershipId,
    String userId,
  ) async {
    if (encryptionKey == null) return 0;
    final data = await supabase
        .from(_table)
        .select('id, paid_by, encrypted_data')
        .eq('partnership_id', partnershipId);

    final decryptedRows = await Future.wait(
      data.map((row) => _decryptToMap(row, partnershipId)),
    );
    return calculateBalance(decryptedRows, userId);
  }

  Future<List<Map<String, dynamic>>> getMonthlyExpenseRows(
    String partnershipId, {
    required DateTime month,
  }) async {
    if (encryptionKey == null) return [];
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final data = await supabase
        .from(_table)
        .select('id, paid_by, encrypted_data')
        .eq('partnership_id', partnershipId)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));

    return Future.wait(
      data.map((row) => _decryptToMap(row, partnershipId)),
    );
  }

  Future<MonthlySummary> getMonthlySummary(
    String partnershipId,
    String userId, {
    required DateTime month,
  }) async {
    final rows = await getMonthlyExpenseRows(partnershipId, month: month);
    return calculateMonthlySummary(rows, userId);
  }

  Future<List<Expense>> getExpensesByMonth(
    String partnershipId, {
    required DateTime month,
    String? category,
  }) async {
    if (encryptionKey == null) return [];
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    final data = await supabase
        .from(_table)
        .select()
        .eq('partnership_id', partnershipId)
        .gte('date', startStr)
        .lt('date', endStr)
        .order('date', ascending: false)
        .order('created_at', ascending: false);

    final expenses = await Future.wait(
      data.map((e) => _decryptRow(e, partnershipId)),
    );

    if (category != null) {
      return expenses.where((e) => e.category == category).toList();
    }
    return expenses;
  }

  Future<List<CategoryAmount>> getCategoryBreakdown(
    String partnershipId,
    String userId, {
    required DateTime month,
  }) async {
    if (encryptionKey == null) return [];
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final data = await supabase
        .from(_table)
        .select('id, paid_by, encrypted_data')
        .eq('partnership_id', partnershipId)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));

    final decryptedRows = await Future.wait(
      data.map((row) => _decryptToMap(row, partnershipId)),
    );
    return calculateCategoryBreakdown(decryptedRows, userId);
  }

  // --- Helpers ---

  Future<Expense> _decryptRow(
    Map<String, dynamic> row,
    String partnershipId,
  ) async {
    final key = encryptionKey;
    if (key == null) throw StateError('Encryption key not available');

    final expenseId = row['id'] as String;
    final fields = await EncryptionService.decryptExpenseFields(
      key: key,
      expenseId: expenseId,
      partnershipId: partnershipId,
      encryptedData: row['encrypted_data'] as String,
    );

    return Expense(
      id: expenseId,
      partnershipId: partnershipId,
      paidBy: row['paid_by'] as String,
      amount: (fields['amount'] as num).toInt(),
      currency: fields['currency'] as String? ?? 'JPY',
      ratio: (fields['ratio'] as num).toDouble(),
      date: DateTime.parse(row['date'] as String),
      category: fields['category'] as String? ?? '',
      memo: fields['memo'] as String? ?? '',
      createdAt: DateTime.parse(row['created_at'] as String),
    );
  }

  Future<Map<String, dynamic>> _decryptToMap(
    Map<String, dynamic> row,
    String partnershipId,
  ) async {
    final key = encryptionKey;
    if (key == null) throw StateError('Encryption key not available');

    final expenseId = row['id'] as String;
    final fields = await EncryptionService.decryptExpenseFields(
      key: key,
      expenseId: expenseId,
      partnershipId: partnershipId,
      encryptedData: row['encrypted_data'] as String,
    );

    return {
      'paid_by': row['paid_by'],
      'amount': fields['amount'],
      'ratio': fields['ratio'],
      'category': fields['category'],
    };
  }
}
