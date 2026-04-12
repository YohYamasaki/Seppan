// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'partnership_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$partnershipRepositoryHash() =>
    r'5a25f1ce580793ec599fd57c32ce9890c426c3b1';

/// See also [partnershipRepository].
@ProviderFor(partnershipRepository)
final partnershipRepositoryProvider =
    AutoDisposeProvider<PartnershipRepository>.internal(
      partnershipRepository,
      name: r'partnershipRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$partnershipRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PartnershipRepositoryRef =
    AutoDisposeProviderRef<PartnershipRepository>;
String _$activePartnershipHash() => r'506ceb3f1279ba5a28c616e19a366fe84b855559';

/// See also [activePartnership].
@ProviderFor(activePartnership)
final activePartnershipProvider =
    AutoDisposeFutureProvider<Partnership?>.internal(
      activePartnership,
      name: r'activePartnershipProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activePartnershipHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ActivePartnershipRef = AutoDisposeFutureProviderRef<Partnership?>;
String _$currentPartnershipHash() =>
    r'5c1614aad809453088a512fb41ea7b0a9d256c58';

/// Current partnership: active first, falls back to pending.
/// If neither exists, creates a new pending partnership and migrates
/// the user's expenses from any archived partnership (lazy migration
/// for the partner who was unlinked by the other side).
///
/// Copied from [currentPartnership].
@ProviderFor(currentPartnership)
final currentPartnershipProvider =
    AutoDisposeFutureProvider<Partnership?>.internal(
      currentPartnership,
      name: r'currentPartnershipProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$currentPartnershipHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CurrentPartnershipRef = AutoDisposeFutureProviderRef<Partnership?>;
String _$partnerProfileHash() => r'f04d6234b207a4eba69026793957499a869dac3b';

/// See also [partnerProfile].
@ProviderFor(partnerProfile)
final partnerProfileProvider = AutoDisposeFutureProvider<Profile?>.internal(
  partnerProfile,
  name: r'partnerProfileProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$partnerProfileHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PartnerProfileRef = AutoDisposeFutureProviderRef<Profile?>;
String _$partnershipStreamHash() => r'59f1f3995e18319d5979d807aaefac9d5f6c2538';

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

/// See also [partnershipStream].
@ProviderFor(partnershipStream)
const partnershipStreamProvider = PartnershipStreamFamily();

/// See also [partnershipStream].
class PartnershipStreamFamily extends Family<AsyncValue<Partnership>> {
  /// See also [partnershipStream].
  const PartnershipStreamFamily();

  /// See also [partnershipStream].
  PartnershipStreamProvider call(String partnershipId) {
    return PartnershipStreamProvider(partnershipId);
  }

  @override
  PartnershipStreamProvider getProviderOverride(
    covariant PartnershipStreamProvider provider,
  ) {
    return call(provider.partnershipId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'partnershipStreamProvider';
}

/// See also [partnershipStream].
class PartnershipStreamProvider extends AutoDisposeStreamProvider<Partnership> {
  /// See also [partnershipStream].
  PartnershipStreamProvider(String partnershipId)
    : this._internal(
        (ref) => partnershipStream(ref as PartnershipStreamRef, partnershipId),
        from: partnershipStreamProvider,
        name: r'partnershipStreamProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$partnershipStreamHash,
        dependencies: PartnershipStreamFamily._dependencies,
        allTransitiveDependencies:
            PartnershipStreamFamily._allTransitiveDependencies,
        partnershipId: partnershipId,
      );

  PartnershipStreamProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.partnershipId,
  }) : super.internal();

  final String partnershipId;

  @override
  Override overrideWith(
    Stream<Partnership> Function(PartnershipStreamRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: PartnershipStreamProvider._internal(
        (ref) => create(ref as PartnershipStreamRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        partnershipId: partnershipId,
      ),
    );
  }

  @override
  AutoDisposeStreamProviderElement<Partnership> createElement() {
    return _PartnershipStreamProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is PartnershipStreamProvider &&
        other.partnershipId == partnershipId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, partnershipId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin PartnershipStreamRef on AutoDisposeStreamProviderRef<Partnership> {
  /// The parameter `partnershipId` of this provider.
  String get partnershipId;
}

class _PartnershipStreamProviderElement
    extends AutoDisposeStreamProviderElement<Partnership>
    with PartnershipStreamRef {
  _PartnershipStreamProviderElement(super.provider);

  @override
  String get partnershipId =>
      (origin as PartnershipStreamProvider).partnershipId;
}

String _$categoriesHash() => r'f4ef265f870d64e100d65dbac33deef997899f1f';

/// See also [categories].
@ProviderFor(categories)
final categoriesProvider = AutoDisposeFutureProvider<List<Category>>.internal(
  categories,
  name: r'categoriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$categoriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CategoriesRef = AutoDisposeFutureProviderRef<List<Category>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
