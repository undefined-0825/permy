import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';
import 'widgets/top_brand_header.dart';

class AboutPrivacyScreen extends StatelessWidget {
  const AboutPrivacyScreen({super.key});

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
              const Text('このアプリについて', style: AppTextStyles.primaryTitle),
              const SizedBox(height: AppSpacing.md),
              const AppSectionHeader(title: 'Permyについて'),
              const SizedBox(height: AppSpacing.inputVertical),
              const Text(
                'Permyはあなたの分身、黒猫のぼく。'
                'LINEの生のトーク履歴をもらって、返信案を作ります。'
                'あなたの「返信したくない...」が「返信できた」に変わるまで、ぼくは手伝い続けます。',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'プライバシーとセキュリティ'),
              const SizedBox(height: AppSpacing.inputVertical),
              const Text('本文を保存しません', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'あなたがLINEから送ってくれたトーク履歴、ぼくが作った返信案。'
                'これらの本文内容は、ぼくのサーバに保存しません。'
                'ぼくはあなたのスマホの中だけで読み取り、毎回新しく返信案を考えます。',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('送信はあなたが決める', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'ぼくが作った返信案は自動では送られません。'
                'あなたがコピーして、あなた自身がLINEで送ります。'
                'ぼくはあくまで分身、手伝い役です。',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              const Text('NG設定は端末に同期', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                '「ぼくが返信に入れない言葉」「避ける文体」は、'
                '設定画面で変更できます。'
                'ぼくはその設定に沿って返信案を考えます。',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: 'お問い合わせ'),
              const SizedBox(height: AppSpacing.inputVertical),
              const Text(
                'ご意見・ご質問・不具合報告は、下記までお願いします。',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: AppSpacing.md),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.9),
                  border: Border.all(color: AppColors.separator),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                padding: const EdgeInsets.all(AppSpacing.inputVertical),
                child: Row(
                  children: [
                    const Icon(Icons.mail_outline, size: 20),
                    const SizedBox(width: AppSpacing.inputVertical),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          unawaited(Haptics.lightImpact());
                          final emailUri = Uri(
                            scheme: 'mailto',
                            path: 'sukima.lab.nakanoya@gmail.com',
                            queryParameters: const {'subject': 'Permy お問い合わせ'},
                          );
                          try {
                            if (await canLaunchUrl(emailUri)) {
                              await launchUrl(emailUri);
                            } else {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('メールアプリが見つかりません'),
                                ),
                              );
                            }
                          } catch (_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('メールアプリの起動に失敗しました'),
                              ),
                            );
                          }
                        },
                        child: const Text(
                          'sukima.lab.nakanoya@gmail.com',
                          style: AppTextStyles.body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              const AppSectionHeader(title: '発行者'),
              const SizedBox(height: AppSpacing.inputVertical),
              const Text('隙間産業ラボ 中野家', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.sm),
              const Text('メール: sukima.lab.nakanoya@gmail.com', style: AppTextStyles.body),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Text(
                  'Version 1.0.0',
                  style: AppTextStyles.small.copyWith(color: AppColors.bodyText),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }
}
