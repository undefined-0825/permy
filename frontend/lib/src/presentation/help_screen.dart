import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import 'widgets/top_brand_header.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const TopBrandHeader(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ヘルプ（使い方）', style: AppTextStyles.primaryTitle),
            SizedBox(height: AppSpacing.md),
            _SectionTitle('1. はじめに'),
            _BodyText(
              'Permyは、LINEのトーク履歴（.txt）をもとに返信案を提案するアプリです。返信の送信は自動で行われず、最終判断はあなた自身が行います。',
            ),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('2. 基本の使い方'),
            _StepText('1) LINEでトーク履歴を .txt として共有します。'),
            _StepText('2) 共有先に Permy を選びます。'),
            _StepText('3) PermyでA/B/Cの返信案を確認します。'),
            _StepText('4) 気に入った案をタップしてコピーし、LINEに貼り付けて送信します。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('3. うまく共有できないとき'),
            _BulletText('Permyを最新バージョンに更新してください。'),
            _BulletText('共有するファイルが .txt 形式か確認してください。'),
            _BulletText('一度アプリを終了して、再度共有を試してください。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('4. 生成に失敗するとき'),
            _BulletText('通信状態の良い場所で再試行してください。'),
            _BulletText('時間をおいて再試行してください（混雑時は制限がかかる場合があります）。'),
            _BulletText('設定のNG項目が厳しすぎる場合は、内容を見直してください。'),
            SizedBox(height: AppSpacing.inputVertical),
            _SectionTitle('5. プライバシーについて'),
            _BodyText(
              'Permyは、入力本文と生成本文を保存しません。本文は画面表示と生成処理に必要な範囲でのみ一時的に扱います。詳しくは「プライバシーポリシー」を確認してください。',
            ),
            SizedBox(height: AppSpacing.md),
            Divider(),
            SizedBox(height: AppSpacing.inputVertical),
            _BodyText('お問い合わせ：sukima.lab.nakanoya@gmail.com'),
          ],
        ),
      ),
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

class _StepText extends StatelessWidget {
  const _StepText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Text(text, style: AppTextStyles.body),
    );
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
