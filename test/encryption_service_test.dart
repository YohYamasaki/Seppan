import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:seppan/services/encryption_service.dart';

void main() {
  group('EncryptionService', () {
    group('generatePartnershipKey', () {
      test('generates 32-byte key', () async {
        final key = await EncryptionService.generatePartnershipKey();
        expect(key.length, 32);
      });

      test('generates unique keys', () async {
        final key1 = await EncryptionService.generatePartnershipKey();
        final key2 = await EncryptionService.generatePartnershipKey();
        expect(key1, isNot(equals(key2)));
      });
    });

    group('ECDH key exchange', () {
      test('both parties derive the same shared secret', () async {
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();

        final pubA = await keyPairA.extractPublicKey();
        final pubB = await keyPairB.extractPublicKey();

        final secretA =
            await EncryptionService.deriveSharedSecret(keyPairA, pubB);
        final secretB =
            await EncryptionService.deriveSharedSecret(keyPairB, pubA);

        expect(secretA, equals(secretB));
      });

      test('shared secret is 32 bytes', () async {
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();
        final pubB = await keyPairB.extractPublicKey();

        final secret =
            await EncryptionService.deriveSharedSecret(keyPairA, pubB);
        expect(secret.length, 32);
      });

      test('different key pairs produce different shared secrets', () async {
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();
        final keyPairC = await EncryptionService.generateEcdhKeyPair();

        final pubB = await keyPairB.extractPublicKey();
        final pubC = await keyPairC.extractPublicKey();

        final secretAB =
            await EncryptionService.deriveSharedSecret(keyPairA, pubB);
        final secretAC =
            await EncryptionService.deriveSharedSecret(keyPairA, pubC);

        expect(secretAB, isNot(equals(secretAC)));
      });
    });

    group('wrapKeyWithSharedSecret / unwrapKeyWithSharedSecret', () {
      test('round-trip: wrap then unwrap recovers original key', () async {
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();
        final pubB = await keyPairB.extractPublicKey();

        final sharedSecret =
            await EncryptionService.deriveSharedSecret(keyPairA, pubB);
        final originalKey = await EncryptionService.generatePartnershipKey();

        final wrapped = await EncryptionService.wrapKeyWithSharedSecret(
            originalKey, sharedSecret);
        final unwrapped = await EncryptionService.unwrapKeyWithSharedSecret(
            wrapped, sharedSecret);

        expect(unwrapped, equals(originalKey));
      });

      test('wrong shared secret fails to unwrap', () async {
        final sharedSecret1 = await EncryptionService.generatePartnershipKey();
        final sharedSecret2 = await EncryptionService.generatePartnershipKey();
        final originalKey = await EncryptionService.generatePartnershipKey();

        final wrapped = await EncryptionService.wrapKeyWithSharedSecret(
            originalKey, sharedSecret1);

        expect(
          () => EncryptionService.unwrapKeyWithSharedSecret(
              wrapped, sharedSecret2),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      });
    });

    group('generateFingerprint', () {
      test('same key pair produces same fingerprint', () async {
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();
        final pubA = await keyPairA.extractPublicKey();
        final pubB = await keyPairB.extractPublicKey();

        final fp1 = await EncryptionService.generateFingerprint(pubA, pubB);
        final fp2 = await EncryptionService.generateFingerprint(pubA, pubB);

        expect(fp1, equals(fp2));
      });

      test('fingerprint format: 4 groups of 6 digits', () async {
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();
        final pubA = await keyPairA.extractPublicKey();
        final pubB = await keyPairB.extractPublicKey();

        final fp = await EncryptionService.generateFingerprint(pubA, pubB);
        final groups = fp.split(' ');

        expect(groups.length, 4);
        for (final group in groups) {
          expect(group.length, 6);
          expect(int.tryParse(group), isNotNull);
        }
      });

      test('different key pairs produce different fingerprints', () async {
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();
        final keyPairC = await EncryptionService.generateEcdhKeyPair();
        final pubA = await keyPairA.extractPublicKey();
        final pubB = await keyPairB.extractPublicKey();
        final pubC = await keyPairC.extractPublicKey();

        final fp1 = await EncryptionService.generateFingerprint(pubA, pubB);
        final fp2 = await EncryptionService.generateFingerprint(pubA, pubC);

        expect(fp1, isNot(equals(fp2)));
      });

      test('order matters: (A,B) != (B,A)', () async {
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();
        final pubA = await keyPairA.extractPublicKey();
        final pubB = await keyPairB.extractPublicKey();

        final fp1 = await EncryptionService.generateFingerprint(pubA, pubB);
        final fp2 = await EncryptionService.generateFingerprint(pubB, pubA);

        expect(fp1, isNot(equals(fp2)));
      });
    });

    group('Argon2id key wrapping', () {
      test('round-trip: wrap then unwrap with correct password', () async {
        final key = await EncryptionService.generatePartnershipKey();
        const password = 'test-password-123';

        final result = await EncryptionService.wrapKey(key, password);
        final unwrapped = await EncryptionService.unwrapKey(
          result.wrappedKey,
          result.salt,
          result.nonce,
          password,
        );

        expect(unwrapped, equals(key));
      });

      test('wrong password fails to unwrap', () async {
        final key = await EncryptionService.generatePartnershipKey();
        const password = 'correct-password';
        const wrongPassword = 'wrong-password';

        final result = await EncryptionService.wrapKey(key, password);

        expect(
          () => EncryptionService.unwrapKey(
            result.wrappedKey,
            result.salt,
            result.nonce,
            wrongPassword,
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      });

      test('same password with different salt produces different wrappedKey',
          () async {
        final key = await EncryptionService.generatePartnershipKey();
        const password = 'same-password';

        final result1 = await EncryptionService.wrapKey(key, password);
        final result2 = await EncryptionService.wrapKey(key, password);

        expect(result1.salt, isNot(equals(result2.salt)));
        expect(result1.wrappedKey, isNot(equals(result2.wrappedKey)));
      });
    });

    group('expense field encryption/decryption', () {
      test('round-trip: encrypt then decrypt', () async {
        final key = await EncryptionService.generatePartnershipKey();
        const expenseId = 'expense-uuid-123';
        const partnershipId = 'partnership-uuid-456';

        final encrypted = await EncryptionService.encryptExpenseFields(
          key: key,
          expenseId: expenseId,
          partnershipId: partnershipId,
          amount: 1500,
          currency: 'JPY',
          ratio: 0.5,
          category: '食費',
          memo: 'ランチ',
        );

        final decrypted = await EncryptionService.decryptExpenseFields(
          key: key,
          expenseId: expenseId,
          partnershipId: partnershipId,
          encryptedData: encrypted,
        );

        expect(decrypted['amount'], 1500);
        expect(decrypted['currency'], 'JPY');
        expect(decrypted['ratio'], 0.5);
        expect(decrypted['category'], '食費');
        expect(decrypted['memo'], 'ランチ');
      });

      test('wrong key fails to decrypt', () async {
        final key1 = await EncryptionService.generatePartnershipKey();
        final key2 = await EncryptionService.generatePartnershipKey();
        const expenseId = 'expense-uuid-123';
        const partnershipId = 'partnership-uuid-456';

        final encrypted = await EncryptionService.encryptExpenseFields(
          key: key1,
          expenseId: expenseId,
          partnershipId: partnershipId,
          amount: 1500,
          currency: 'JPY',
          ratio: 0.5,
          category: '食費',
          memo: '',
        );

        expect(
          () => EncryptionService.decryptExpenseFields(
            key: key2,
            expenseId: expenseId,
            partnershipId: partnershipId,
            encryptedData: encrypted,
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      });

      test('AAD mismatch: wrong expenseId fails', () async {
        final key = await EncryptionService.generatePartnershipKey();
        const partnershipId = 'partnership-uuid-456';

        final encrypted = await EncryptionService.encryptExpenseFields(
          key: key,
          expenseId: 'original-id',
          partnershipId: partnershipId,
          amount: 1000,
          currency: 'JPY',
          ratio: 0.5,
          category: '食費',
          memo: '',
        );

        expect(
          () => EncryptionService.decryptExpenseFields(
            key: key,
            expenseId: 'different-id',
            partnershipId: partnershipId,
            encryptedData: encrypted,
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      });

      test('AAD mismatch: wrong partnershipId fails', () async {
        final key = await EncryptionService.generatePartnershipKey();
        const expenseId = 'expense-uuid-123';

        final encrypted = await EncryptionService.encryptExpenseFields(
          key: key,
          expenseId: expenseId,
          partnershipId: 'original-partnership',
          amount: 1000,
          currency: 'JPY',
          ratio: 0.5,
          category: '食費',
          memo: '',
        );

        expect(
          () => EncryptionService.decryptExpenseFields(
            key: key,
            expenseId: expenseId,
            partnershipId: 'different-partnership',
            encryptedData: encrypted,
          ),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      });

      test('same data encrypted twice produces different ciphertext', () async {
        final key = await EncryptionService.generatePartnershipKey();
        const expenseId = 'expense-uuid-123';
        const partnershipId = 'partnership-uuid-456';

        final encrypted1 = await EncryptionService.encryptExpenseFields(
          key: key,
          expenseId: expenseId,
          partnershipId: partnershipId,
          amount: 1000,
          currency: 'JPY',
          ratio: 0.5,
          category: '食費',
          memo: '',
        );

        final encrypted2 = await EncryptionService.encryptExpenseFields(
          key: key,
          expenseId: expenseId,
          partnershipId: partnershipId,
          amount: 1000,
          currency: 'JPY',
          ratio: 0.5,
          category: '食費',
          memo: '',
        );

        // nonce が毎回異なるため暗号文も異なる
        expect(encrypted1, isNot(equals(encrypted2)));
      });
    });

    group('full E2E key exchange flow', () {
      test('complete flow: ECDH → wrap → password wrap → unwrap', () async {
        // A と B が ECDH 鍵ペアを生成
        final keyPairA = await EncryptionService.generateEcdhKeyPair();
        final keyPairB = await EncryptionService.generateEcdhKeyPair();
        final pubA = await keyPairA.extractPublicKey();
        final pubB = await keyPairB.extractPublicKey();

        // 両者が同じ共有秘密を導出
        final secretA =
            await EncryptionService.deriveSharedSecret(keyPairA, pubB);
        final secretB =
            await EncryptionService.deriveSharedSecret(keyPairB, pubA);
        expect(secretA, equals(secretB));

        // フィンガープリントが一致
        final fpA = await EncryptionService.generateFingerprint(pubA, pubB);
        final fpB = await EncryptionService.generateFingerprint(pubA, pubB);
        expect(fpA, equals(fpB));

        // A が AES 鍵を生成し、共有秘密でラップ
        final partnershipKey =
            await EncryptionService.generatePartnershipKey();
        final wrappedForExchange =
            await EncryptionService.wrapKeyWithSharedSecret(
                partnershipKey, secretA);

        // B が共有秘密でアンラップ
        final recoveredKey =
            await EncryptionService.unwrapKeyWithSharedSecret(
                wrappedForExchange, secretB);
        expect(recoveredKey, equals(partnershipKey));

        // 両者がパスワードで鍵をラップ
        const passwordA = 'alice-password';
        const passwordB = 'bob-password';

        final wrappedA =
            await EncryptionService.wrapKey(recoveredKey, passwordA);
        final wrappedB =
            await EncryptionService.wrapKey(recoveredKey, passwordB);

        // パスワードからアンラップして同じ鍵が得られる
        final keyFromA = await EncryptionService.unwrapKey(
          wrappedA.wrappedKey,
          wrappedA.salt,
          wrappedA.nonce,
          passwordA,
        );
        final keyFromB = await EncryptionService.unwrapKey(
          wrappedB.wrappedKey,
          wrappedB.salt,
          wrappedB.nonce,
          passwordB,
        );

        expect(keyFromA, equals(partnershipKey));
        expect(keyFromB, equals(partnershipKey));

        // 両者が同じ鍵で expense を暗号化/復号できる
        const expenseId = 'test-expense-id';
        const partnershipId = 'test-partnership-id';

        final encrypted = await EncryptionService.encryptExpenseFields(
          key: keyFromA,
          expenseId: expenseId,
          partnershipId: partnershipId,
          amount: 3000,
          currency: 'JPY',
          ratio: 0.75,
          category: '食費',
          memo: 'ディナー',
        );

        final decrypted = await EncryptionService.decryptExpenseFields(
          key: keyFromB,
          expenseId: expenseId,
          partnershipId: partnershipId,
          encryptedData: encrypted,
        );

        expect(decrypted['amount'], 3000);
        expect(decrypted['memo'], 'ディナー');
      });
    });
  });
}
