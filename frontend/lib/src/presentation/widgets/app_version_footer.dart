import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';

class AppVersionFooter extends StatelessWidget {
  const AppVersionFooter({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final version = snapshot.data?.version;
        final versionLabel = version == null || version.isEmpty
            ? 'Version:-'
            : 'Version:$version';

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              versionLabel,
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(color: AppColors.metaText),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '©Sukima,Lab Nakanoya',
              textAlign: TextAlign.center,
              style: AppTextStyles.small.copyWith(color: AppColors.metaText),
            ),
          ],
        );
      },
    );
  }
}
