// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Expense _$ExpenseFromJson(Map<String, dynamic> json) => _Expense(
  id: json['id'] as String,
  partnershipId: json['partnership_id'] as String,
  paidBy: json['paid_by'] as String,
  amount: (json['amount'] as num).toInt(),
  currency: json['currency'] as String? ?? 'JPY',
  ratio: (json['ratio'] as num?)?.toDouble() ?? 0.5,
  date: DateTime.parse(json['date'] as String),
  category: json['category'] as String? ?? '',
  memo: json['memo'] as String? ?? '',
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$ExpenseToJson(_Expense instance) => <String, dynamic>{
  'id': instance.id,
  'partnership_id': instance.partnershipId,
  'paid_by': instance.paidBy,
  'amount': instance.amount,
  'currency': instance.currency,
  'ratio': instance.ratio,
  'date': instance.date.toIso8601String(),
  'category': instance.category,
  'memo': instance.memo,
  'created_at': instance.createdAt.toIso8601String(),
};
