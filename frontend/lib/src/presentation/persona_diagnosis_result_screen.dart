import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import '../domain/persona_type_helper.dart';
import 'widgets/top_brand_header.dart';

class PersonaDiagnosisResultScreen extends StatelessWidget {
  const PersonaDiagnosisResultScreen({
    required this.trueType,
    required this.nightType,
    this.assertiveness = 50,
    this.warmth = 50,
    this.riskGuard = 50,
    super.key,
  });

  final String trueType;
  final String nightType;
  final int assertiveness;
  final int warmth;
  final int riskGuard;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const TopBrandHeader(),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('あなたのペルソナ', style: AppTextStyles.primaryTitle),
              const SizedBox(height: AppSpacing.md),
              const AppSectionHeader(title: '普段の自分'),
              const SizedBox(height: AppSpacing.inputVertical),
              _PersonaTypeCard(
                typeName: getTrueSelfTypeName(trueType),
                description: _getTrueTypeDescription(trueType),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: '夜の私'),
              const SizedBox(height: AppSpacing.inputVertical),
              _PersonaTypeCard(
                typeName: getNightSelfTypeName(nightType),
                description: _getNightTypeDescription(nightType),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'スタイルスコア'),
              const SizedBox(height: AppSpacing.md),
              _StyleScoreRow(label: '主張度', score: assertiveness),
              const SizedBox(height: AppSpacing.inputVertical),
              _StyleScoreRow(label: '温かみ', score: warmth),
              const SizedBox(height: AppSpacing.inputVertical),
              _StyleScoreRow(label: 'リスク回避', score: riskGuard),
              const SizedBox(height: AppSpacing.xl),
              const Text(
                'これらのペルソナは、あなたの返信スタイルを決める大事な指標。'
                'ときどき見返して、今の傾向を確認してみてね。',
                style: AppTextStyles.meta,
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  String _getTrueTypeDescription(String type) {
    switch (type) {
      case 'Stability':
        return 'バランスを大事にする。無理のない生活を心がけるタイプ。';
      case 'Independence':
        return '自分のペースを守る。判断を自分で決めるタイプ。';
      case 'Approval':
        return '人の評価を大事にする。信頼を集めることに価値を置くタイプ。';
      case 'Realism':
        return '現実的に考える。長期的な得を見据えるタイプ。';
      case 'Romance':
        return '感情を大事にする。直感を重視するタイプ。';
      default:
        return 'ペルソナ種別が不明です。';
    }
  }

  String _getNightTypeDescription(String type) {
    switch (type) {
      case 'VisitPush':
        return '次の約束を大事にする。関係を継続することを重視するタイプ。';
      case 'Heal':
        return '相手を癒すことを重視する。寄り添いが得意なタイプ。';
      case 'LittleDevil':
        return '駆け引きを楽しむ。軽快なテンポを作るタイプ。';
      case 'BigClient':
        return '重要顧客を見極める。戦略的に寄せるタイプ。';
      case 'Balance':
        return '全体バランスを重視する。状況に応じて柔軟に対応するタイプ。';
      default:
        return 'ペルソナ種別が不明です。';
    }
  }
}

class _PersonaTypeCard extends StatelessWidget {
  const _PersonaTypeCard({required this.typeName, required this.description});

  final String typeName;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            typeName,
            style: AppTextStyles.primaryTitle.copyWith(color: AppColors.secondaryPink),
          ),
          const SizedBox(height: AppSpacing.inputVertical),
          Text(description, style: AppTextStyles.body),
        ],
      ),
    );
  }
}

class _StyleScoreRow extends StatelessWidget {
  const _StyleScoreRow({required this.label, required this.score});

  final String label;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: AppSpacing.sm,
            backgroundColor: AppColors.separator,
            valueColor: AlwaysStoppedAnimation<Color>(_getScoreColor(score)),
          ),
        ),
      ],
    );
  }

  Color _getScoreColor(int score) {
    if (score < 30) {
      return AppColors.error;
    }
    if (score < 70) {
      return AppColors.secondaryPink;
    }
    return AppColors.primaryPink;
  }
}
