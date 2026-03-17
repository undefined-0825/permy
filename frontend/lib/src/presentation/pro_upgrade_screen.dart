import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

class ProUpgradeScreen extends StatelessWidget {
  const ProUpgradeScreen({required this.onTapChangePlus, super.key});

  final VoidCallback onTapChangePlus;

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('Plusのご案内')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          const Text(
            'Plusにすると、返信作成がもっと楽になるよ',
            style: AppTextStyles.primaryTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          _BenefitCard(
            title: 'Plusの優位性',
            items: const [
              '1日100回まで生成できる（Freeは1日3回）',
              '限定コンボをすべて使える（2/3/4/5）',
              '推定メーター表示で判断しやすい',
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.highlight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionHeader(title: '料金'),
                SizedBox(height: AppSpacing.sm),
                Text('月額 2,980円', style: AppTextStyles.primaryTitle),
                SizedBox(height: AppSpacing.xs),
                Text('1日あたり100円以下', style: AppTextStyles.body),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppButton(text: 'Plusに変更', onPressed: onTapChangePlus),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('あとで'),
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppSectionHeader(title: title),
          const SizedBox(height: AppSpacing.sm),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Text('・$item', style: AppTextStyles.body),
            ),
        ],
      ),
    );
  }
}
