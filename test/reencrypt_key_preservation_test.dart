import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Structural tests verifying crash-safe re-encryption key preservation:
/// - Old key is saved before switching to the new key
/// - Old key is cleared only after re-encryption completes
/// - Unlock page resumes interrupted re-encryption on startup
void main() {
  final fingerprintFile =
      File('lib/pages/auth/fingerprint_verification_page.dart');
  final encryptionProviderFile =
      File('lib/providers/encryption_provider.dart');
  final unlockFile = File('lib/pages/auth/encryption_unlock_page.dart');

  late String fingerprintContent;
  late String providerContent;
  late String unlockContent;

  setUpAll(() {
    fingerprintContent = fingerprintFile.readAsStringSync();
    providerContent = encryptionProviderFile.readAsStringSync();
    unlockContent = unlockFile.readAsStringSync();
  });

  group('FingerprintVerificationPage key preservation ordering', () {
    test('savePendingOldKey is called before saveReceivedKey', () {
      final saveOldIdx = fingerprintContent.indexOf('savePendingOldKey');
      final saveNewIdx = fingerprintContent.indexOf('saveReceivedKey');
      expect(saveOldIdx, greaterThan(-1));
      expect(saveNewIdx, greaterThan(-1));
      expect(
        saveOldIdx,
        lessThan(saveNewIdx),
        reason: 'savePendingOldKey must be called before saveReceivedKey '
            'so the old key is persisted before being replaced.',
      );
    });

    test('clearPendingOldKey is called after reencryptUserExpenses', () {
      final reencryptIdx =
          fingerprintContent.indexOf('reencryptUserExpenses');
      final clearIdx = fingerprintContent.indexOf(
        'clearPendingOldKey',
        reencryptIdx,
      );
      expect(reencryptIdx, greaterThan(-1));
      expect(
        clearIdx,
        greaterThan(reencryptIdx),
        reason: 'clearPendingOldKey must be called after '
            'reencryptUserExpenses completes successfully.',
      );
    });
  });

  group('EncryptionKeyNotifier pending old key methods', () {
    test('savePendingOldKey method exists', () {
      expect(
        providerContent.contains('savePendingOldKey'),
        isTrue,
        reason: 'EncryptionKeyNotifier must have a savePendingOldKey '
            'method to persist the old key before re-encryption.',
      );
    });

    test('clearPendingOldKey method exists', () {
      expect(
        providerContent.contains('clearPendingOldKey'),
        isTrue,
        reason: 'EncryptionKeyNotifier must have a clearPendingOldKey '
            'method to remove the old key after re-encryption.',
      );
    });

    test('getPendingOldKey method exists', () {
      expect(
        providerContent.contains('getPendingOldKey'),
        isTrue,
        reason: 'EncryptionKeyNotifier must have a getPendingOldKey '
            'method to retrieve the old key for resumption.',
      );
    });

    test('_pendingOldKeyPrefix constant exists', () {
      expect(
        providerContent.contains('_pendingOldKeyPrefix'),
        isTrue,
        reason: 'EncryptionKeyNotifier must declare a '
            '_pendingOldKeyPrefix constant for storage key naming.',
      );
    });
  });

  group('EncryptionUnlockPage re-encryption resumption', () {
    test('_resumeReencryptionIfNeeded method exists', () {
      expect(
        unlockContent.contains('_resumeReencryptionIfNeeded'),
        isTrue,
        reason: 'EncryptionUnlockPage must have a '
            '_resumeReencryptionIfNeeded method to resume '
            'interrupted re-encryption after password unlock.',
      );
    });

    test('getPendingOldKey is called within _resumeReencryptionIfNeeded', () {
      final methodIdx =
          unlockContent.indexOf('_resumeReencryptionIfNeeded');
      expect(methodIdx, greaterThan(-1));

      final callIdx = unlockContent.indexOf('getPendingOldKey', methodIdx);
      expect(
        callIdx,
        greaterThan(methodIdx),
        reason: '_resumeReencryptionIfNeeded must call getPendingOldKey '
            'to check for an interrupted re-encryption.',
      );
    });

    test('clearPendingOldKey is called after reencryptUserExpenses', () {
      final reencryptIdx = unlockContent.indexOf('reencryptUserExpenses');
      expect(reencryptIdx, greaterThan(-1));

      final clearIdx = unlockContent.indexOf(
        'clearPendingOldKey',
        reencryptIdx,
      );
      expect(
        clearIdx,
        greaterThan(reencryptIdx),
        reason: 'clearPendingOldKey must be called after '
            'reencryptUserExpenses in the unlock page.',
      );
    });
  });
}
