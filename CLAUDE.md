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
| 状態管理 | Riverpod 3.0 | コード生成、コンパイル時安全性 |
| データモデル | Freezed | イミュータブルモデル + JSON変換 |
| ルーティング | go_router | 宣言的ルーティング、ディープリンク対応 |
| QRコード | mobile_scanner + qr_flutter | |

## 機能要件

### 認証・アカウント管理
- サインアップ / ログイン: Google、Apple（iOSのみ）、電話番号（SMS OTP）
- ユーザープロフィール: 名前、アバターアイコン（プリセット選択）
- ログアウト、ユーザーデータ削除

### パートナーリンク（ペアリング）
- パートナーシップ作成時に6桁の invite_code を自動生成（有効期限付き）
- QRコード表示 or 手入力でリンク
- Supabase Realtime でリンク待機をリアルタイム監視

### 支払い入力
- 金額（必須）、日付、支払者（user1/user2 選択）、負担率（0%/25%/50%/75%/100%）
- カテゴリ（カスタマイズ可能）、メモ（任意）

### メインページ（ダッシュボード）
- 残高サマリーカード: 双方向の差額メッセージ
- 直近の履歴プレビュー
- Pull-to-refresh

### 履歴
- 支払い履歴の一覧（新しい順、遅延読み込み）
- 詳細表示、削除

### 設定
- プロフィール編集、カテゴリ編集
- パートナーシップ管理
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
  amount (NUMERIC)
  currency (TEXT, DEFAULT 'JPY')
  ratio (NUMERIC, 0.0〜1.0)
  date (DATE)
  category (TEXT)
  memo (TEXT)
  created_at (TIMESTAMPTZ)
```

### 設計方針
- 累計金額はカラムに持たず、expenses から常にクエリで算出する（データ整合性を担保）
- ユーザー情報は profiles テーブルで正規化（旧版の user1/user2 フィールド重複を解消）
- RLS でペア内のデータアクセスを DB レベルで制御

## 画面構成

```
認証フロー:
  SignInPage → ProfileSetupPage → InvitePage（ペアリング待ち）

メインフロー（BottomNavigationBar 3タブ）:
  HomePage       — 残高サマリー + 直近履歴 + 支払入力FAB
  HistoryPage    — 全履歴一覧
  SettingsPage   — プロフィール / カテゴリ / パートナーシップ管理 / アカウント削除
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
│   ├── partnership.dart
│   ├── expense.dart
│   └── category.dart
├── repositories/
│   ├── auth_repository.dart
│   ├── profile_repository.dart
│   ├── partnership_repository.dart
│   └── expense_repository.dart
├── providers/
│   ├── auth_provider.dart
│   ├── partnership_provider.dart
│   ├── expense_provider.dart
│   └── balance_provider.dart
├── pages/
│   ├── auth/
│   ├── home/
│   ├── history/
│   ├── expense_input/
│   └── settings/
└── widgets/
    ├── balance_card.dart
    ├── expense_tile.dart
    └── ...
```

## 旧版との対応

旧版のソースコードは /Users/yoheiyamasaki/Documents/repositories/seppa にある。旧版の機能や挙動について確認が必要な場合はそちらを参照すること。
