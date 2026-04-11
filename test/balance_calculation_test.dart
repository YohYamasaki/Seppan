import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/utils/balance.dart';

Map<String, dynamic> expense({
  required String paidBy,
  required int amount,
  double ratio = 0.5,
}) {
  return {'paid_by': paidBy, 'amount': amount, 'ratio': ratio};
}

const userA = 'user-a';
const userB = 'user-b';

void main() {
  group('50/50 split (ratio = 0.5)', () {
    test('single payment by me - partner owes half', () {
      final expenses = [expense(paidBy: userA, amount: 1000)];
      expect(calculateBalance(expenses, userA), 500);
    });

    test('single payment by partner - I owe half', () {
      final expenses = [expense(paidBy: userB, amount: 1000)];
      expect(calculateBalance(expenses, userA), -500);
    });

    test('equal payments cancel out', () {
      final expenses = [
        expense(paidBy: userA, amount: 1000),
        expense(paidBy: userB, amount: 1000),
      ];
      expect(calculateBalance(expenses, userA), 0);
    });

    test('multiple payments by me', () {
      final expenses = [
        expense(paidBy: userA, amount: 1000),
        expense(paidBy: userA, amount: 2000),
      ];
      // (1000 * 0.5) + (2000 * 0.5) = 1500
      expect(calculateBalance(expenses, userA), 1500);
    });

    test('multiple payments by partner', () {
      final expenses = [
        expense(paidBy: userB, amount: 1000),
        expense(paidBy: userB, amount: 2000),
      ];
      // -(1000 * 0.5) + -(2000 * 0.5) = -1500
      expect(calculateBalance(expenses, userA), -1500);
    });

    test('mixed payments - I paid more', () {
      final expenses = [
        expense(paidBy: userA, amount: 3000),
        expense(paidBy: userB, amount: 1000),
      ];
      // (3000 * 0.5) - (1000 * 0.5) = 1500 - 500 = 1000
      expect(calculateBalance(expenses, userA), 1000);
    });

    test('mixed payments - partner paid more', () {
      final expenses = [
        expense(paidBy: userA, amount: 1000),
        expense(paidBy: userB, amount: 3000),
      ];
      // (1000 * 0.5) - (3000 * 0.5) = 500 - 1500 = -1000
      expect(calculateBalance(expenses, userA), -1000);
    });
  });

  group('Symmetry - balance is zero-sum between two users', () {
    test('50/50 split is symmetric', () {
      final expenses = [
        expense(paidBy: userA, amount: 1000),
        expense(paidBy: userB, amount: 600),
      ];
      final balanceA = calculateBalance(expenses, userA);
      final balanceB = calculateBalance(expenses, userB);
      expect(balanceA + balanceB, 0);
    });

    test('75/25 split is symmetric', () {
      final expenses = [
        expense(paidBy: userA, amount: 1000, ratio: 0.75),
      ];
      final balanceA = calculateBalance(expenses, userA);
      final balanceB = calculateBalance(expenses, userB);
      expect(balanceA + balanceB, 0);
    });

    test('complex mixed scenario is symmetric', () {
      final expenses = [
        expense(paidBy: userA, amount: 3000, ratio: 0.5),
        expense(paidBy: userB, amount: 2000, ratio: 0.75),
        expense(paidBy: userA, amount: 500, ratio: 0.25),
        expense(paidBy: userB, amount: 1200, ratio: 1.0),
      ];
      final balanceA = calculateBalance(expenses, userA);
      final balanceB = calculateBalance(expenses, userB);
      expect(balanceA + balanceB, 0);
    });
  });

  group('100% payer burden (ratio = 1.0) - treat/おごり', () {
    test('I pay and bear 100% - partner owes nothing', () {
      final expenses = [expense(paidBy: userA, amount: 1000, ratio: 1.0)];
      // 1000 * (1 - 1.0) = 0
      expect(calculateBalance(expenses, userA), 0);
    });

    test('partner pays and bears 100% - I owe nothing', () {
      final expenses = [expense(paidBy: userB, amount: 1000, ratio: 1.0)];
      // Partner treats: balance -= 1000 * (1 - 1.0) = 0
      expect(calculateBalance(expenses, userA), 0);
    });
  });

  group('0% payer burden (ratio = 0.0) - advance/立て替え', () {
    test('I pay but bear 0% - partner owes full amount', () {
      final expenses = [expense(paidBy: userA, amount: 1000, ratio: 0.0)];
      // 1000 * (1 - 0.0) = 1000
      expect(calculateBalance(expenses, userA), 1000);
    });

    test('partner pays but bears 0% - I owe full amount', () {
      final expenses = [expense(paidBy: userB, amount: 1000, ratio: 0.0)];
      // Partner advances: balance -= 1000 * (1 - 0.0) = -1000
      expect(calculateBalance(expenses, userA), -1000);
    });
  });

  group('75/25 split (ratio = 0.75)', () {
    test('I pay, I bear 75% - partner owes 25%', () {
      final expenses = [expense(paidBy: userA, amount: 1000, ratio: 0.75)];
      // 1000 * (1 - 0.75) = 250
      expect(calculateBalance(expenses, userA), 250);
    });

    test('partner pays, payer bears 75% - I owe 25%', () {
      final expenses = [expense(paidBy: userB, amount: 1000, ratio: 0.75)];
      // balance -= 1000 * (1 - 0.75) = -250
      expect(calculateBalance(expenses, userA), -250);
    });
  });

  group('25/75 split (ratio = 0.25)', () {
    test('I pay, I bear 25% - partner owes 75%', () {
      final expenses = [expense(paidBy: userA, amount: 1000, ratio: 0.25)];
      // 1000 * (1 - 0.25) = 750
      expect(calculateBalance(expenses, userA), 750);
    });

    test('partner pays, payer bears 25% - I owe 75%', () {
      final expenses = [expense(paidBy: userB, amount: 1000, ratio: 0.25)];
      // balance -= 1000 * (1 - 0.25) = -750
      expect(calculateBalance(expenses, userA), -750);
    });
  });

  group('Edge cases', () {
    test('no expenses - balance is zero', () {
      expect(calculateBalance([], userA), 0);
    });

    test('zero amount expense', () {
      final expenses = [expense(paidBy: userA, amount: 0)];
      expect(calculateBalance(expenses, userA), 0);
    });

    test('very large amount', () {
      final expenses = [expense(paidBy: userA, amount: 999999)];
      // 999999 * 0.5 = 499999.5 → rounds to 500000
      expect(calculateBalance(expenses, userA), 500000);
    });

    test('1 yen - smallest unit', () {
      final expenses = [expense(paidBy: userA, amount: 1)];
      // 1 * 0.5 = 0.5 → rounds to 1
      expect(calculateBalance(expenses, userA), 1);
    });

    test('odd amount 50/50 - rounding', () {
      final expenses = [expense(paidBy: userA, amount: 3)];
      // 3 * 0.5 = 1.5 → rounds to 2
      expect(calculateBalance(expenses, userA), 2);
    });

    test('many small expenses accumulate correctly', () {
      final expenses = List.generate(
        100,
        (_) => expense(paidBy: userA, amount: 100),
      );
      // 100 * (100 * 0.5) = 5000
      expect(calculateBalance(expenses, userA), 5000);
    });
  });

  group('Rounding behavior with non-50/50 splits', () {
    test('333 yen at 75/25', () {
      final expenses = [expense(paidBy: userA, amount: 333, ratio: 0.75)];
      // 333 * 0.25 = 83.25 → rounds to 83
      expect(calculateBalance(expenses, userA), 83);
    });

    test('1 yen at 75/25', () {
      final expenses = [expense(paidBy: userA, amount: 1, ratio: 0.75)];
      // 1 * 0.25 = 0.25 → rounds to 0
      expect(calculateBalance(expenses, userA), 0);
    });

    test('accumulated rounding across many expenses', () {
      // 10 expenses of 33 yen at 75/25 split
      final expenses = List.generate(
        10,
        (_) => expense(paidBy: userA, amount: 33, ratio: 0.75),
      );
      // Each: 33 * 0.25 = 8.25, total = 82.5 → rounds to 83
      // Note: rounding happens once at the end, not per expense
      expect(calculateBalance(expenses, userA), 83);
    });
  });

  group('Real-world scenario', () {
    test('typical month of shared expenses', () {
      final expenses = [
        // Groceries - user A pays, 50/50
        expense(paidBy: userA, amount: 5000, ratio: 0.5),
        // Dinner out - user B pays, 50/50
        expense(paidBy: userB, amount: 8000, ratio: 0.5),
        // Electricity - user A pays, 50/50
        expense(paidBy: userA, amount: 12000, ratio: 0.5),
        // User A's personal item - 100% their burden
        expense(paidBy: userA, amount: 3000, ratio: 1.0),
        // Gift from user B - 100% their treat
        expense(paidBy: userB, amount: 2000, ratio: 1.0),
      ];

      final balanceA = calculateBalance(expenses, userA);
      // A paid: 5000*0.5 + 12000*0.5 + 3000*0 = 2500 + 6000 + 0 = 8500
      // B paid: -(8000*0.5) + -(2000*0) = -4000 + 0 = -4000
      // Net: 8500 - 4000 = 4500
      expect(balanceA, 4500);

      final balanceB = calculateBalance(expenses, userB);
      expect(balanceA + balanceB, 0);
    });

    test('all expenses by one person, all 50/50', () {
      final expenses = [
        expense(paidBy: userA, amount: 1000),
        expense(paidBy: userA, amount: 2000),
        expense(paidBy: userA, amount: 3000),
      ];
      // Total paid by A = 6000, partner owes 50% = 3000
      expect(calculateBalance(expenses, userA), 3000);
      expect(calculateBalance(expenses, userB), -3000);
    });
  });

  group('Fixed: ratio semantics now correct for both payers', () {
    test('at 50/50 both formulas agree', () {
      final expenses = [expense(paidBy: userB, amount: 1000, ratio: 0.5)];
      expect(calculateBalance(expenses, userA), -500);
    });

    test('partner treats (ratio=1.0) - I owe nothing', () {
      final expenses = [expense(paidBy: userB, amount: 1000, ratio: 1.0)];
      expect(calculateBalance(expenses, userA), 0);
    });

    test('partner advances (ratio=0.0) - I owe full amount', () {
      final expenses = [expense(paidBy: userB, amount: 1000, ratio: 0.0)];
      expect(calculateBalance(expenses, userA), -1000);
    });
  });
}
