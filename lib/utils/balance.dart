/// Calculates net balance for [userId] from a list of expense rows.
///
/// Each row must contain 'paid_by' (String), 'amount' (num), 'ratio' (num).
/// ratio = the payer's burden share (0.0 to 1.0).
///
/// Positive = partner owes you. Negative = you owe partner.
int calculateBalance(List<Map<String, dynamic>> rows, String userId) {
  var balance = 0.0;
  for (final row in rows) {
    final amount = (row['amount'] as num).toDouble();
    final ratio = (row['ratio'] as num).toDouble();
    final paidBy = row['paid_by'] as String;

    if (paidBy == userId) {
      // I paid, partner owes me their share
      balance += amount * (1 - ratio);
    } else {
      // Partner paid, I owe my share (= 1 - payer's burden)
      balance -= amount * (1 - ratio);
    }
  }
  return balance.round();
}
