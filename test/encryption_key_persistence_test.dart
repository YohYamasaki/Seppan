import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/providers/encryption_provider.dart';

void main() {
  group('EncryptionKeyNotifier keepAlive', () {
    test('key persists after all listeners are removed', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Simulate a widget watching the provider
      final sub = container.listen(
        encryptionKeyNotifierProvider,
        (_, __) {},
      );

      // Set the key (simulates setupEncryption setting state)
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;
      expect(container.read(encryptionKeyNotifierProvider), equals(key));

      // Widget is disposed — no more active listeners.
      // With AutoDispose this would reset the state to null.
      sub.close();

      // Key must still be available (keepAlive).
      // This is the exact scenario that caused the /encryption-setup loop:
      // navigating away disposed all watchers, auto-dispose cleared the key,
      // and InvitePage saw null again.
      expect(container.read(encryptionKeyNotifierProvider), equals(key));
    });

    test('initially returns null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(encryptionKeyNotifierProvider), isNull);
    });

    test('clear() resets key to null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final key = Uint8List.fromList(List.generate(32, (i) => i));
      container.read(encryptionKeyNotifierProvider.notifier).state = key;
      expect(container.read(encryptionKeyNotifierProvider), isNotNull);

      container.read(encryptionKeyNotifierProvider.notifier).clear();
      expect(container.read(encryptionKeyNotifierProvider), isNull);
    });
  });
}
