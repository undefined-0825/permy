import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';

enum AppButtonVariant { primary, secondary }

class AppButton extends StatelessWidget {
  const AppButton({
    required this.text,
    super.key,
    this.onPressed,
    this.enabled = true,
    this.expand = true,
    this.variant = AppButtonVariant.primary,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool enabled;
  final bool expand;
  final AppButtonVariant variant;

  Future<void> _handlePressed() async {
    if (!enabled || onPressed == null) {
      return;
    }
    await Haptics.success();
    onPressed!.call();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = !enabled || onPressed == null;
    final double minHeight = AppSpacing.xxl;

    final ButtonStyle primaryStyle = ElevatedButton.styleFrom(
      backgroundColor: isDisabled
          ? AppColors.disabledPink
          : AppColors.primaryPink,
      foregroundColor: isDisabled ? AppColors.metaText : AppColors.white,
      disabledBackgroundColor: AppColors.disabledPink,
      disabledForegroundColor: AppColors.metaText,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      minimumSize: const Size(0, AppSpacing.xxl),
      elevation: 0,
    );

    final ButtonStyle secondaryStyle = OutlinedButton.styleFrom(
      foregroundColor: isDisabled ? AppColors.metaText : AppColors.primaryPink,
      disabledForegroundColor: AppColors.metaText,
      side: BorderSide(
        color: isDisabled ? AppColors.separator : AppColors.primaryPink,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      minimumSize: const Size(0, AppSpacing.xxl),
    );

    final Widget label = Text(
      text,
      style: AppTextStyles.buttonLabel.copyWith(
        color: switch (variant) {
          AppButtonVariant.primary =>
            isDisabled ? AppColors.metaText : AppColors.white,
          AppButtonVariant.secondary =>
            isDisabled ? AppColors.metaText : AppColors.primaryPink,
        },
      ),
    );

    final Widget button = switch (variant) {
      AppButtonVariant.primary => ElevatedButton(
        onPressed: isDisabled ? null : _handlePressed,
        style: primaryStyle,
        child: label,
      ),
      AppButtonVariant.secondary => OutlinedButton(
        onPressed: isDisabled ? null : _handlePressed,
        style: secondaryStyle,
        child: label,
      ),
    };

    if (!expand) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: button,
      );
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
