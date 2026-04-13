import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/providers/encryption_provider.dart';
import 'package:seppan/providers/expense_provider.dart';

/// Tests that encryption state is properly cleaned up on sign-out/delete,
/// preventing stale keys from leaking into the next session.
void main() {
  group('Encryption state cleanup on sign-out', () {
    test('clear() resets in-memory key to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;
      expect(container.read(encryptionKeyNotifierProvider), isNotNull);

      container.read(encryptionKeyNotifierProvider.notifier).clear();
      expect(container.read(encryptionKeyNotifierProvider), isNull);
    });

    test('expense repository reflects key availability', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // No key → repository has null key
      expect(container.read(expenseRepositoryProvider).encryptionKey, isNull);

      // Set key → repository has key
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;
      expect(
          container.read(expenseRepositoryProvider).encryptionKey, equals(key));

      // Clear key → repository back to null
      container.read(encryptionKeyNotifierProvider.notifier).clear();
      expect(container.read(expenseRepositoryProvider).encryptionKey, isNull);
    });

    test('stale key without clear causes next session to skip setup', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Session 1: user has key
      final oldKey = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = oldKey;

      // Sign-out WITHOUT clearing key (the bug scenario)
      // keepAlive notifier retains state across provider lifecycle

      // Session 2: stale key is still present
      expect(container.read(encryptionKeyNotifierProvider), isNotNull,
          reason: 'Without clear, stale key persists');
    });

    test('clear before sign-out ensures fresh session', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Session 1: user has key
      final oldKey = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = oldKey;

      // Sign-out WITH clear
      container.read(encryptionKeyNotifierProvider.notifier).clear();

      // Session 2: key is null → password setup or unlock will be required
      expect(container.read(encryptionKeyNotifierProvider), isNull);
    });
  });

  group('Router redirect with encryption unlock', () {
    // These test the pure redirect function directly.
    // The encryptionUnlockRequired async provider is tested via
    // integration tests since it depends on Supabase.

    test('redirects to /encryption-unlock when key missing', () {
      // Tested in router_redirect_test.dart — included here for
      // documentation of the full sign-out → re-login flow:
      //
      // 1. User logs out → clearAll() clears memory key + secure storage
      // 2. User re-logs in → currentUser changes → currentPartnership loads
      // 3. encryptionUnlockRequired provider evaluates:
      //    a. key is null → continue
      //    b. tryRestoreFromCache → empty (cleared) → continue
      //    c. getWrappedKey from server → found → return true
      // 4. Router redirect sees needsEncryptionUnlock=true → /encryption-unlock
      // 5. User enters password → key restored → provider returns false
      // 6. Router allows navigation to /home
    });
  });
}
