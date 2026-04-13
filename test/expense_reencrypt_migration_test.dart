import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/services/encryption_service.dart';

/// Tests that expense re-encryption during partnership migration
/// correctly updates the AAD (Additional Authenticated Data).
///
/// Background: AES-GCM encrypts with AAD = "$expenseId:$partnershipId".
/// When an expense is migrated to a new partnership, the partnership_id
/// changes, so the ciphertext must be re-encrypted with the new AAD.
/// Without re-encryption, decryption fails with a MAC error.
void main() {
  late Uint8List key;

  setUp(() async {
    key = await EncryptionService.generatePartnershipKey();
  });

  const expenseId = 'expense-001';
  const oldPartnershipId = 'partnership-old';
  const newPartnershipId = 'partnership-new';

  Future<String> encrypt(String partnershipId) {
    return EncryptionService.encryptExpenseFields(
      key: key,
      expenseId: expenseId,
      partnershipId: partnershipId,
      amount: 1500,
      currency: 'JPY',
      ratio: 0.5,
      category: '食費',
      memo: 'ランチ',
    );
  }

  Future<Map<String, dynamic>> decrypt(
      String encryptedData, String partnershipId) {
    return EncryptionService.decryptExpenseFields(
      key: key,
      expenseId: expenseId,
      partnershipId: partnershipId,
      encryptedData: encryptedData,
    );
  }

  test('decrypt succeeds with matching partnership ID (baseline)', () async {
    final encrypted = await encrypt(oldPartnershipId);
    final fields = await decrypt(encrypted, oldPartnershipId);

    expect(fields['amount'], 1500);
    expect(fields['currency'], 'JPY');
    expect(fields['ratio'], 0.5);
    expect(fields['category'], '食費');
    expect(fields['memo'], 'ランチ');
  });

  test('decrypt fails with mismatched partnership ID (the bug)', () async {
    final encrypted = await encrypt(oldPartnershipId);

    // This simulates the old migrateUserExpenses: partnership_id changed
    // in the DB but encrypted_data still has the old AAD.
    expect(
      () => decrypt(encrypted, newPartnershipId),
      throwsA(anything),
    );
  });

  test('re-encrypt with new partnership ID fixes decryption', () async {
    // Step 1: encrypt with old partnership
    final oldEncrypted = await encrypt(oldPartnershipId);

    // Step 2: decrypt with old AAD (simulates migration read)
    final fields = await decrypt(oldEncrypted, oldPartnershipId);

    // Step 3: re-encrypt with new AAD (simulates migration write)
    final newEncrypted = await EncryptionService.encryptExpenseFields(
      key: key,
      expenseId: expenseId,
      partnershipId: newPartnershipId,
      amount: (fields['amount'] as num).toInt(),
      currency: fields['currency'] as String,
      ratio: (fields['ratio'] as num).toDouble(),
      category: fields['category'] as String,
      memo: fields['memo'] as String,
    );

    // Step 4: decrypt with new AAD succeeds
    final result = await decrypt(newEncrypted, newPartnershipId);
    expect(result['amount'], 1500);
    expect(result['currency'], 'JPY');
    expect(result['ratio'], 0.5);
    expect(result['category'], '食費');
    expect(result['memo'], 'ランチ');
  });

  test('old ciphertext still fails with new AAD after re-encrypt', () async {
    final oldEncrypted = await encrypt(oldPartnershipId);

    // Even after re-encrypting a new copy, the old ciphertext is
    // still bound to the old AAD.
    expect(
      () => decrypt(oldEncrypted, newPartnershipId),
      throwsA(anything),
    );
  });
}
