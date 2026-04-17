# Seppan

2人のパートナー間での割り勘・立て替え管理アプリ。支出データはエンドツーエンド暗号化（E2EE）で保護され、サーバーを含む第三者が平文データにアクセスすることはできません。

## 機能

- パートナー間の支出記録・割り勘計算
- カテゴリ別の支出管理・月次チャート
- QR コードによるパートナーリンク
- エンドツーエンド暗号化による支出データの保護
- 支出データのCSV エクスポート/インポート

## 技術構成

| レイヤー       | 技術                                                |
| -------------- | --------------------------------------------------- |
| フレームワーク | Flutter (Dart 3.11+)                                |
| バックエンド   | Supabase (PostgreSQL, Auth, Realtime, RLS)          |
| 状態管理       | Riverpod 3.0 + コード生成                           |
| データモデル   | Freezed + json_serializable                         |
| ルーティング   | go_router                                           |
| 暗号化         | cryptography (AES-256-GCM, Argon2id, X25519, HKDF)  |
| 鍵キャッシュ   | flutter_secure_storage                              |
| 認証           | Google Sign-In (ネイティブ), Apple (iOS), Email OTP |
| アナリティクス | Firebase Analytics                                  |
| チャート       | fl_chart                                            |

## セットアップ

### 前提条件

- Flutter SDK 3.11+
- Supabase プロジェクト
- Firebase プロジェクト（Analytics 用）

### 環境変数

`.env` ファイルをプロジェクトルートに作成:

```
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_ANON_KEY=eyJ...
GOOGLE_WEB_CLIENT_ID=xxx.apps.googleusercontent.com
```

### ビルド

```bash
# 依存関係のインストール
flutter pub get

# コード生成 (Freezed, Riverpod)
dart run build_runner build --delete-conflicting-outputs

# デバッグ実行
flutter run --dart-define-from-file=.env

# リリースビルド (APK)
flutter build apk --release --dart-define-from-file=.env
```

### データベース

Supabase CLI でマイグレーションを管理:

```bash
npx supabase db push    # マイグレーションをリモートに適用
```

## テスト

```bash
flutter test
```

## セキュリティ設計

支出の機密フィールド（金額、通貨、負担率、カテゴリ、メモ）はクライアント側で AES-256-GCM 暗号化され、サーバーには暗号文のみが保存されます。パートナー間の鍵共有は X25519 ECDH + フィンガープリント検証で行われ、パスワードによる鍵保護には Argon2id を使用しています。

詳しい暗号化フロー・鍵交換プロトコル・アーキテクチャについては **[開発者ガイド (develop.md)](develop.md)** を参照してください。
