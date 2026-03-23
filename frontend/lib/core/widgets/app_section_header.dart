import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({required this.title, super.key, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final isArticleTitle = title.startsWith('第') && title.contains('条');
    final titleStyle = isArticleTitle
        ? AppTextStyles.sectionHeader.copyWith(fontWeight: FontWeight.w700)
        : AppTextStyles.sectionHeader;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: titleStyle),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(subtitle!, style: AppTextStyles.meta),
          ],
        ],
      ),
    );
  }
}
