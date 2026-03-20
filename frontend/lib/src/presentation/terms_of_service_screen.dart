import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import 'widgets/support_email_link.dart';
import 'widgets/top_brand_header.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const TopBrandHeader(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('利用規約', style: AppTextStyles.primaryTitle),
            SizedBox(height: AppSpacing.md),
            _MetaRow(label: '最終更新日', value: '2026年3月'),
            SizedBox(height: AppSpacing.md),
            _BodyText(
              '本利用規約（以下「本規約」）は、隙間産業ラボ 中野家（以下「当社」）が提供するアプリ「Permy」（以下「本サービス」）の利用条件を定めるものです。ユーザーは本規約に同意したうえで本サービスを利用するものとします。',
            ),
            SizedBox(height: AppSpacing.md),
            _SectionTitle('第1条（適用）'),
            _BodyText('本規約は、本サービスの利用に関する一切の関係に適用されます。'),
            _BodyText('当社が本サービス内または別途提示するガイドライン・ポリシー等は、本規約の一部を構成します。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第2条（サービス内容）'),
            _BodyText('本サービスは、ユーザーが提供したテキスト情報をもとに、返信文の候補（A/B/C形式）を提案するツールです。'),
            _BodyText('本サービスは提案を行うものであり、送信や意思決定はユーザー自身が行うものとします。'),
            _BodyText('本サービスは特定の成果（売上・関係性改善等）を保証するものではありません。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第3条（利用条件）'),
            _BodyText('ユーザーは、日本国内において本サービスを利用するものとします。'),
            _BodyText('ユーザーは、自己の責任において本サービスを利用し、その結果について一切の責任を負います。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第4条（アカウント）'),
            _BodyText('本サービスは匿名IDにより利用を開始します。'),
            _BodyText('ユーザーは、自己の端末および認証情報を適切に管理する責任を負います。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第5条（課金・プラン）'),
            _BodyText('本サービスには無料プランおよび有料プランがあります。'),
            _BodyText('有料プランはサブスクリプション形式で提供され、料金および内容はアプリ内に表示されます。'),
            _BodyText('課金はAppleまたはGoogleのプラットフォームを通じて行われます。'),
            _BodyText('解約・変更は各ストアのサブスクリプション管理画面から行うものとします。'),
            _BodyText('購入済みコンテンツの復元機能を提供します。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第6条（禁止事項）'),
            _BodyText('ユーザーは以下の行為を行ってはなりません。'),
            _BulletText('法令または公序良俗に違反する行為'),
            _BulletText('他者の権利を侵害する行為'),
            _BulletText('本サービスの運営を妨害する行為'),
            _BulletText('不正アクセスやシステムへの攻撃行為'),
            _BulletText('本サービスの結果を用いた違法・不適切な行為'),
            _BulletText('その他、当社が不適切と判断する行為'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第7条（知的財産権）'),
            _BodyText('本サービスに関するすべての権利は当社または正当な権利者に帰属します。'),
            _BodyText('ユーザーは、本サービスを通じて得た内容を自己利用の範囲でのみ使用するものとします。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第8条（データの取り扱い）'),
            _BodyText('本サービスは、ユーザーが入力したテキストおよび生成された返信内容を保存しません。'),
            _BodyText('本サービスは、必要最小限のメタデータ（利用状況・エラー情報等）のみを取得します。'),
            _BodyText('詳細はプライバシーポリシーに従います。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第9条（サービスの変更・停止）'),
            _BodyText('当社は、ユーザーへの事前通知なく本サービスの内容を変更または停止できるものとします。'),
            _BodyText('これによりユーザーに生じた損害について、当社は責任を負いません。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第10条（免責事項）'),
            _BodyText('本サービスは現状有姿で提供され、完全性・正確性・有用性を保証するものではありません。'),
            _BodyText('本サービスの利用により生じた損害について、当社は一切の責任を負いません。'),
            _BodyText('ユーザー間または第三者とのトラブルについて、当社は関与せず責任を負いません。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第11条（利用制限・停止）'),
            _BodyText('当社は、ユーザーが本規約に違反した場合、事前通知なく利用制限またはアカウント停止を行うことができます。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第12条（規約の変更）'),
            _BodyText(
              '当社は、必要に応じて本規約を変更することができます。変更後の規約は、本サービス上に掲載した時点で効力を生じます。',
            ),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第13条（準拠法・管轄）'),
            _BodyText('本規約は日本法に準拠します。'),
            _BodyText('本サービスに関する紛争は、当社所在地を管轄する裁判所を第一審の専属管轄裁判所とします。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第14条（お問い合わせ）'),
            _BodyText('本サービスに関するお問い合わせは以下までご連絡ください。'),
            SizedBox(height: AppSpacing.md),
            Divider(),
            SizedBox(height: AppSpacing.inputVertical),
            _BodyText('隙間産業ラボ 中野家'),
            SupportEmailLink(prefix: 'メール'),
            SizedBox(height: AppSpacing.sm),
            _BodyText(
              '公式利用規約: https://sites.google.com/view/permy-terms/terms',
            ),
            _BodyText(
              '公式プライバシーポリシー: https://sites.google.com/view/permy-privacy-policy/privacy-policy',
            ),
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
        Text(
          '$label：',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(value, style: AppTextStyles.body),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(title: text);
  }
}

class _BodyText extends StatelessWidget {
  const _BodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: AppTextStyles.body);
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text('・$text', style: AppTextStyles.body),
    );
  }
}
