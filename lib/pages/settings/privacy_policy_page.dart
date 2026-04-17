import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('プライバシーポリシー', style: theme.textTheme.displayMedium),
          const SizedBox(height: 4),
          Text('最終更新日: 2026年4月17日',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          _section(theme, '1. はじめに',
              'Seppan（以下「本アプリ」）は、2人のパートナー間での割り勘・立て替え管理を目的とした個人開発アプリです。'
              '本アプリをご利用いただくにあたり、以下のプライバシーポリシーをご確認ください。'),
          _section(theme, '2. 収集する情報',
              '本アプリでは、以下の情報を収集・保存します。\n\n'
              '- アカウント情報: メールアドレスまたはGoogleアカウント、Appleアカウントの認証情報\n'
              '- プロフィール情報: 表示名、アバターアイコンの選択\n'
              '- 支払い情報: 金額、日付、カテゴリ、メモ、支払者、負担割合（エンドツーエンド暗号化された状態で保存）\n'
              '- パートナーシップ情報: リンク状態、暗号化された鍵情報'),
          _section(theme, '3. エンドツーエンド暗号化',
              '本アプリでは、支出データをエンドツーエンド（E2E）暗号化して保護しています。\n\n'
              '- 金額、カテゴリ、メモなどの機密データはAES-256-GCMで暗号化され、サーバーには暗号文のみが保存されます\n'
              '- 暗号化鍵はユーザーが設定したパスワードで保護されます（Argon2idによる鍵導出）\n'
              '- パートナー間の鍵交換にはX25519 ECDHを使用し、フィンガープリント確認により中間者攻撃を検出します\n'
              '- サービス提供者を含む第三者が平文データにアクセスすることはできません\n'
              '- パスワードを紛失した場合、サービス提供者であってもデータを復元することはできません'),
          _section(theme, '4. 情報の利用目的',
              '収集した情報は、以下の目的でのみ使用します。\n\n'
              '- パートナー間の支出管理機能の提供\n'
              '- 残高計算および履歴の表示\n'
              '- ユーザー認証およびアカウント管理'),
          _section(theme, '5. 情報の共有',
              '本アプリでは、リンクされたパートナー間でのみ支払い情報が共有されます。'
              'パートナーとのデータ共有はE2E暗号化のもとで行われ、サーバーは暗号文を中継するのみです。'
              '第三者への情報提供、販売、広告目的での利用は一切行いません。'),
          _section(theme, '6. データの保存',
              'データはSupabase（クラウドサービス）上に保存されます。'
              '支出データはE2E暗号化されており、サーバー上では暗号文のみが存在します。'
              'データベースへのアクセスはRow Level Security（RLS）により、'
              '本人およびリンクされたパートナーのみに制限されています。'),
          _section(theme, '7. データのエクスポート',
              '本アプリでは、ユーザー自身の操作により、支払い履歴をCSVファイルとしてエクスポートすることができます。\n\n'
              '⚠ エクスポートされたCSVファイルは暗号化されていない平文です。'
              '金額、カテゴリ、メモ、パートナーの名前などが含まれますので、'
              '保存場所および共有先には十分ご注意ください。'),
          _section(theme, '8. データの削除',
              'ユーザーはいつでもアプリ内の「設定」>「アカウント削除」から、'
              'すべてのデータを削除することができます。'
              'アカウント削除を実行すると、プロフィール情報、支払い履歴、暗号化鍵情報、'
              'パートナーシップ情報がすべて消去されます。'
              'パートナーとのリンクは自動的に解除され、リンク相手があなたの代わりに入力した履歴もすべて削除されます。'
              'この操作は取り消すことができません。'),
          _section(theme, '9. 分析ツール',
              '本アプリでは、アプリの利用状況を把握し機能改善に役立てるため、'
              'Firebase Analytics（Google LLC 提供）を使用しています。\n\n'
              '収集する情報:\n'
              '- 画面遷移の履歴（どの画面を閲覧したか）\n'
              '- デバイス情報（OS、機種、アプリバージョン）\n'
              '- 概算地域情報（IPアドレスベースの国・地域レベル）\n'
              '- アプリの利用頻度・利用時間\n\n'
              '収集される情報には、支払い金額やカテゴリ、メモ等の個人的なデータは一切含まれません。\n'
              'Firebase Analytics のデータはGoogle LLCのプライバシーポリシーに基づいて取り扱われます。\n\n'
              '本アプリでは、広告サービスは使用していません。'),
          _section(theme, '10. お子様のプライバシー',
              '本アプリは13歳未満のお子様を対象としておらず、'
              '13歳未満の方から意図的に個人情報を収集することはありません。'),
          _section(theme, '11. ポリシーの変更',
              '本ポリシーは予告なく変更される場合があります。'
              '重要な変更がある場合は、アプリ内でお知らせします。'),
          _section(theme, '12. お問い合わせ',
              '本ポリシーに関するご質問は、下記メールアドレスまでお問い合わせください。\n\n'
              'seppan-support@yayo1.com'),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _section(ThemeData theme, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(body, style: theme.textTheme.bodyMedium),
        ],
      ),
    );
  }
}
