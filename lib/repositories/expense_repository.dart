import '../config/supabase.dart';
import '../models/expense.dart';
import '../utils/balance.dart';
import '../utils/expense_stats.dart';

class ExpenseRepository {
  static const _table = 'expenses';

  Future<void> addExpense(Expense expense) async {
    await supabase.from(_table).insert(expense.toJson()..remove('id'));
  }

  Future<List<Expense>> getExpenses(
    String partnershipId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final data = await supabase
        .from(_table)
        .select()
        .eq('partnership_id', partnershipId)
        .order('date', ascending: false)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return data.map((e) => Expense.fromJson(e)).toList();
  }

  Future<Expense?> getExpense(String expenseId) async {
    final data = await supabase
        .from(_table)
        .select()
        .eq('id', expenseId)
        .maybeSingle();
    if (data == null) return null;
    return Expense.fromJson(data);
  }

  Future<void> updateExpense(Expense expense) async {
    await supabase
        .from(_table)
        .update(expense.toJson()..remove('id')..remove('created_at'))
        .eq('id', expense.id);
  }

  Future<void> deleteExpense(String expenseId) async {
    await supabase.from(_table).delete().eq('id', expenseId);
  }

  /// Deletes all expenses paid by [userId] in the given partnership.
  /// Used before account deletion to clean up the user's own expenses
  /// while preserving the partner's expenses.
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

  /// Moves all expenses from one partnership to another.
  /// Used when a user who already has expenses on a pending partnership
  /// joins another user's partnership.
  Future<void> migrateExpenses(
    String fromPartnershipId,
    String toPartnershipId,
  ) async {
    await supabase
        .from(_table)
        .update({'partnership_id': toPartnershipId})
        .eq('partnership_id', fromPartnershipId);
  }

  /// Moves only the expenses paid by [userId] to another partnership.
  /// Used when unlinking so the user keeps their own payment history.
  Future<void> migrateUserExpenses(
    String fromPartnershipId,
    String toPartnershipId,
    String userId,
  ) async {
    await supabase
        .from(_table)
        .update({'partnership_id': toPartnershipId})
        .eq('partnership_id', fromPartnershipId)
        .eq('paid_by', userId);
  }

  /// Returns the net balance for [userId] within the partnership.
  /// Positive = partner owes you. Negative = you owe partner.
  Future<int> getBalanceSummary(
    String partnershipId,
    String userId,
  ) async {
    final data = await supabase
        .from(_table)
        .select('paid_by, amount, ratio')
        .eq('partnership_id', partnershipId);

    return calculateBalance(data, userId);
  }

  /// Returns raw expense rows for [partnershipId] within the given month.
  Future<List<Map<String, dynamic>>> getMonthlyExpenseRows(
    String partnershipId, {
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    return supabase
        .from(_table)
        .select('paid_by, amount, category')
        .eq('partnership_id', partnershipId)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));
  }

  /// Monthly summary (total, my total, partner total).
  Future<MonthlySummary> getMonthlySummary(
    String partnershipId,
    String userId, {
    required DateTime month,
  }) async {
    final rows = await getMonthlyExpenseRows(partnershipId, month: month);
    return calculateMonthlySummary(rows, userId);
  }

  /// Returns full [Expense] objects for a given month, optionally filtered by category.
  Future<List<Expense>> getExpensesByMonth(
    String partnershipId, {
    required DateTime month,
    String? category,
  }) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final startStr = start.toIso8601String().substring(0, 10);
    final endStr = end.toIso8601String().substring(0, 10);

    var query = supabase
        .from(_table)
        .select()
        .eq('partnership_id', partnershipId)
        .gte('date', startStr)
        .lt('date', endStr);

    if (category != null) {
      query = query.eq('category', category);
    }

    final data = await query
        .order('date', ascending: false)
        .order('created_at', ascending: false);
    return data.map((e) => Expense.fromJson(e)).toList();
  }

  /// Category breakdown for the given month.
  /// Calculates [userId]'s burden per category based on payer and ratio.
  Future<List<CategoryAmount>> getCategoryBreakdown(
    String partnershipId,
    String userId, {
    required DateTime month,
  }) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);
    final rows = await supabase
        .from(_table)
        .select('paid_by, amount, ratio, category')
        .eq('partnership_id', partnershipId)
        .gte('date', start.toIso8601String().substring(0, 10))
        .lt('date', end.toIso8601String().substring(0, 10));
    return calculateCategoryBreakdown(rows, userId);
  }
}
