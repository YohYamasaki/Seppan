// Pure functions for computing expense statistics from raw data.

/// Monthly summary: total, my payments, partner's payments.
class MonthlySummary {
  const MonthlySummary({
    required this.total,
    required this.myTotal,
    required this.partnerTotal,
  });

  final int total;
  final int myTotal;
  final int partnerTotal;
}

/// Calculates monthly payment totals for [userId].
MonthlySummary calculateMonthlySummary(
  List<Map<String, dynamic>> rows,
  String userId,
) {
  var myTotal = 0.0;
  var partnerTotal = 0.0;
  for (final row in rows) {
    final amount = (row['amount'] as num).toDouble();
    final paidBy = row['paid_by'] as String;
    if (paidBy == userId) {
      myTotal += amount;
    } else {
      partnerTotal += amount;
    }
  }
  final total = myTotal + partnerTotal;
  return MonthlySummary(
    total: total.round(),
    myTotal: myTotal.round(),
    partnerTotal: partnerTotal.round(),
  );
}

/// Category breakdown entry.
class CategoryAmount {
  const CategoryAmount({required this.category, required this.amount});

  final String category;
  final int amount;
}

/// Groups expenses by category and returns totals, sorted descending.
///
/// When [userId] is provided, calculates each user's **burden** per category
/// based on the payer and ratio (not just who paid, but how much each person
/// actually owes). Without [userId], sums raw amounts.
List<CategoryAmount> calculateCategoryBreakdown(
  List<Map<String, dynamic>> rows, [
  String? userId,
]) {
  final map = <String, double>{};
  for (final row in rows) {
    final amount = (row['amount'] as num).toDouble();
    final category = (row['category'] as String?) ?? '';
    final key = category.isEmpty ? 'その他' : category;

    double burden;
    if (userId != null) {
      final paidBy = row['paid_by'] as String;
      final ratio = (row['ratio'] as num).toDouble();
      // payer bears amount * ratio, the other bears amount * (1 - ratio)
      burden = (paidBy == userId) ? amount * ratio : amount * (1 - ratio);
    } else {
      burden = amount;
    }
    map[key] = (map[key] ?? 0) + burden;
  }
  final entries = map.entries.where((e) => e.value.round() > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries
      .map((e) => CategoryAmount(category: e.key, amount: e.value.round()))
      .toList();
}
