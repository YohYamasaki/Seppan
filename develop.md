# Seppan 開発者ガイド

2人のパートナー間での割り勘・立て替え管理アプリ。支払いデータはクライアント側で E2E 暗号化され、サーバーには暗号文のみが保存される。

---

## 技術スタック

| レイヤー       | 技術                                  | 役割                                      |
| -------------- | ------------------------------------- | ----------------------------------------- |
| フレームワーク | Flutter (Dart 3.11+)                  | クロスプラットフォーム UI                 |
| バックエンド   | Supabase                              | PostgreSQL, 認証, Realtime, RLS           |
| 状態管理       | Riverpod 3.0 + riverpod_generator     | コード生成ベースのリアクティブ状態管理    |
| データモデル   | Freezed + json_serializable           | イミュータブルモデル + JSON 変換          |
| ルーティング   | go_router                             | 宣言的ルーティング, ディープリンク対応    |
| E2E 暗号化     | cryptography + flutter_secure_storage | AES-256-GCM, X25519, Argon2id             |
| 認証           | google_sign_in + Supabase Auth        | Google ネイティブ, Apple (iOS), Email OTP |
| アナリティクス | Firebase Analytics                    | スクリーントラッキング                    |
| チャート       | fl_chart                              | カテゴリ別集計の可視化                    |

---

## アーキテクチャ概要

```mermaid
graph TD
    Pages["Pages (UI)<br/>sign_in, profile_setup, invite,<br/>fingerprint, encryption, home,<br/>stats, history, settings"]
    Providers["Providers (状態管理)<br/>auth, partnership, expense,<br/>balance, encryption"]
    Repos["Repositories (データ層)<br/>auth, partnership, expense,<br/>encryption_key, profile"]
    Services["Services<br/>encryption_service<br/>csv_service"]
    Utils["Utils (純粋関数)<br/>balance, expense_stats,<br/>formatters, router_redirect"]
    Supabase["Supabase<br/>PostgreSQL + Auth + Realtime"]

    Pages --> Providers
    Providers --> Repos
    Repos --> Services
    Repos --> Supabase
    Providers --> Utils
```

**レイヤーのルール:**

- Pages は Providers のみを参照し、Repositories や Services を直接呼ばない（例外: 暗号化フロー）
- Providers は Repositories を参照し、ビジネスロジックは Utils に委譲する
- Repositories は Supabase と直接通信し、暗号化/復号を内部で透過的に行う
- Services と Utils は外部依存を持たない純粋な関数群

---

## ディレクトリ構成

```
lib/
├── main.dart                   # エントリポイント (Firebase/Supabase 初期化)
├── app.dart                    # MaterialApp.router ラッパー
├── config/
│   ├── supabase.dart           # Supabase クライアント初期化
│   ├── theme.dart              # Material 3 テーマ定義
│   └── router.dart             # GoRouter ルート定義 + リフレッシュロジック
├── models/                     # Freezed イミュータブルモデル
│   ├── expense.dart            # 支払い (復号済みの状態)
│   ├── partnership.dart        # パートナーシップ (ECDH鍵含む)
│   ├── profile.dart            # ユーザープロフィール
│   └── category.dart           # カテゴリ
├── providers/                  # Riverpod プロバイダー
│   ├── auth_provider.dart      # 認証状態, ユーザー, プロフィール
│   ├── partnership_provider.dart # パートナーシップ, パートナー情報
│   ├── expense_provider.dart   # 支払いデータ (暗号化鍵注入)
│   ├── balance_provider.dart   # 残高計算, カテゴリ集計
│   └── encryption_provider.dart # 暗号化鍵ライフサイクル管理
├── repositories/               # データアクセス層
│   ├── auth_repository.dart    # 認証操作 (Google/Apple/Email)
│   ├── partnership_repository.dart # パートナーシップ CRUD
│   ├── expense_repository.dart # 支払い CRUD (暗号化透過)
│   ├── encryption_key_repository.dart # ラップ鍵の保存/取得
│   └── profile_repository.dart # プロフィール CRUD
├── services/                   # ビジネスロジック
│   ├── encryption_service.dart # 暗号化操作 (AES, ECDH, Argon2id)
│   └── csv_service.dart        # CSV エクスポート/インポート
├── utils/                      # 純粋関数ユーティリティ
│   ├── router_redirect.dart    # ルーターリダイレクト状態機械
│   ├── balance.dart            # 残高計算
│   ├── expense_stats.dart      # 月別集計/カテゴリ集計
│   ├── formatters.dart         # 日付/通貨フォーマット
│   └── reorder.dart            # リスト並び替え
├── pages/                      # 画面
│   ├── loading_page.dart       # 起動時ローディング画面
│   ├── auth/                   # 認証・暗号化フロー
│   ├── home/                   # ホーム (ダッシュボード)
│   ├── stats/                  # 統計
│   ├── history/                # 履歴 (マルチセレクト対応)
│   ├── expense_input/          # 支払い入力
│   ├── settings/               # 設定
│   └── shell/                  # BottomNavigationBar シェル
└── widgets/                    # 共通ウィジェット
```

---

## E2E 暗号化アーキテクチャ

### 暗号化の対象

| フィールド                                    | 暗号化 | 備考                                    |
| --------------------------------------------- | ------ | --------------------------------------- |
| amount, currency, ratio, category, memo       | 暗号化 | `encrypted_data` カラムに base64 で保存 |
| id, partnership_id, paid_by, date, created_at | 平文   | インデックス/クエリに必要               |

### 使用アルゴリズム

| 用途               | アルゴリズム              | 備考                           |
| ------------------ | ------------------------- | ------------------------------ |
| 支払いデータ暗号化 | AES-256-GCM               | AAD: `expenseId:partnershipId` |
| パートナー間鍵交換 | X25519 ECDH + HKDF-SHA256 | 共有秘密鍵でラップ/アンラップ  |
| パスワード鍵導出   | Argon2id (64MB, 3回)      | AES-GCM でラップ/アンラップ    |
| ローカルキャッシュ | flutter_secure_storage    | hex エンコードで保存           |

### 鍵の保存場所

| 保存場所                   | 内容                                        | キー名                        |
| -------------------------- | ------------------------------------------- | ----------------------------- |
| メモリ (Riverpod)          | 生の AES-256 パートナーシップ鍵             | `EncryptionKeyNotifier.state` |
| ローカル (SecureStorage)   | 生の鍵の hex エンコード                     | `partnership_key_{pid}`       |
| サーバー (encryption_keys) | Argon2id でラップされた鍵 + ソルト + ナンス | -                             |

### 暗号文フォーマット

```
base64( nonce[12bytes] || ciphertext || tag[16bytes] )
AAD = "$expenseId:$partnershipId"
```

AAD（Additional Authenticated Data）に expense ID と partnership ID をバインドすることで、暗号文のコピペ攻撃（別の expense や partnership に暗号文を移動する攻撃）を防止する。

### 鍵管理の構造

```mermaid
graph TD
    K["パートナーシップ鍵 K<br/>(AES-256, 32bytes)"]
    A_PW["ユーザー A のパスワード"]
    B_PW["ユーザー B のパスワード"]
    A_DK["Argon2id(64MB, 3回)<br/>→ 導出鍵 DK_A"]
    B_DK["Argon2id(64MB, 3回)<br/>→ 導出鍵 DK_B"]
    A_WK["AES-GCM(DK_A, K)<br/>→ wrapped_K_A"]
    B_WK["AES-GCM(DK_B, K)<br/>→ wrapped_K_B"]
    A_SV["サーバー保存:<br/>wrapped_K_A, salt_A, nonce_A"]
    B_SV["サーバー保存:<br/>wrapped_K_B, salt_B, nonce_B"]

    K --> A_PW & B_PW
    A_PW --> A_DK --> A_WK --> A_SV
    B_PW --> B_DK --> B_WK --> B_SV
```

- サーバーは暗号文とラップ済み鍵のみを保持し、平文の鍵 K やパスワードには一切アクセスできない
- デバイスローカルでは `flutter_secure_storage` に鍵をキャッシュし、毎回のパスワード入力を不要にする

### 鍵交換の全体フロー

サインアップからリンク完了、日常利用までの完全なシーケンス:

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
    A->>A: fp = SHA-256(A_pub || B_pub) → 6桁x4組
    B->>B: fp = SHA-256(A_pub || B_pub) → 6桁x4組
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

### 鍵復元フロー (アプリ再起動時)

```mermaid
flowchart TD
    Start[アプリ起動] --> CheckMem{メモリに鍵あり?}
    CheckMem -->|Yes| Done[アンロック不要]
    CheckMem -->|No| CheckLocal{ローカルキャッシュ<br/>に鍵あり?}
    CheckLocal -->|Yes| Restore[キャッシュから復元]
    Restore --> Done
    CheckLocal -->|No| CheckServer{サーバーに<br/>ラップ鍵あり?}
    CheckServer -->|Yes| Unlock[/encryption-unlock<br/>パスワード入力/]
    Unlock --> Unwrap[Argon2id → アンラップ]
    Unwrap --> Done
    CheckServer -->|No| NoKey[暗号化未設定]
```

### クラッシュ耐性 (再暗号化)

```mermaid
sequenceDiagram
    participant App as アプリ
    participant SS as SecureStorage
    participant DB as Supabase

    App->>SS: savePendingOldKey(pid, oldKey)
    Note right of SS: 旧鍵を保持

    App->>SS: saveReceivedKey(pid, newKey)
    Note right of SS: 新鍵でメモリ+キャッシュ更新

    loop 各 expense
        App->>App: decrypt(oldKey) → encrypt(newKey)
        App->>DB: UPDATE encrypted_data
    end

    App->>SS: clearPendingOldKey(pid)
    Note right of SS: 旧鍵を安全に削除

    Note over App,DB: クラッシュ時: 起動後に<br/>getPendingOldKey() で再開
```

---

## 認証・ルーティングの状態機械

### ルーターリダイレクト

`router_redirect.dart` は純粋関数で、以下の優先順位でリダイレクトを決定する:

```mermaid
flowchart TD
    Start[リクエスト] --> LoggedIn{ログイン済み?}
    LoggedIn -->|No| SignIn[→ /sign-in]
    LoggedIn -->|Yes| ProfileLoading{プロフィール<br/>読込中?}
    ProfileLoading -->|Yes| Stay1[そのまま待機]
    ProfileLoading -->|No| HasProfile{プロフィール<br/>あり?}
    HasProfile -->|No| Setup[→ /profile-setup]
    HasProfile -->|Yes| EncLoading{暗号化<br/>チェック中?}
    EncLoading -->|Yes| Stay2[そのまま待機]
    EncLoading -->|No| NeedUnlock{暗号化<br/>アンロック必要?}
    NeedUnlock -->|Yes| Unlock[→ /encryption-unlock]
    NeedUnlock -->|No| OnLoading{/loading に<br/>いる?}
    OnLoading -->|Yes| Home[→ /home]
    OnLoading -->|No| OnAuth{認証ルートに<br/>いる?}
    OnAuth -->|Yes| Home
    OnAuth -->|No| NoRedirect[リダイレクトなし]
```

### GoRouter のリフレッシュ戦略

```dart
// NG: ref.watch → GoRouter 再構築 → ナビゲーションリセット
final goRouter = GoRouter(...); // 毎回新しいインスタンス

// OK: ref.listen + refreshListenable → GoRouter は1つのインスタンスを維持
final refreshNotifier = ValueNotifier<int>(0);
ref.listen(authStateChangesProvider, (_, __) => refreshNotifier.value++);
GoRouter(refreshListenable: refreshNotifier, ...);
```

プロフィール読込のリフレッシュは `loading → data/error` 遷移のみでトリガーし、
`invalidate` による `data → loading` ではトリガーしない（進行中のナビゲーションをキャンセルしないため）。

---

## データベース設計

### テーブル関係

```mermaid
erDiagram
    profiles ||--o{ partnerships : "user1_id"
    profiles ||--o{ partnerships : "user2_id (nullable)"
    partnerships ||--o{ categories : "CASCADE"
    partnerships ||--o{ expenses : "CASCADE"
    partnerships ||--o{ encryption_keys : "CASCADE"
    profiles ||--o{ expenses : "paid_by"
    profiles ||--o{ encryption_keys : "user_id CASCADE"

    profiles {
        uuid id PK
        text display_name
        int icon_id
        timestamptz created_at
        timestamptz updated_at
    }

    partnerships {
        uuid id PK
        uuid user1_id FK
        uuid user2_id FK "nullable"
        text status "pending/active/archived"
        text user1_ecdh_pub "nullable"
        text user2_ecdh_pub "nullable"
        text wrapped_partnership_key "nullable"
        timestamptz created_at
    }

    categories {
        uuid id PK
        uuid partnership_id FK
        text name
        int sort_order
    }

    expenses {
        uuid id PK
        uuid partnership_id FK
        uuid paid_by FK
        date date
        text encrypted_data "AES-256-GCM暗号文"
        timestamptz created_at
    }

    encryption_keys {
        uuid id PK
        uuid partnership_id FK
        uuid user_id FK
        text wrapped_key "Argon2idラップ鍵"
        text key_salt
        text key_nonce
    }
```

### RLS (Row Level Security)

全テーブルで RLS が有効。主なポリシー:

- **profiles**: 自分のプロフィールのみ CRUD 可能。パートナーのプロフィールは読み取りのみ
- **partnerships**: 自分が user1 または user2 のものだけ参照・更新可能。pending のパートナーシップは認証済みユーザーなら join 可能
- **expenses / categories**: パートナーシップのメンバーのみ CRUD 可能
- **encryption_keys**: 自分のキーのみ CRUD 可能

### アカウント削除

`delete_user_data` RPC は `SECURITY DEFINER` で RLS をバイパスし、FK 安全な順序でデータを削除:

```mermaid
flowchart LR
    A[DELETE expenses] --> B[ARCHIVE partnerships]
    B --> C[DELETE categories]
    C --> D[DELETE partnerships]
    D --> E[DELETE profile]
```

---

## 支払いデータのフロー

### 入力 → 暗号化 → 保存

```mermaid
sequenceDiagram
    participant UI as ExpenseInputPage
    participant Repo as ExpenseRepository
    participant Enc as EncryptionService
    participant DB as Supabase

    UI->>Repo: addExpense(Expense)
    Repo->>Repo: UUID 事前生成 (AAD に必要)
    Repo->>Enc: encryptExpenseFields(amount, currency, ratio, category, memo)
    Note right of Enc: AAD = "expenseId:partnershipId"
    Enc-->>Repo: encrypted_data (base64)
    Repo->>DB: INSERT (id, partnership_id, paid_by, date, encrypted_data)
```

### 取得 → 復号 → 表示

```mermaid
sequenceDiagram
    participant DB as Supabase
    participant Repo as ExpenseRepository
    participant Enc as EncryptionService
    participant UI as Page

    DB-->>Repo: { id, partnership_id, paid_by, date, encrypted_data }
    Repo->>Enc: decryptExpenseFields(encrypted_data, key, expenseId, partnershipId)
    Enc-->>Repo: { amount, currency, ratio, category, memo }
    Repo-->>UI: Expense オブジェクト (平文)
```

### 残高計算

```mermaid
flowchart LR
    A[全 expenses 復号] --> B["各行を { paid_by, amount, ratio } に変換"]
    B --> C[calculateBalance]
    C --> D["int<br/>正: 相手が借り / 負: 自分が借り"]
```

計算ロジック: 自分が払った → `+amount*(1-ratio)`, 相手が払った → `-amount*(1-ratio)`

---

## 画面遷移フロー

### 初回セットアップ

```mermaid
flowchart LR
    Loading[/loading/] --> SignIn[/sign-in/]
    SignIn --> Profile[/profile-setup/]
    Profile --> Home1[/home/<br/>未リンク状態]
    Home1 -->|リンクはこちら| Invite[/invite/]
    Invite --> EncSetup[/encryption-setup/<br/>パスワード設定]
    EncSetup --> Invite2[/invite/<br/>QR表示+待機]
    Invite2 -->|パートナーがQRスキャン| FP[/fingerprint-verification/<br/>双方で確認]
    FP --> Home2[/home/<br/>リンク完了]
```

### アプリ再起動

```mermaid
flowchart TD
    Start[/loading/] --> HasCache{ローカルキャッシュ<br/>に鍵あり?}
    HasCache -->|Yes| Home[/home/]
    HasCache -->|No| HasServer{サーバーに<br/>ラップ鍵あり?}
    HasServer -->|Yes| Unlock[/encryption-unlock/]
    Unlock --> Home
    HasServer -->|No, 未ログイン| SignIn[/sign-in/]
```

### メイン画面 (4タブ)

```mermaid
flowchart TD
    Shell[MainShell<br/>BottomNavigationBar]
    Shell --> Home["/home<br/>ダッシュボード<br/>(残高, カテゴリ, 直近履歴)"]
    Shell --> Stats["/stats<br/>カテゴリ別月次チャート"]
    Shell --> History["/history<br/>全履歴<br/>(ページネーション, マルチセレクト)"]
    Shell --> Settings["/settings<br/>各種設定"]

    Stats --> CatDetail["/stats/category-detail"]
    History --> Detail["/history/:id<br/>詳細, 編集, 削除"]
    Settings --> ProfileEdit["/settings/profile-edit"]
    Settings --> CatEdit["/settings/category-edit"]
    Settings --> PartnerManage["/settings/partnership"]
    Settings --> EncSettings["/settings/encryption"]
```

---

## プロバイダー依存グラフ

```mermaid
graph TD
    Auth["authStateChangesProvider<br/>(Stream)"]
    User["currentUserProvider<br/>(User?)"]
    Profile["currentProfileProvider<br/>(AsyncValue&lt;Profile?&gt;)"]
    Partnership["currentPartnershipProvider<br/>(AsyncValue&lt;Partnership?&gt;)"]
    Active["activePartnershipProvider<br/>(AsyncValue&lt;Partnership?&gt;)"]
    Partner["partnerProfileProvider<br/>(AsyncValue&lt;Profile?&gt;)"]
    Categories["categoriesProvider<br/>(AsyncValue&lt;List&lt;Category&gt;&gt;)"]
    Unlock["encryptionUnlockRequiredProvider<br/>(AsyncValue&lt;bool&gt;)"]
    EncKey["encryptionKeyNotifierProvider<br/>(keepAlive, Uint8List?)"]
    ExpRepo["expenseRepositoryProvider<br/>(鍵注入)"]
    Recent["recentExpensesProvider"]
    ExpDetail["expenseDetailProvider(id)"]
    Balance["balanceSummaryProvider"]
    CatBreak["categoryBreakdownProvider"]
    Version["expenseDataVersionProvider<br/>(StateProvider&lt;int&gt;)"]

    Auth --> User
    User --> Profile
    User --> Partnership
    Partnership --> Active
    Active --> Partner
    Partnership --> Categories
    Partnership --> Unlock
    EncKey --> Unlock
    EncKey --> ExpRepo
    ExpRepo --> Recent
    ExpRepo --> ExpDetail
    ExpRepo --> Balance
    ExpRepo --> CatBreak
    Version -.->|手動リフレッシュ| Recent
```

**`keepAlive: true`** は `EncryptionKeyNotifier` のみに適用。他のプロバイダーは `autoDispose` で、画面遷移時にメモリから解放される。

---

## コード生成

以下のコマンドでモデルとプロバイダーのコードを再生成する:

```bash
dart run build_runner build --delete-conflicting-outputs
```

生成されるファイル:

- `*.freezed.dart` — Freezed モデルの `copyWith`, `==`, `hashCode`, `toString`
- `*.g.dart` — JSON シリアライズ (`fromJson`/`toJson`) + Riverpod プロバイダー定義

`@riverpod` アノテーションから `*Provider` が生成される。手動で `Provider` クラスを書く必要はない。

---

## ビルドと実行

### 環境変数

`.env` ファイルに以下を定義:

```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
```

### デバッグビルド

```bash
flutter run --dart-define-from-file=.env
```

### リリースビルド (APK)

```bash
flutter build apk --release --dart-define-from-file=.env
```

### adb インストール

```bash
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## マイグレーション管理

Supabase CLI を使用。マイグレーションファイルは `supabase/migrations/` に SQL で管理。

### 新規マイグレーション

```bash
npx supabase migration new <名前>    # ファイル作成
# SQL を記述
npx supabase db push                 # リモートに適用
```

### 後方互換性ルール

- カラム追加は必ず `DEFAULT` または `NULL` 許容
- カラム削除・名前変更は行わない
- NOT NULL カラム追加時は必ず `DEFAULT` をつける
- テーブル追加は旧クライアントに影響しないため安全

---

## テスト

### テスト方針

- **純粋関数テスト**: `flutter_test` のみ使用。モッキングフレームワーク不使用
- **構造テスト**: ソースファイルを `dart:io` で読み、コードパターンの存在を `contains` / `indexOf` で検証

### テスト実行

```bash
flutter test
```

### テストファイル一覧

| ファイル                               | 種別     | テスト内容                              |
| -------------------------------------- | -------- | --------------------------------------- |
| `router_redirect_test.dart`            | 純粋関数 | ルーターリダイレクト状態機械 (36テスト) |
| `balance_calculation_test.dart`        | 純粋関数 | 残高計算 (各割合, エッジケース)         |
| `expense_stats_test.dart`              | 純粋関数 | 月次集計・カテゴリ集計                  |
| `encryption_service_test.dart`         | 純粋関数 | 暗号化ラウンドトリップ, AAD検証         |
| `csv_service_test.dart`                | 純粋関数 | CSV パース, バリデーション              |
| `formatters_test.dart`                 | 純粋関数 | フォーマッター                          |
| `reorder_test.dart`                    | 純粋関数 | リスト並び替え                          |
| `self_join_guard_test.dart`            | 構造     | セルフジョインガード                    |
| `fingerprint_race_guard_test.dart`     | 構造     | レースコンディションガード              |
| `bulk_delete_safety_test.dart`         | 構造     | 一括削除エラー処理                      |
| `reencrypt_key_preservation_test.dart` | 構造     | 再暗号化時の旧鍵保持                    |
| `csv_duplicate_detection_test.dart`    | 構造     | CSV 重複検知                            |
