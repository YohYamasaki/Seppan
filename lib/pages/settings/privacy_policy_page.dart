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
          Text('最終更新日: 2026年4月12日',
              style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          _section(theme, '1. はじめに',
              'Seppan（以下「本アプリ」）は、2人のパートナー間での割り勘・立て替え管理を目的とした個人開発アプリです。'
              '本アプリをご利用いただくにあたり、以下のプライバシーポリシーをご確認ください。'),
          _section(theme, '2. 収集する情報',
              '本アプリでは、以下の情報を収集・保存します。\n\n'
              '- アカウント情報: メールアドレスまたはGoogleアカウント、Appleアカウントの認証情報\n'
              '- プロフィール情報: 表示名、アバターアイコンの選択\n'
              '- 支払い情報: 金額、日付、カテゴリ、メモ、支払者、負担割合\n'
              '- パートナーシップ情報: 招待コード、リンク状態'),
          _section(theme, '3. 情報の利用目的',
              '収集した情報は、以下の目的でのみ使用します。\n\n'
              '- パートナー間の支出管理機能の提供\n'
              '- 残高計算および履歴の表示\n'
              '- ユーザー認証およびアカウント管理'),
          _section(theme, '4. 情報の共有',
              '本アプリでは、リンクされたパートナー間でのみ支払い情報が共有されます。'
              '第三者への情報提供、販売、広告目的での利用は一切行いません。'),
          _section(theme, '5. データの保存',
              'データはSupabase（クラウドサービス）上に安全に保存されます。'
              'データベースへのアクセスはRow Level Security（RLS）により、'
              '本人およびリンクされたパートナーのみに制限されています。'),
          _section(theme, '6. データの削除',
              'ユーザーはいつでもアプリ内の「設定」>「アカウント削除」から、'
              'すべてのデータを削除することができます。'
              'アカウント削除を実行すると、プロフィール情報、支払い履歴、'
              'パートナーシップ情報がすべて消去されます。'
              'この操作は取り消すことができません。'),
          _section(theme, '7. 分析・広告',
              '本アプリでは、サードパーティの分析ツールや広告サービスを使用していません。'),
          _section(theme, '8. お子様のプライバシー',
              '本アプリは13歳未満のお子様を対象としておらず、'
              '13歳未満の方から意図的に個人情報を収集することはありません。'),
          _section(theme, '9. ポリシーの変更',
              '本ポリシーは予告なく変更される場合があります。'
              '重要な変更がある場合は、アプリ内でお知らせします。'),
          _section(theme, '10. お問い合わせ',
              '本ポリシーに関するご質問は、アプリのサポートまでお問い合わせください。'),
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
