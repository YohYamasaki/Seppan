// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'encryption_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$encryptionKeyRepositoryHash() =>
    r'c68340b20b591719e429a7cd78749a80ed063d84';

/// See also [encryptionKeyRepository].
@ProviderFor(encryptionKeyRepository)
final encryptionKeyRepositoryProvider =
    AutoDisposeProvider<EncryptionKeyRepository>.internal(
      encryptionKeyRepository,
      name: r'encryptionKeyRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$encryptionKeyRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EncryptionKeyRepositoryRef =
    AutoDisposeProviderRef<EncryptionKeyRepository>;
String _$encryptionUnlockRequiredHash() =>
    r'4b586b20530e754915aa879413b28c77b608cb40';

/// Determines if the user needs to enter their encryption password.
///
/// Returns true when the server has a wrapped key but the in-memory key
/// is null and local cache is empty (cleared on sign-out).
///
/// This provider is reactive: it re-evaluates automatically when the
/// user, partnership, or encryption key state changes.
///
/// Copied from [encryptionUnlockRequired].
@ProviderFor(encryptionUnlockRequired)
final encryptionUnlockRequiredProvider =
    AutoDisposeFutureProvider<bool>.internal(
      encryptionUnlockRequired,
      name: r'encryptionUnlockRequiredProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$encryptionUnlockRequiredHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef EncryptionUnlockRequiredRef = AutoDisposeFutureProviderRef<bool>;
String _$encryptionKeyNotifierHash() =>
    r'75bc6389ec71f7470d3e90b87be50187cbba02f2';

/// See also [EncryptionKeyNotifier].
@ProviderFor(EncryptionKeyNotifier)
final encryptionKeyNotifierProvider =
    NotifierProvider<EncryptionKeyNotifier, Uint8List?>.internal(
      EncryptionKeyNotifier.new,
      name: r'encryptionKeyNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$encryptionKeyNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$EncryptionKeyNotifier = Notifier<Uint8List?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
