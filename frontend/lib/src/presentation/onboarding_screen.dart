import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'widgets/top_brand_header.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const OnboardingScreen({super.key, required this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late PageController _pageController;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 3) {
      _pageController.animateToPage(
        _currentStep + 1,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      widget.onCompleted();
    }
  }

  void _skipOnboarding() {
    Haptics.selection();
    widget.onCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const TopBrandHeader(),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentStep = index;
                });
              },
              children: [
                _buildStep(
                  icon: Icons.message,
                  title: 'ペルミィへようこそ',
                  body: 'ぼくはきみの分身。\nLINEのトーク履歴から、\nぴったりな返信を作るよ。',
                ),
                _buildStep(
                  icon: Icons.share,
                  title: 'トーク履歴を送ろう',
                  body: 'LINEでトーク履歴を送信して、\nこのアプリに共有して。\n.txtを受け取って返信案を作るよ。',
                ),
                _buildStep(
                  icon: Icons.lock_outline,
                  title: 'プライバシー保護',
                  body: 'トークの本文は保存されません。\n返信案はあなたが選んでコピーして、\n送信はあなたの操作で行います。',
                ),
                _buildStep(
                  icon: Icons.star,
                  title: 'さあ、始めよう',
                  body: '準備ができたら始めよう。\nきみのやり方に合う返信を\nいっしょに作っていくよ。',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    4,
                    (index) => Container(
                      margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      width: AppSpacing.sm,
                      height: AppSpacing.sm,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: index == _currentStep
                            ? AppColors.primaryTitle
                            : AppColors.metaText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    if (_currentStep > 0)
                      Expanded(
                        child: AppButton(
                          text: '戻る',
                          variant: AppButtonVariant.secondary,
                          onPressed: () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                        ),
                      ),
                    if (_currentStep > 0)
                      const SizedBox(width: AppSpacing.inputVertical),
                    Expanded(
                      child: AppButton(
                        text: _currentStep == 3 ? 'ペルミィを作る' : '次へ',
                        onPressed: () {
                          Haptics.mediumImpact();
                          _nextStep();
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.inputVertical),
                TextButton(
                  onPressed: _skipOnboarding,
                  child: const Text('スキップ'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: AppColors.secondaryPink),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: AppTextStyles.primaryTitle,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(body, style: AppTextStyles.body, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
