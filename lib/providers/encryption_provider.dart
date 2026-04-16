import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/encryption_key_repository.dart';
import '../services/encryption_service.dart';
import 'auth_provider.dart';
import 'partnership_provider.dart';

part 'encryption_provider.g.dart';

@riverpod
EncryptionKeyRepository encryptionKeyRepository(Ref ref) {
  return EncryptionKeyRepository();
}

/// Determines if the user needs to enter their encryption password.
///
/// Returns true when the server has a wrapped key but the in-memory key
/// is null and local cache is empty (cleared on sign-out).
///
/// This provider is reactive: it re-evaluates automatically when the
/// user, partnership, or encryption key state changes.
@riverpod
Future<bool> encryptionUnlockRequired(Ref ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    debugPrint('[encryptionUnlock] user is null → false');
    return false;
  }

  // Already have key in memory — no unlock needed
  if (ref.watch(encryptionKeyNotifierProvider) != null) {
    debugPrint('[encryptionUnlock] key already in memory → false');
    return false;
  }

  debugPrint('[encryptionUnlock] awaiting partnership...');
  final partnership = await ref.watch(currentPartnershipProvider.future);
  if (partnership == null) {
    debugPrint('[encryptionUnlock] partnership is null → false');
    return false;
  }
  debugPrint('[encryptionUnlock] partnership=${partnership.id}, status=${partnership.status}');

  // Try local cache first (e.g. app restart without sign-out)
  final restored = await ref
      .read(encryptionKeyNotifierProvider.notifier)
      .tryRestoreFromCache(partnership.id);
  if (restored) {
    debugPrint('[encryptionUnlock] restored from cache → false');
    return false;
  }
  // Note: tryRestoreFromCache sets encryptionKeyNotifierProvider if
  // successful, which causes this provider to re-evaluate and return
  // false via the early exit above.

  // Local cache empty — check server for a wrapped key
  try {
    debugPrint('[encryptionUnlock] checking server for wrapped key...');
    final data = await ref
        .read(encryptionKeyRepositoryProvider)
        .getWrappedKey(partnership.id, user.id);
    debugPrint('[encryptionUnlock] wrappedKey found=${data != null} → ${data != null}');
    return data != null;
  } catch (e) {
    debugPrint('[encryptionUnlock] getWrappedKey error: $e → false');
    return false;
  }
}

@Riverpod(keepAlive: true)
class EncryptionKeyNotifier extends _$EncryptionKeyNotifier {
  static const _storage = FlutterSecureStorage();
  static const _keyPrefix = 'partnership_key_';

  Uint8List? _cachedDerivedKey;
  Uint8List? _cachedSalt;

  @override
  Uint8List? build() => null;

  bool get isUnlocked => state != null;

  /// 初回設定: 生の AES 鍵をパスワードでラップして保存
  Future<void> setupEncryption({
    required String partnershipId,
    required String userId,
    required String password,
    required Uint8List rawKey,
  }) async {
    final result = await EncryptionService.wrapKey(rawKey, password);

    // Argon2id 導出鍵をキャッシュ（ECDH 後の再ラップ用）
    _cachedDerivedKey = result.derivedKeyBytes;
    _cachedSalt = result.saltBytes;

    final repo = ref.read(encryptionKeyRepositoryProvider);
    await repo.storeWrappedKey(
      partnershipId: partnershipId,
      userId: userId,
      wrappedKey: result.wrappedKey,
      salt: result.salt,
      nonce: result.nonce,
    );

    // ローカルキャッシュに保存
    await _cacheKey(partnershipId, rawKey);
    state = rawKey;
  }

  /// パスワードで鍵をアンロック
  Future<bool> unlockWithPassword({
    required String partnershipId,
    required String userId,
    required String password,
  }) async {
    final repo = ref.read(encryptionKeyRepositoryProvider);
    final data = await repo.getWrappedKey(partnershipId, userId);
    if (data == null) return false;

    try {
      final rawKey = await EncryptionService.unwrapKey(
        data['wrapped_key'] as String,
        data['key_salt'] as String,
        data['key_nonce'] as String,
        password,
      );
      await _cacheKey(partnershipId, rawKey);
      state = rawKey;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// ローカルキャッシュから鍵を復元（パスワード不要）
  Future<bool> tryRestoreFromCache(String partnershipId) async {
    final cached = await _storage.read(key: '$_keyPrefix$partnershipId');
    if (cached == null) return false;

    final bytes = _hexToBytes(cached);
    state = bytes;
    return true;
  }

  /// Re-associate the current key with a new partnership
  Future<void> migrateToPartnership({
    required String oldPartnershipId,
    required String newPartnershipId,
    required String userId,
  }) async {
    final key = state;
    if (key == null) return;

    // Copy encryption_keys entry from old to new partnership
    final repo = ref.read(encryptionKeyRepositoryProvider);
    final oldData = await repo.getWrappedKey(oldPartnershipId, userId);
    if (oldData != null) {
      await repo.storeWrappedKey(
        partnershipId: newPartnershipId,
        userId: userId,
        wrappedKey: oldData['wrapped_key'] as String,
        salt: oldData['key_salt'] as String,
        nonce: oldData['key_nonce'] as String,
      );
    }

    // Update local cache
    await _cacheKey(newPartnershipId, key);
  }

  /// Save a raw key received via ECDH key exchange (joiner side).
  /// Wraps with password if available, otherwise just caches locally.
  Future<void> saveReceivedKey({
    required String partnershipId,
    required String userId,
    required Uint8List rawKey,
  }) async {
    await _cacheKey(partnershipId, rawKey);
    state = rawKey;
  }

  /// キャッシュ済みの導出鍵で現在の AES 鍵を再ラップしてサーバーに保存。
  /// ECDH 鍵交換後にパスワード再入力なしで鍵をサーバーに保存するために使用。
  /// 導出鍵がメモリにない場合（アプリ再起動等）は false を返す。
  Future<bool> rewrapForPartnership({
    required String partnershipId,
    required String userId,
  }) async {
    final key = state;
    if (key == null || _cachedDerivedKey == null || _cachedSalt == null) {
      return false;
    }

    final result = await EncryptionService.wrapKeyWithDerivedKey(
      key,
      derivedKey: _cachedDerivedKey!,
      salt: _cachedSalt!,
    );

    final repo = ref.read(encryptionKeyRepositoryProvider);
    await repo.storeWrappedKey(
      partnershipId: partnershipId,
      userId: userId,
      wrappedKey: result.wrappedKey,
      salt: result.salt,
      nonce: result.nonce,
    );

    await _cacheKey(partnershipId, key);

    _cachedDerivedKey = null;
    _cachedSalt = null;
    return true;
  }

  /// Ensure the current in-memory key is cached under [partnershipId].
  /// No-op if the key is null.
  Future<void> ensureCached(String partnershipId) async {
    final key = state;
    if (key == null) return;
    await _cacheKey(partnershipId, key);
  }

  void clear() {
    state = null;
  }

  /// Clear all encryption state: memory + local cache.
  /// Call on sign-out or account deletion to prevent stale keys
  /// from persisting into the next session.
  Future<void> clearAll() async {
    state = null;
    await _storage.deleteAll();
  }

  Future<void> _cacheKey(String partnershipId, Uint8List key) async {
    await _storage.write(
      key: '$_keyPrefix$partnershipId',
      value: _bytesToHex(key),
    );
  }

  static String _bytesToHex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }
}
