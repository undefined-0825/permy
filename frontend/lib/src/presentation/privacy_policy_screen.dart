import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('プライバシーポリシー')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MetaRow(label: '最終更新日', value: '2026年3月7日'),
            SizedBox(height: 16),
            _SectionTitle('1. 基本方針'),
            _BodyText(
              'Permy（以下「本サービス」）は、利用者のプライバシーを尊重し、取得する情報を必要最小限に限定します。特に、LINEトーク履歴本文および生成本文は永続保存しません。',
            ),
            SizedBox(height: 12),
            _SectionTitle('2. 取得する情報'),
            _BulletText('匿名認証用のユーザー識別子（user_id）'),
            _BulletText('アプリ設定情報（例：NGタグ、診断タイプ、生成方針）'),
            _BulletText('利用状況のメタデータ（例：イベント種別、アプリバージョン、OS、エラーコード）'),
            SizedBox(height: 8),
            _BodyText('上記には、会話本文・生成本文そのものは含みません。'),
            SizedBox(height: 12),
            _SectionTitle('3. 保存しない情報（重要）'),
            _BulletText('LINEトーク履歴本文'),
            _BulletText('AIが生成した返信本文'),
            _BulletText('本文を復元可能な派生データ（要約・特徴量等）'),
            SizedBox(height: 12),
            _SectionTitle('4. 利用目的'),
            _BulletText('本サービス機能の提供（返信案生成、設定同期、端末移行）'),
            _BulletText('障害対応および品質改善（本文を含まない範囲）'),
            _BulletText('利用状況分析（本文を含まない統計情報）'),
            SizedBox(height: 12),
            _SectionTitle('5. 第三者提供'),
            _BodyText(
              '法令に基づく場合を除き、運営者は個人データを第三者へ提供しません。外部サービスを利用する場合も、本文非保存ポリシーを維持する範囲でのみ利用します。',
            ),
            SizedBox(height: 12),
            _SectionTitle('6. 安全管理'),
            _BulletText('通信は暗号化（HTTPS）を前提とします。'),
            _BulletText('トークンは端末のセキュアストレージに保存します。'),
            _BulletText('ログには本文を含めません。'),
            SizedBox(height: 12),
            _SectionTitle('7. 保有期間'),
            _BodyText(
              '設定情報・認証情報・運用上必要なログは、法令およびサービス運営上必要な期間のみ保持し、不要となった情報は適切に削除します。',
            ),
            SizedBox(height: 12),
            _SectionTitle('8. 利用者の権利'),
            _BodyText(
              '利用者は、法令の範囲で自己情報に関する開示・訂正・利用停止等を求めることができます。手続きは下記連絡先へお問い合わせください。',
            ),
            SizedBox(height: 12),
            _SectionTitle('9. ポリシー変更'),
            _BodyText('本ポリシーは必要に応じて改定されます。重要な変更はアプリ内または適切な方法で通知します。'),
            SizedBox(height: 20),
            Divider(),
            SizedBox(height: 12),
            _BodyText('運営者：隙間産業ラボ 中野家'),
            _BodyText('連絡先：sukima.lab.nakanoya@gmail.com'),
          ],
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label：', style: const TextStyle(fontWeight: FontWeight.w600)),
        Text(value),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(height: 1.6));
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('・$text', style: const TextStyle(height: 1.6)),
    );
  }
}
