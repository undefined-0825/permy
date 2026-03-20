import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

class ProUpgradeScreen extends StatefulWidget {
  const ProUpgradeScreen({
    required this.onTapChangePlus,
    required this.onOpenHiddenPage,
    required this.isProActive,
    super.key,
  });

  static const String _heroImagePath = 'assets/images/pro_upgrade/hero_01.png';

  final VoidCallback onTapChangePlus;
  final VoidCallback onOpenHiddenPage;
  final bool isProActive;

  @override
  State<ProUpgradeScreen> createState() => _ProUpgradeScreenState();
}

class _ProUpgradeScreenState extends State<ProUpgradeScreen> {
  int _hiddenTapCount = 0;

  void _onHiddenTap() {
    if (widget.isProActive) {
      return;
    }
    final nextCount = _hiddenTapCount + 1;
    if (nextCount >= 10) {
      setState(() {
        _hiddenTapCount = 0;
      });
      widget.onOpenHiddenPage();
      return;
    }
    setState(() {
      _hiddenTapCount = nextCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(
        title: const Text('Plusのご案内'),
        actions: [
          if (!widget.isProActive)
            GestureDetector(
              key: const Key('pro_upgrade_hidden_tap_area'),
              behavior: HitTestBehavior.opaque,
              onTap: _onHiddenTap,
              child: const SizedBox(width: 56, height: 56),
            ),
        ],
      ),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          AspectRatio(
            // 1024x1536（2:3）の挿絵サイズに合わせて表示する
            aspectRatio: 2 / 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.asset(
                ProUpgradeScreen._heroImagePath,
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const Text(
            'Plusにすると、返信作成がもっと楽になるよ',
            style: AppTextStyles.primaryTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.highlight,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
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
          AppButton(text: 'Plusに変更', onPressed: widget.onTapChangePlus),
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
