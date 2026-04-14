# Seppan

2人のパートナー間での割り勘・立て替え管理アプリ。支出データはエンドツーエンド暗号化（E2EE）で保護され、サーバーを含む第三者が平文データにアクセスすることはできません。

## 機能

- パートナー間の支出記録・割り勘計算
- カテゴリ別の支出管理
- QR コードによるパートナーリンク
- エンドツーエンド暗号化による支出データの保護

## 技術構成

| レイヤー       | 技術                                               |
| -------------- | -------------------------------------------------- |
| フレームワーク | Flutter                                            |
| バックエンド   | Supabase (PostgreSQL, Auth, Realtime, RLS)         |
| 暗号化         | cryptography (AES-256-GCM, Argon2id, X25519, HKDF) |
| 鍵キャッシュ   | flutter_secure_storage                             |

## 暗号化 & 鍵交換フロー

```mermaid
sequenceDiagram
    actor A as ユーザー A（招待者）
    participant S as Supabase
    actor B as ユーザー B（参加者）

    Note over A: サインアップ・プロフィール設定
    A->>S: アカウント作成

    Note over A: 暗号化パスワード設定
    A->>A: パートナーシップ鍵 K を生成
    A->>A: パスワード → Argon2id → 導出鍵 DK
    A->>A: AES-GCM(DK, K) → wrapped_K
    A->>S: wrapped_K, salt, nonce を保存

    Note over A: 支出データの入力（リンク前でも可能）
    A->>A: 支出を K で AES-256-GCM 暗号化
    A->>S: encrypted_data を保存

    Note over B: サインアップ・プロフィール設定
    B->>S: アカウント作成

    Note over B: 暗号化パスワード設定
    B->>B: パートナーシップ鍵 K_B を生成
    B->>B: パスワード → Argon2id → wrapped_K_B
    B->>S: wrapped_K_B, salt, nonce を保存

    Note over B: 支出データの入力（リンク前でも可能）
    B->>B: 支出を K_B で暗号化
    B->>S: encrypted_data を保存

    Note over A,B: パートナーリンク（ECDH 鍵交換）

    A->>A: X25519 鍵ペア (a, A_pub) 生成
    A->>S: A_pub を保存
    Note over A: QR コード表示: {pid, A_pub}

    B->>B: QR スキャン → pid, A_pub 取得
    B->>B: X25519 鍵ペア (b, B_pub) 生成
    B->>S: partnership に参加 + B_pub を保存
    S-->>A: Realtime: B_pub を受信

    Note over A,B: フィンガープリント確認
    A->>A: fp = SHA-256(A_pub ‖ B_pub) → 6桁×4組
    B->>B: fp = SHA-256(A_pub ‖ B_pub) → 6桁×4組
    Note over A,B: 口頭でセキュリティコードの一致を確認

    Note over A: 「一致を確認」ボタン押下
    A->>A: s = HKDF(X25519(a, B_pub))
    A->>A: wrapped_K_ecdh = AES-GCM(s, K)
    A->>S: wrapped_K_ecdh を保存

    S-->>B: Realtime: wrapped_K_ecdh を受信
    Note over B: 「一致を確認」ボタン押下
    B->>B: s = HKDF(X25519(b, A_pub))
    B->>B: K = 復号(wrapped_K_ecdh, s)
    B->>B: 既存支出を K_B → K で再暗号化
    B->>S: 再暗号化データ + K をパスワードで再ラップして保存
    B->>S: パートナーシップを active に

    Note over A,B: リンク完了 — 以後は共通鍵 K で暗号化

    Note over A: 支出入力
    A->>A: AES-256-GCM(K, 平文, AAD)
    A->>S: encrypted_data

    Note over B: 支出閲覧
    B->>S: encrypted_data 取得
    B->>B: AES-256-GCM 復号(K, 暗号文, AAD)

    Note over A,B: 別デバイスでログイン時
    A->>A: パスワード入力 → Argon2id → DK
    A->>S: wrapped_K 取得
    A->>A: K = AES-GCM 復号(DK, wrapped_K)
    Note over A: ロック解除完了
```

## E2EE 設計

### 暗号化対象

支出の機密フィールド（`amount`, `currency`, `ratio`, `category`, `memo`）を JSON にまとめ、AES-256-GCM で暗号化します。`id`, `partnership_id`, `paid_by`, `date` などのメタデータは暗号化しません（クエリ・ソート・RLS に必要なため）。

### 暗号文フォーマット

```
base64( nonce[12bytes] || ciphertext || tag[16bytes] )
AAD = "$expenseId:$partnershipId"
```

AAD（Additional Authenticated Data）に expense ID と partnership ID をバインドすることで、暗号文のコピペ攻撃を防止します。

### 鍵管理

```
パートナーシップ鍵 K (AES-256, 32bytes)
  │
  ├─ ユーザー A のパスワード
  │   → Argon2id (memory=64MB, iterations=3) → 導出鍵 DK_A
  │   → AES-GCM(key=DK_A, plaintext=K) → wrapped_K_A
  │   → サーバーに保存: wrapped_K_A, salt_A, nonce_A
  │
  └─ ユーザー B のパスワード
      → Argon2id → 導出鍵 DK_B
      → AES-GCM(key=DK_B, plaintext=K) → wrapped_K_B
      → サーバーに保存: wrapped_K_B, salt_B, nonce_B
```

- サーバーは暗号文とラップ済み鍵のみを保持し、平文の鍵 K やパスワードには一切アクセスできません
- デバイスローカルでは `flutter_secure_storage` に鍵をキャッシュし、毎回のパスワード入力を不要にします
