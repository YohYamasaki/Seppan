# Seppan

## プロジェクト概要

2人のパートナー間での割り勘・立て替え管理アプリ。旧版「Seppa」（/Users/yoheiyamasaki/Documents/repositories/seppa）をゼロから作り直すプロジェクト。

### ターゲット

- Android（メイン）、将来的に iOS にも展開
- 日本円のみ対応（将来の複数通貨対応を見据え、currency カラムは確保）

## サポートの指針

- このプロジェクトは学習目的のため、プロダクションレベルの品質が求められるものではない
- 実際のコーディングはユーザーが手動で行う。明示的に指示されるまで、ファイルの変更・追加・削除は行わないこと
- ユーザーの実装上の質問に対して噛み砕いて分かりやすく解説することを第一目標とする

## 技術スタック

| レイヤー | 選定 | 備考 |
|---|---|---|
| フレームワーク | Flutter | |
| バックエンド | Supabase | PostgreSQL、認証、Realtime、RLS |
| 状態管理 | Riverpod 3.0 | コード生成（riverpod_generator）、コンパイル時安全性 |
| データモデル | Freezed | イミュータブルモデル + JSON変換 |
| ルーティング | go_router | 宣言的ルーティング、ディープリンク対応 |
| E2E暗号化 | cryptography + flutter_secure_storage | AES-256-GCM、X25519 ECDH、Argon2id |
| QRコード | mobile_scanner + qr_flutter | |
| チャート | fl_chart | カテゴリ別集計の可視化 |

## 機能要件

### 認証・アカウント管理
- サインアップ / ログイン: Google、Apple（iOSのみ）、メール（OTP）
- ユーザープロフィール: 名前、アバターアイコン（プリセット選択）
- ログアウト、ユーザーデータ削除（RPC経由）

### パートナーリンク（ペアリング）
- パートナーシップ作成時に6桁の invite_code を自動生成（有効期限付き）
- QRコード表示 or 手入力でリンク
- Supabase Realtime でリンク待機をリアルタイム監視

### E2E暗号化（End-to-End Encryption）
- 支払いデータ（金額、通貨、負担率、カテゴリ、メモ）をクライアント側で暗号化してからSupabaseに保存
- サーバー側では暗号文のみ保持し、平文データにはアクセス不可

#### 暗号化アーキテクチャ
- **AES-256-GCM**: 支払いフィールドの暗号化（AAD: `expenseId:partnershipId`）
- **X25519 ECDH**: パートナー間の鍵交換プロトコル
- **Argon2id**: パスワードベースの鍵導出（65MB, 3 iterations）
- **HKDF-SHA256**: 共有秘密鍵からの鍵導出

#### 鍵交換フロー
1. パートナーシップ作成者が AES-256 パートナーシップ鍵を生成
2. 双方が X25519 ECDH 公開鍵を交換
3. 共有秘密鍵から同一のラッピング鍵を導出
4. 作成者側がパートナーシップ鍵を共有秘密鍵でラップして送信
5. 参加者側がアンラップし、フィンガープリント（6桁グループ）で検証
6. 双方のパスワードでラップしてサーバーに長期保存

#### 鍵管理
- flutter_secure_storage によるローカルキャッシュ（オフラインアクセス）
- パスワードロック解除（起動時）
- パートナーシップ間の鍵マイグレーション
- 鍵ローテーション時のデータ再暗号化

### 支払い入力
- 金額（必須）、日付、支払者（user1/user2 選択）、負担率（0%/25%/50%/75%/100%）
- カテゴリ（カスタマイズ可能）、メモ（任意）
- 入力時にクライアント側で暗号化し、encrypted_data カラムに base64 で保存

### メインページ（ダッシュボード）
- 残高サマリーカード: 双方向の差額メッセージ
- 直近の履歴プレビュー
- Pull-to-refresh

### 統計ページ
- 月別カテゴリ集計チャート（fl_chart）
- カテゴリ別詳細ページ（月指定）

### 履歴
- 支払い履歴の一覧（新しい順、遅延読み込み）
- 詳細表示・編集・削除

### 設定
- プロフィール編集、カテゴリ編集
- パートナーシップ管理（リンク解除含む）
- 暗号化設定（暗号化状態・鍵情報の確認）
- プライバシーポリシー
- アカウント削除

### 不要な機能
- 広告（旧版にあったが廃止）

## データベース設計（Supabase / PostgreSQL）

### テーブル構成

```
profiles
  id (UUID, = supabase auth.uid)
  display_name (TEXT)
  icon_id (INT)
  created_at (TIMESTAMPTZ)
  updated_at (TIMESTAMPTZ)

partnerships
  id (UUID)
  user1_id (UUID FK → profiles.id)
  user2_id (UUID FK → profiles.id, NULLABLE)
  invite_code (TEXT, UNIQUE)
  status (TEXT: 'pending' | 'active' | 'archived')
  user1_ecdh_pub (TEXT, NULLABLE)      -- X25519 ECDH 公開鍵（user1）
  user2_ecdh_pub (TEXT, NULLABLE)      -- X25519 ECDH 公開鍵（user2）
  wrapped_partnership_key (TEXT, NULLABLE) -- ECDH共有秘密鍵でラップされたパートナーシップ鍵
  created_at (TIMESTAMPTZ)

categories
  id (UUID)
  partnership_id (UUID FK → partnerships.id)
  name (TEXT)
  sort_order (INT)

expenses
  id (UUID)
  partnership_id (UUID FK → partnerships.id)
  paid_by (UUID FK → profiles.id)
  date (DATE)
  encrypted_data (TEXT)                -- AES-256-GCM暗号化された支払いデータ（base64）
  created_at (TIMESTAMPTZ)
  -- 暗号化対象フィールド: amount, currency, ratio, category, memo
  -- 平文フィールド: id, partnership_id, paid_by, date, created_at

encryption_keys
  partnership_id (UUID FK → partnerships.id)
  user_id (UUID FK → profiles.id)
  wrapped_key (TEXT)                   -- パスワード(Argon2id)でラップされたAES鍵
  key_salt (TEXT)                      -- Argon2id ソルト
  key_nonce (TEXT)                     -- AES-GCM ナンス
```

### 設計方針
- 累計金額はカラムに持たず、expenses から常にクエリで算出する（データ整合性を担保）
- ユーザー情報は profiles テーブルで正規化（旧版の user1/user2 フィールド重複を解消）
- RLS でペア内のデータアクセスを DB レベルで制御
- E2E暗号化により、サーバー側では平文の金額・カテゴリ等にアクセス不可

### マイグレーション方針

- スキーマ管理は Supabase CLI を使用（`supabase/migrations/` に SQL ファイルで管理）
- マイグレーションワークフロー:
  1. `npx supabase migration new <名前>` でファイル作成
  2. SQL を記述
  3. `npx supabase db push` でリモートに適用
- **後方互換性**: 古いクライアント + 新しいサーバーの組み合わせを考慮する
  - カラム追加は必ず `DEFAULT` または `NULL` 許容にする
  - カラム削除・名前変更は行わない（やむを得ない場合は、新カラム追加 → 移行 → 旧カラム削除の3段階で）
  - NOT NULL カラム追加時は必ず `DEFAULT` をつける
  - テーブル追加は旧クライアントに影響しないため安全

## 画面構成

```
認証フロー:
  SignInPage → (EmailAuthPage) → ProfileSetupPage → InvitePage（ペアリング待ち）

暗号化フロー:
  FingerprintVerificationPage  — ECDH鍵交換のフィンガープリント検証
  EncryptionSetupPage          — パスワード設定（新規パートナーシップ）
  EncryptionUnlockPage         — パスワード入力（起動時のロック解除）

メインフロー（BottomNavigationBar 4タブ）:
  HomePage       — 残高サマリー + 直近履歴 + 支払入力FAB
  StatsPage      — 月別カテゴリ集計チャート → CategoryDetailPage
  HistoryPage    — 全履歴一覧 → HistoryDetailPage（詳細・編集）
  SettingsPage   — プロフィール / カテゴリ / パートナーシップ / 暗号化設定 / プライバシーポリシー / アカウント削除
```

## ディレクトリ構成

```
lib/
├── main.dart
├── app.dart
├── config/
│   ├── supabase.dart
│   ├── theme.dart
│   └── router.dart
├── models/
│   ├── profile.dart
│   ├── partnership.dart          -- ECDH公開鍵・ラップ鍵フィールド含む
│   ├── expense.dart
│   └── category.dart
├── services/
│   └── encryption_service.dart   -- AES-GCM, ECDH, Argon2id, HKDF 暗号操作
├── repositories/
│   ├── auth_repository.dart
│   ├── profile_repository.dart
│   ├── partnership_repository.dart
│   ├── expense_repository.dart   -- 暗号化/復号処理含む
│   └── encryption_key_repository.dart -- ラップ鍵のCRUD
├── providers/
│   ├── auth_provider.dart
│   ├── partnership_provider.dart
│   ├── expense_provider.dart
│   ├── balance_provider.dart     -- 残高計算 + カテゴリ集計
│   └── encryption_provider.dart  -- 暗号化鍵状態管理（EncryptionKeyNotifier）
├── pages/
│   ├── auth/
│   │   ├── sign_in_page.dart
│   │   ├── email_auth_page.dart
│   │   ├── profile_setup_page.dart
│   │   ├── invite_page.dart
│   │   ├── qr_scanner_page.dart
│   │   ├── fingerprint_verification_page.dart
│   │   ├── encryption_setup_page.dart
│   │   └── encryption_unlock_page.dart
│   ├── home/
│   ├── stats/
│   │   ├── stats_page.dart
│   │   └── category_detail_page.dart
│   ├── history/
│   │   ├── history_page.dart
│   │   └── history_detail_page.dart
│   ├── expense_input/
│   ├── settings/
│   │   ├── settings_page.dart
│   │   ├── profile_edit_page.dart
│   │   ├── category_edit_page.dart
│   │   ├── partnership_manage_page.dart
│   │   ├── privacy_policy_page.dart
│   │   └── encryption_settings_page.dart
│   └── shell/
│       └── main_shell.dart       -- BottomNavigationBar 4タブ
├── utils/
│   ├── router_redirect.dart      -- 認証フロー状態機械（純粋関数）
│   ├── balance.dart              -- 残高計算ロジック
│   ├── expense_stats.dart        -- 月別集計・カテゴリ集計
│   ├── formatters.dart           -- 日付・通貨フォーマット
│   └── reorder.dart              -- カテゴリ並び替え
└── widgets/
    ├── balance_card.dart
    ├── main_card.dart
    ├── monthly_summary_card.dart
    ├── expense_tile.dart
    ├── category_chart_card.dart
    ├── avatar_icon.dart
    ├── main_button.dart
    └── ratio_bar.dart
```

## 旧版との対応

旧版のソースコードは /Users/yoheiyamasaki/Documents/repositories/seppa にある。旧版の機能や挙動について確認が必要な場合はそちらを参照すること。
