import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/providers/encryption_provider.dart';
import 'package:seppan/providers/expense_provider.dart';

/// Tests that the expense provider chain correctly reflects
/// the current encryption key state.
///
/// The real bug was that InvitePage created a new partnership but never
/// invalidated currentPartnershipProvider, so expenses were saved against
/// a stale (archived) partnership ID. After restart, currentPartnershipProvider
/// re-evaluated to the new partnership and the expenses appeared gone.
///
/// We cannot fully reproduce the Supabase-dependent currentPartnershipProvider
/// in unit tests, but we CAN verify the expenseRepository ↔ encryptionKey
/// provider chain that is also part of this data-flow.
void main() {
  group('Provider chain: encryption key → expense repository', () {
    test('expenseRepository reflects key changes immediately', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially no key → repository has null key
      final repo1 = container.read(expenseRepositoryProvider);
      expect(repo1.encryptionKey, isNull);

      // Set key (simulates successful unlock/restore)
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;

      // Repository should now have the key
      final repo2 = container.read(expenseRepositoryProvider);
      expect(repo2.encryptionKey, equals(key));
      expect(identical(repo1, repo2), isFalse,
          reason: 'A new repository instance should be created when key changes');
    });

    test('key restore before migration: repository gets key for re-encryption',
        () {
      // Simulates the fix in currentPartnershipProvider:
      // 1. Key is null (app just launched, B was unlinked)
      // 2. Restore key from archived partnership cache
      // 3. expenseRepository now has the key for re-encryption
      //
      // Before fix: migrateUserExpenses ran with null key → plain migration
      // → AAD mismatch → data permanently corrupted
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initially no key
      expect(container.read(expenseRepositoryProvider).encryptionKey, isNull);

      // Simulate tryRestoreFromCache setting the key
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;

      // Now expenseRepository has the key — migrateUserExpenses will
      // re-encrypt instead of doing a plain (corrupting) migration
      final repo = container.read(expenseRepositoryProvider);
      expect(repo.encryptionKey, equals(key));
    });

    test('clearing key makes repository return null key again', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Set then clear
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;
      expect(container.read(expenseRepositoryProvider).encryptionKey, isNotNull);

      container.read(encryptionKeyNotifierProvider.notifier).clear();
      expect(container.read(expenseRepositoryProvider).encryptionKey, isNull);
    });
  });
}
