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
              const SizedBox(height: AppSpacing.md),
              const Text('あなたのペルソナ', style: AppTextStyles.primaryTitle),
              const SizedBox(height: AppSpacing.md),
              const AppSectionHeader(title: '普段の自分'),
              const SizedBox(height: AppSpacing.inputVertical),
              _PersonaTypeCard(
                typeName: getTrueSelfTypeName(trueType),
                imagePath: getTrueSelfTypeImagePath(trueType),
                description: _getTrueTypeDescription(trueType),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: '夜の私'),
              const SizedBox(height: AppSpacing.inputVertical),
              _PersonaTypeCard(
                typeName: getNightSelfTypeName(nightType),
                imagePath: getNightSelfTypeImagePath(nightType),
                description: _getNightTypeDescription(nightType),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'ペルソナパラメータ'),
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
        return '安定感と継続性を重視する。';
      case 'Independence':
        return '自分の判断軸で動ける。';
      case 'Approval':
        return '信頼獲得を大切にする。';
      case 'Realism':
        return '現実的に成果へつなげる。';
      case 'Romance':
        return '感情と直感を素直に活かす。';
      default:
        return 'ペルソナ種別が不明です。';
    }
  }

  String _getNightTypeDescription(String type) {
    switch (type) {
      case 'VisitPush':
        return '次の来店につながる提案が得意。';
      case 'Heal':
        return '安心感を与える寄り添いが得意。';
      case 'LittleDevil':
        return '軽快な駆け引きで温度を上げる。';
      case 'BigClient':
        return '重要顧客へ戦略的に寄せる。';
      case 'Balance':
        return '状況に応じて柔軟に最適化する。';
      default:
        return 'ペルソナ種別が不明です。';
    }
  }
}

class _PersonaTypeCard extends StatelessWidget {
  const _PersonaTypeCard({
    required this.typeName,
    required this.description,
    this.imagePath,
  });

  final String typeName;
  final String description;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.separator),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.md),
              topRight: Radius.circular(AppRadius.md),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: imagePath == null
                  ? Container(
                      color: AppColors.highlight,
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.image_not_supported_outlined,
                        color: AppColors.metaText,
                      ),
                    )
                  : Image.asset(
                      imagePath!,
                      fit: BoxFit.contain,
                      alignment: Alignment.center,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.highlight,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.image_not_supported_outlined,
                          color: AppColors.metaText,
                        ),
                      ),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  typeName,
                  style: AppTextStyles.primaryTitle.copyWith(
                    color: AppColors.secondaryPink,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(description, style: AppTextStyles.meta),
              ],
            ),
          ),
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
