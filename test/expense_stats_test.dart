import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/utils/expense_stats.dart';

const userA = 'user-a';
const userB = 'user-b';

Map<String, dynamic> row({
  required String paidBy,
  required int amount,
  String category = '',
  double ratio = 0.5,
}) {
  return {
    'paid_by': paidBy,
    'amount': amount,
    'category': category,
    'ratio': ratio,
  };
}

void main() {
  group('calculateMonthlySummary', () {
    test('empty list returns all zeros', () {
      final s = calculateMonthlySummary([], userA);
      expect(s.total, 0);
      expect(s.myTotal, 0);
      expect(s.partnerTotal, 0);
    });

    test('single payment by me', () {
      final s = calculateMonthlySummary(
        [row(paidBy: userA, amount: 1000)],
        userA,
      );
      expect(s.total, 1000);
      expect(s.myTotal, 1000);
      expect(s.partnerTotal, 0);
    });

    test('single payment by partner', () {
      final s = calculateMonthlySummary(
        [row(paidBy: userB, amount: 2000)],
        userA,
      );
      expect(s.total, 2000);
      expect(s.myTotal, 0);
      expect(s.partnerTotal, 2000);
    });

    test('mixed payments', () {
      final s = calculateMonthlySummary(
        [
          row(paidBy: userA, amount: 3000),
          row(paidBy: userB, amount: 5000),
          row(paidBy: userA, amount: 2000),
        ],
        userA,
      );
      expect(s.total, 10000);
      expect(s.myTotal, 5000);
      expect(s.partnerTotal, 5000);
    });

    test('total equals myTotal + partnerTotal', () {
      final rows = [
        row(paidBy: userA, amount: 1234),
        row(paidBy: userB, amount: 5678),
        row(paidBy: userA, amount: 999),
      ];
      final s = calculateMonthlySummary(rows, userA);
      expect(s.total, s.myTotal + s.partnerTotal);
    });
  });

  group('calculateCategoryBreakdown', () {
    test('empty list returns empty', () {
      expect(calculateCategoryBreakdown([]), isEmpty);
    });

    test('single category', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 1000, category: '食費'),
      ]);
      expect(result.length, 1);
      expect(result[0].category, '食費');
      expect(result[0].amount, 1000);
    });

    test('groups by category and sums', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 1000, category: '食費'),
        row(paidBy: userB, amount: 2000, category: '日用品'),
        row(paidBy: userA, amount: 500, category: '食費'),
      ]);
      expect(result.length, 2);
      // Sorted by amount descending
      expect(result[0].category, '日用品');
      expect(result[0].amount, 2000);
      expect(result[1].category, '食費');
      expect(result[1].amount, 1500);
    });

    test('empty category becomes その他', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 500, category: ''),
        row(paidBy: userA, amount: 300),
      ]);
      expect(result.length, 1);
      expect(result[0].category, 'その他');
      expect(result[0].amount, 800);
    });

    test('sorted descending by amount', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 100, category: 'C'),
        row(paidBy: userA, amount: 300, category: 'A'),
        row(paidBy: userA, amount: 200, category: 'B'),
      ]);
      expect(result.map((e) => e.category).toList(), ['A', 'B', 'C']);
    });

    test('many categories from both users', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 5000, category: '食費'),
        row(paidBy: userB, amount: 8000, category: '食費'),
        row(paidBy: userA, amount: 12000, category: '光熱費'),
        row(paidBy: userB, amount: 3000, category: '娯楽'),
        row(paidBy: userA, amount: 1000, category: '娯楽'),
      ]);
      expect(result.length, 3);
      // 食費: 13000, 光熱費: 12000, 娯楽: 4000
      expect(result[0].category, '食費');
      expect(result[0].amount, 13000);
      expect(result[1].category, '光熱費');
      expect(result[1].amount, 12000);
      expect(result[2].category, '娯楽');
      expect(result[2].amount, 4000);
    });

    test('total of all categories equals sum of all amounts', () {
      final rows = [
        row(paidBy: userA, amount: 1234, category: 'A'),
        row(paidBy: userB, amount: 5678, category: 'B'),
        row(paidBy: userA, amount: 999, category: 'A'),
      ];
      final result = calculateCategoryBreakdown(rows);
      final total = result.fold<int>(0, (sum, e) => sum + e.amount);
      expect(total, 1234 + 5678 + 999);
    });
  });

  group('calculateCategoryBreakdown with userId (burden)', () {
    test('50/50 split: my burden is half regardless of payer', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 1000, category: '食費', ratio: 0.5),
        row(paidBy: userB, amount: 2000, category: '食費', ratio: 0.5),
      ], userA);
      expect(result.length, 1);
      // userA paid 1000 * 0.5 = 500, userB paid 2000 so userA bears 2000 * 0.5 = 1000
      expect(result[0].amount, 1500);
    });

    test('100% ratio (treat): payer bears all', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 3000, category: '食費', ratio: 1.0),
      ], userA);
      // userA's burden = 3000 * 1.0 = 3000
      expect(result[0].amount, 3000);
    });

    test('100% ratio: non-payer bears nothing', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 3000, category: '食費', ratio: 1.0),
      ], userB);
      // userB's burden = 3000 * (1 - 1.0) = 0 → filtered out
      expect(result, isEmpty);
    });

    test('0% ratio (advance): payer bears nothing', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 4000, category: '日用品', ratio: 0.0),
      ], userA);
      // userA's burden = 4000 * 0.0 = 0 → filtered out
      expect(result, isEmpty);
    });

    test('0% ratio: non-payer bears all', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 4000, category: '日用品', ratio: 0.0),
      ], userB);
      // userB's burden = 4000 * (1 - 0.0) = 4000
      expect(result[0].amount, 4000);
    });

    test('mixed ratios across categories', () {
      final result = calculateCategoryBreakdown([
        row(paidBy: userA, amount: 1000, category: '食費', ratio: 0.5),
        row(paidBy: userB, amount: 2000, category: '日用品', ratio: 0.75),
        row(paidBy: userA, amount: 4000, category: '食費', ratio: 0.25),
      ], userA);
      // 食費: 1000*0.5 + 4000*0.25 = 500 + 1000 = 1500
      // 日用品: 2000*(1-0.75) = 500
      expect(result.length, 2);
      expect(result[0].category, '食費');
      expect(result[0].amount, 1500);
      expect(result[1].category, '日用品');
      expect(result[1].amount, 500);
    });
  });
}
