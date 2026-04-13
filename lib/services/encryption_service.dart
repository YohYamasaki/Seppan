import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class EncryptionService {
  static final _aesGcm = AesGcm.with256bits();
  static final _x25519 = X25519();
  static final _hkdf = Hkdf(hmac: Hmac(Sha256()), outputLength: 32);

  // --- AES-256 鍵生成 ---

  static Future<Uint8List> generatePartnershipKey() async {
    final key = await _aesGcm.newSecretKey();
    return Uint8List.fromList(await key.extractBytes());
  }

  // --- X25519 ECDH ---

  static Future<SimpleKeyPair> generateEcdhKeyPair() async {
    return await _x25519.newKeyPair();
  }

  static Future<Uint8List> deriveSharedSecret(
    SimpleKeyPair myKeyPair,
    SimplePublicKey peerPublicKey,
  ) async {
    final sharedSecret = await _x25519.sharedSecretKey(
      keyPair: myKeyPair,
      remotePublicKey: peerPublicKey,
    );
    final derivedKey = await _hkdf.deriveKey(
      secretKey: sharedSecret,
      nonce: List<int>.filled(32, 0),
      info: utf8.encode('seppan-ecdh-wrap-v1'),
    );
    return Uint8List.fromList(await derivedKey.extractBytes());
  }

  // --- ECDH 鍵ラップ（共有秘密で AES 鍵をラップ） ---

  static Future<String> wrapKeyWithSharedSecret(
    Uint8List rawKey,
    Uint8List sharedSecret,
  ) async {
    final secretKey = SecretKey(sharedSecret);
    final secretBox = await _aesGcm.encrypt(
      rawKey,
      secretKey: secretKey,
    );
    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return base64Url.encode(combined);
  }

  static Future<Uint8List> unwrapKeyWithSharedSecret(
    String wrappedKeyB64,
    Uint8List sharedSecret,
  ) async {
    final combined = base64Url.decode(wrappedKeyB64);
    final nonce = combined.sublist(0, 12);
    final cipherText = combined.sublist(12, combined.length - 16);
    final mac = Mac(combined.sublist(combined.length - 16));

    final secretKey = SecretKey(sharedSecret);
    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: mac,
    );
    final decrypted = await _aesGcm.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(decrypted);
  }

  // --- フィンガープリント ---

  static Future<String> generateFingerprint(
    SimplePublicKey pubKeyA,
    SimplePublicKey pubKeyB,
  ) async {
    final combined = Uint8List.fromList([
      ...pubKeyA.bytes,
      ...pubKeyB.bytes,
    ]);
    final hash = await Sha256().hash(combined);
    final hashBytes = hash.bytes;

    // 6桁数字×4組 (80ビット強度)
    // 各 20ビットを取り出して 10^6 で mod → 6桁数字
    final groups = <String>[];
    for (var i = 0; i < 4; i++) {
      final offset = i * 3; // 3バイト = 24ビット、20ビット使用
      final value = (hashBytes[offset] << 16) |
          (hashBytes[offset + 1] << 8) |
          hashBytes[offset + 2];
      // 24ビットから 10^6 で mod → 6桁数字
      groups.add((value % 1000000).toString().padLeft(6, '0'));
    }
    return groups.join(' ');
  }

  // --- パスワードベースの鍵ラップ（Argon2id） ---

  static Future<({String wrappedKey, String salt, String nonce, Uint8List derivedKeyBytes, Uint8List saltBytes})> wrapKey(
    Uint8List rawKey,
    String password,
  ) async {
    // ランダムな salt 生成
    final saltBytes = Uint8List(16);
    _fillRandom(saltBytes);

    // Argon2id で鍵導出
    final argon2id = Argon2id(
      memory: 65536, // 64MB
      iterations: 3,
      parallelism: 1,
      hashLength: 32,
    );
    final derivedKey = await argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: saltBytes,
    );

    // AES-GCM で rawKey をラップ
    final derivedKeyBytes = Uint8List.fromList(await derivedKey.extractBytes());
    final wrappingKey = SecretKey(derivedKeyBytes);
    final secretBox = await _aesGcm.encrypt(
      rawKey,
      secretKey: wrappingKey,
    );

    return (
      wrappedKey: base64Url.encode(Uint8List.fromList([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ])),
      salt: base64Url.encode(saltBytes),
      nonce: base64Url.encode(Uint8List.fromList(secretBox.nonce)),
      derivedKeyBytes: derivedKeyBytes,
      saltBytes: saltBytes,
    );
  }

  static Future<Uint8List> unwrapKey(
    String wrappedKeyB64,
    String saltB64,
    String nonceB64,
    String password,
  ) async {
    final wrapped = base64Url.decode(wrappedKeyB64);
    final salt = base64Url.decode(saltB64);
    final nonce = base64Url.decode(nonceB64);

    // Argon2id で鍵導出（同じパラメータ）
    final argon2id = Argon2id(
      memory: 65536,
      iterations: 3,
      parallelism: 1,
      hashLength: 32,
    );
    final derivedKey = await argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    // AES-GCM でアンラップ
    final wrappingKey = SecretKey(await derivedKey.extractBytes());
    final cipherText = wrapped.sublist(0, wrapped.length - 16);
    final mac = Mac(wrapped.sublist(wrapped.length - 16));
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final decrypted = await _aesGcm.decrypt(secretBox, secretKey: wrappingKey);
    return Uint8List.fromList(decrypted);
  }

  /// Wrap [rawKey] using an already-derived wrapping key + salt.
  /// This avoids a second Argon2id derivation (and password prompt)
  /// when the partnership key changes after ECDH key exchange.
  static Future<({String wrappedKey, String salt, String nonce})>
      wrapKeyWithDerivedKey(
    Uint8List rawKey, {
    required Uint8List derivedKey,
    required Uint8List salt,
  }) async {
    final wrappingKey = SecretKey(derivedKey);
    final secretBox = await _aesGcm.encrypt(
      rawKey,
      secretKey: wrappingKey,
    );

    return (
      wrappedKey: base64Url.encode(Uint8List.fromList([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ])),
      salt: base64Url.encode(salt),
      nonce: base64Url.encode(Uint8List.fromList(secretBox.nonce)),
    );
  }

  // --- Expense フィールド暗号化/復号 ---

  static Future<String> encryptExpenseFields({
    required Uint8List key,
    required String expenseId,
    required String partnershipId,
    required int amount,
    required String currency,
    required double ratio,
    required String category,
    required String memo,
  }) async {
    final plaintext = jsonEncode({
      'amount': amount,
      'currency': currency,
      'ratio': ratio,
      'category': category,
      'memo': memo,
    });

    final aad = utf8.encode('$expenseId:$partnershipId');
    final secretKey = SecretKey(key);
    final secretBox = await _aesGcm.encrypt(
      utf8.encode(plaintext),
      secretKey: secretKey,
      aad: aad,
    );

    final combined = Uint8List.fromList([
      ...secretBox.nonce,
      ...secretBox.cipherText,
      ...secretBox.mac.bytes,
    ]);
    return base64.encode(combined);
  }

  static Future<Map<String, dynamic>> decryptExpenseFields({
    required Uint8List key,
    required String expenseId,
    required String partnershipId,
    required String encryptedData,
  }) async {
    final combined = base64.decode(encryptedData);
    final nonce = combined.sublist(0, 12);
    final cipherText = combined.sublist(12, combined.length - 16);
    final mac = Mac(combined.sublist(combined.length - 16));

    final aad = utf8.encode('$expenseId:$partnershipId');
    final secretKey = SecretKey(key);
    final secretBox = SecretBox(cipherText, nonce: nonce, mac: mac);
    final decrypted = await _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: aad,
    );

    return jsonDecode(utf8.decode(decrypted)) as Map<String, dynamic>;
  }

  // --- ヘルパー ---

  static void _fillRandom(Uint8List bytes) {
    // cryptography パッケージの SecretKey 生成でランダムを使うが、
    // salt にはダミー→正式にはランダムが必要
    // SecretKey のランダム生成を利用して salt を作る
    final random = SecretKeyData.random(length: bytes.length);
    final randomBytes = random.bytes;
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = randomBytes[i];
    }
  }
}
