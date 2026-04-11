// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'balance_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$balanceSummaryHash() => r'e7ac98f594494c62b94c37224e5fdafc1dca467f';

/// Net balance for current user.
/// Positive = partner owes you. Negative = you owe partner.
///
/// Copied from [balanceSummary].
@ProviderFor(balanceSummary)
final balanceSummaryProvider = AutoDisposeFutureProvider<int>.internal(
  balanceSummary,
  name: r'balanceSummaryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$balanceSummaryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BalanceSummaryRef = AutoDisposeFutureProviderRef<int>;
String _$categoryBreakdownHash() => r'531d98e82c4a25e6fb32765efe5f4c8bd2022c97';

/// Category breakdown for current month (current user's burden).
///
/// Copied from [categoryBreakdown].
@ProviderFor(categoryBreakdown)
final categoryBreakdownProvider =
    AutoDisposeFutureProvider<List<CategoryAmount>>.internal(
      categoryBreakdown,
      name: r'categoryBreakdownProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$categoryBreakdownHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CategoryBreakdownRef =
    AutoDisposeFutureProviderRef<List<CategoryAmount>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
