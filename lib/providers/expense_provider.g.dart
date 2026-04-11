// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$expenseRepositoryHash() => r'e33dbce465ddd2592a69b3b85e5c8cacaa8da411';

/// See also [expenseRepository].
@ProviderFor(expenseRepository)
final expenseRepositoryProvider =
    AutoDisposeProvider<ExpenseRepository>.internal(
      expenseRepository,
      name: r'expenseRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$expenseRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExpenseRepositoryRef = AutoDisposeProviderRef<ExpenseRepository>;
String _$recentExpensesHash() => r'e75d864f3fc6ba16a625a991b8e6d878a45c87e9';

/// See also [recentExpenses].
@ProviderFor(recentExpenses)
final recentExpensesProvider =
    AutoDisposeFutureProvider<List<Expense>>.internal(
      recentExpenses,
      name: r'recentExpensesProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recentExpensesHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef RecentExpensesRef = AutoDisposeFutureProviderRef<List<Expense>>;
String _$expenseDetailHash() => r'b9f134e630a5a38fbb6f4184637717e0b306b597';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [expenseDetail].
@ProviderFor(expenseDetail)
const expenseDetailProvider = ExpenseDetailFamily();

/// See also [expenseDetail].
class ExpenseDetailFamily extends Family<AsyncValue<Expense?>> {
  /// See also [expenseDetail].
  const ExpenseDetailFamily();

  /// See also [expenseDetail].
  ExpenseDetailProvider call(String expenseId) {
    return ExpenseDetailProvider(expenseId);
  }

  @override
  ExpenseDetailProvider getProviderOverride(
    covariant ExpenseDetailProvider provider,
  ) {
    return call(provider.expenseId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'expenseDetailProvider';
}

/// See also [expenseDetail].
class ExpenseDetailProvider extends AutoDisposeFutureProvider<Expense?> {
  /// See also [expenseDetail].
  ExpenseDetailProvider(String expenseId)
    : this._internal(
        (ref) => expenseDetail(ref as ExpenseDetailRef, expenseId),
        from: expenseDetailProvider,
        name: r'expenseDetailProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$expenseDetailHash,
        dependencies: ExpenseDetailFamily._dependencies,
        allTransitiveDependencies:
            ExpenseDetailFamily._allTransitiveDependencies,
        expenseId: expenseId,
      );

  ExpenseDetailProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.expenseId,
  }) : super.internal();

  final String expenseId;

  @override
  Override overrideWith(
    FutureOr<Expense?> Function(ExpenseDetailRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: ExpenseDetailProvider._internal(
        (ref) => create(ref as ExpenseDetailRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        expenseId: expenseId,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<Expense?> createElement() {
    return _ExpenseDetailProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is ExpenseDetailProvider && other.expenseId == expenseId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, expenseId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin ExpenseDetailRef on AutoDisposeFutureProviderRef<Expense?> {
  /// The parameter `expenseId` of this provider.
  String get expenseId;
}

class _ExpenseDetailProviderElement
    extends AutoDisposeFutureProviderElement<Expense?>
    with ExpenseDetailRef {
  _ExpenseDetailProviderElement(super.provider);

  @override
  String get expenseId => (origin as ExpenseDetailProvider).expenseId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
