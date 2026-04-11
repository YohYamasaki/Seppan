import 'package:freezed_annotation/freezed_annotation.dart';

part 'expense.freezed.dart';
part 'expense.g.dart';

@freezed
abstract class Expense with _$Expense {
  const factory Expense({
    required String id,
    required String partnershipId,
    required String paidBy,
    required int amount,
    @Default('JPY') String currency,
    @Default(0.5) double ratio,
    required DateTime date,
    @Default('') String category,
    @Default('') String memo,
    required DateTime createdAt,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}
