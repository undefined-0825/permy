import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';

/// バージョンアップお知らせ画面。
/// [isForced] が true の場合は戻れない（強制更新）。
/// [storeUrl] が空のときはストアボタンを無効にする。
class UpdateNoticeScreen extends StatelessWidget {
  const UpdateNoticeScreen({
    required this.latestVersion,
    required this.storeUrl,
    required this.releaseNoteTitle,
    required this.releaseNoteBody,
    this.isForced = false,
    super.key,
  });

  final String latestVersion;
  final String storeUrl;
  final String releaseNoteTitle;
  final String releaseNoteBody;
  /// true: 強制更新（戻る不可）, false: 任意更新（「あとで」スキップ可）
  final bool isForced;

  List<Widget> _dismissButton(BuildContext context) {
    return [
      const SizedBox(height: AppSpacing.sm),
      TextButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('あとで'),
      ),
    ];
  }

  Future<void> _openStore() async {
    if (storeUrl.isEmpty) return;
    final uri = Uri.parse(storeUrl);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final title = releaseNoteTitle.isNotEmpty
        ? releaseNoteTitle
        : 'バージョンアップのお知らせ';
    final body = releaseNoteBody.isNotEmpty
        ? releaseNoteBody
        : '新しいバージョン（$latestVersion）が利用できます。\nストアからアップデートしてください。';

    return PopScope(
      canPop: !isForced,
      child: AppScaffold(
        scrollable: true,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.xl),
            Text(
              title,
              style: AppTextStyles.primaryTitle.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'v$latestVersion',
              style: AppTextStyles.meta,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.highlight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(body, style: AppTextStyles.body),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              text: 'バージョンアップする',
              enabled: storeUrl.isNotEmpty,
              onPressed: _openStore,
            ),
            if (!isForced) ..._dismissButton(context),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }
}
