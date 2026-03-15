import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';

const String supportEmailAddress = 'sukima.lab.nakanoya@gmail.com';
const String supportEmailSubject = 'Permy お問い合わせ';

Future<void> launchSupportEmail(BuildContext context) async {
  final emailUri = Uri(
    scheme: 'mailto',
    path: supportEmailAddress,
    queryParameters: const {'subject': supportEmailSubject},
  );

  try {
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
      return;
    }

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('メールアプリが見つかりません')));
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('メールアプリの起動に失敗しました')));
  }
}

class SupportEmailLink extends StatelessWidget {
  const SupportEmailLink({
    super.key,
    this.prefix,
    this.filled = false,
    this.showIcon = false,
  });

  final String? prefix;
  final bool filled;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final text = prefix == null
        ? supportEmailAddress
        : '$prefix：$supportEmailAddress';

    final textWidget = Text(
      text,
      style: AppTextStyles.body.copyWith(decoration: TextDecoration.underline),
    );

    if (!filled) {
      return InkWell(
        onTap: () => launchSupportEmail(context),
        child: textWidget,
      );
    }

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.sm),
      onTap: () => launchSupportEmail(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: 0.9),
          border: Border.all(color: AppColors.separator),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        padding: const EdgeInsets.all(AppSpacing.inputVertical),
        child: Row(
          children: [
            if (showIcon) ...[
              const Icon(Icons.mail_outline, size: 20),
              const SizedBox(width: AppSpacing.inputVertical),
            ],
            Expanded(child: textWidget),
          ],
        ),
      ),
    );
  }
}
