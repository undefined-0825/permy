import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_button.dart';

class AppErrorMessageBox extends StatelessWidget {
  const AppErrorMessageBox({
    required this.title,
    required this.message,
    super.key,
    this.errorCode,
    this.detail,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? errorCode;
  final String? detail;
  final String? actionLabel;
  final VoidCallback? onAction;

  static const String _errorCatImagePath =
      'assets/images/errors/permy_cat_error.png';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Image.asset(
              _errorCatImagePath,
              height: 72,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTextStyles.sectionHeader,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(message, textAlign: TextAlign.center, style: AppTextStyles.body),
          if ((errorCode ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'エラーコード: $errorCode',
              textAlign: TextAlign.center,
              style: AppTextStyles.small,
            ),
          ],
          if ((detail ?? '').isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '詳細: $detail',
              textAlign: TextAlign.center,
              style: AppTextStyles.small,
            ),
          ],
          if (onAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(text: actionLabel ?? '閉じる', onPressed: onAction),
          ],
        ],
      ),
    );
  }
}

Future<void> showAppErrorDialog({
  required BuildContext context,
  required String title,
  required String message,
  String? errorCode,
  String? detail,
  String actionLabel = '閉じる',
}) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: AppErrorMessageBox(
          title: title,
          message: message,
          errorCode: errorCode,
          detail: detail,
          actionLabel: actionLabel,
          onAction: () => Navigator.of(dialogContext).pop(),
        ),
      );
    },
  );
}
