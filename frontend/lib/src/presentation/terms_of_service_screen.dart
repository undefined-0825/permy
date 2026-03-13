import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

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
            _MetaRow(label: '最終更新日', value: '2026年3月7日'),
            SizedBox(height: AppSpacing.md),
            _SectionTitle('第1条（適用）'),
            _BodyText(
              '本規約は、隙間産業ラボ 中野家（以下「運営者」）が提供するアプリ「Permy」（以下「本サービス」）の利用条件を定めるものです。利用者は本規約に同意のうえ本サービスを利用するものとします。',
            ),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第2条（サービス内容）'),
            _BodyText(
              '本サービスは、LINEトーク履歴をもとに返信文案（A/B/C）を提案する補助サービスです。返信の送信主体および最終判断は利用者本人にあります。',
            ),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第3条（禁止事項）'),
            _BodyText('利用者は、以下の行為を行ってはなりません。'),
            _BulletText('法令または公序良俗に違反する行為'),
            _BulletText('第三者の権利を侵害する行為（著作権、プライバシー、名誉等）'),
            _BulletText('虚偽情報の入力、なりすまし、不正アクセス等の不正利用行為'),
            _BulletText('本サービスの運営を妨害する行為、またはそのおそれのある行為'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第4条（データの取り扱い）'),
            _BodyText('運営者は、入力本文および生成本文を永続保存しません。詳細はプライバシーポリシーに定めます。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第5条（料金・サブスクリプション）'),
            _BodyText(
              '有料プランの内容、料金、課金方法、更新、解約、返金、復元等は各アプリストア（Google Play / App Store）の規約および購入画面の表示に従います。',
            ),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第6条（知的財産権）'),
            _BodyText('本サービスに関する著作権その他の知的財産権は、運営者または正当な権利者に帰属します。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第7条（免責）'),
            _BodyText(
              '運営者は、本サービスの完全性・正確性・有用性・特定目的適合性・継続性を保証しません。利用者が本サービスを用いて行った行為およびその結果について、運営者は法令上許される範囲で責任を負いません。',
            ),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第8条（サービス変更・停止）'),
            _BodyText(
              '運営者は、保守、障害対応、法令対応その他必要な場合、事前通知なく本サービスの全部または一部を変更・停止・終了することがあります。',
            ),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第9条（規約の変更）'),
            _BodyText(
              '運営者は、必要と判断した場合、本規約を変更できます。変更後の規約は本サービス内に表示した時点で効力を生じます。',
            ),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('第10条（準拠法・裁判管轄）'),
            _BodyText(
              '本規約は日本法を準拠法とし、本サービスに関して紛争が生じた場合は、運営者の所在地を管轄する裁判所を第一審の専属的合意管轄裁判所とします。',
            ),
            SizedBox(height: AppSpacing.md),
            Divider(),
            SizedBox(height: AppSpacing.inputVertical),
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
