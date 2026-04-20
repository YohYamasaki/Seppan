import 'package:flutter/material.dart';

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('利用規約')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('利用規約', style: theme.textTheme.displayMedium),
          const SizedBox(height: 4),
          Text('最終更新日: 2026年4月16日', style: theme.textTheme.bodySmall),
          const SizedBox(height: 24),
          _section(
            theme,
            '1. 本規約について',
            '本利用規約（以下「本規約」）は、Seppan（以下「本アプリ」）の利用条件を定めるものです。'
                '本アプリをインストールまたは使用することにより、本規約に同意したものとみなします。',
          ),
          _section(
            theme,
            '2. サービス内容',
            '本アプリは、2人のパートナー間での割り勘・立て替え管理を目的としたアプリです。'
                '支払い情報の記録、残高の計算、履歴の閲覧などの機能を提供します。',
          ),
          _section(
            theme,
            '3. アカウント',
            '本アプリの利用にはアカウント登録が必要です。'
                'ユーザーはアカウント情報の管理について責任を負います。'
                'アカウントの不正利用を発見した場合は、速やかにご連絡ください。',
          ),
          _section(
            theme,
            '4. 利用上の注意',
            'ユーザーは以下の行為を行ってはなりません。\n\n'
                '- 法令または公序良俗に違反する行為\n'
                '- 本アプリのサーバーやネットワークに過度な負荷をかける行為\n'
                '- 本アプリのリバースエンジニアリング、逆コンパイル、逆アセンブル\n'
                '- 他のユーザーの利用を妨害する行為\n'
                '- その他、開発者が不適切と判断する行為',
          ),
          _section(
            theme,
            '5. データと暗号化',
            '本アプリはエンドツーエンド暗号化を採用しています。'
                '暗号化パスワードを紛失した場合、データの復旧はできません。'
                'パスワードの管理はユーザーの責任となります。',
          ),
          _section(
            theme,
            '6. 免責事項',
            '本アプリは個人開発によるもので、「現状のまま」提供されます。\n\n'
                '- 本アプリの完全性、正確性、信頼性について保証しません\n'
                '- サービスの中断、変更、終了が発生する場合があります\n'
                '- 本アプリの利用により生じた損害について、法令で許容される範囲で責任を負いません\n'
                '- 金額の計算結果は参考値であり、最終的な確認はユーザーの責任で行ってください',
          ),
          _section(theme, '7. 知的財産権', '本アプリに関するすべての知的財産権は開発者に帰属します。'),
          _section(
            theme,
            '8. 規約の変更',
            '開発者は本規約を変更する場合があります。'
                '重要な変更がある場合は、アプリ内でお知らせします。'
                '変更後も本アプリを継続して利用する場合、変更後の規約に同意したものとみなします。',
          ),
          _section(
            theme,
            '9. 準拠法・管轄',
            '本規約は日本法に準拠し、紛争が生じた場合は東京地方裁判所を第一審の専属的合意管轄裁判所とします。',
          ),
          _section(
            theme,
            '10. お問い合わせ',
            '本規約に関するご質問は、下記メールアドレスまでお問い合わせください。\n\n'
                'yohei.yamasaki.yayo1@gmail.com',
          ),
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
