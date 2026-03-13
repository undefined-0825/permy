import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';
import '../domain/models.dart';
import '../domain/persona_diagnosis.dart';
import '../domain/persona_type_helper.dart';
import 'persona_diagnosis_result_screen.dart';
import 'widgets/top_brand_header.dart';

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({required this.onCompleted, super.key});

  final Future<DiagnosisResult> Function(List<DiagnosisAnswer> answers)
  onCompleted;

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final Map<String, String> _answers = <String, String>{};
  bool _saving = false;
  String? _error;
  int _currentQuestionIndex = 0;
  DiagnosisResult? _diagnosisResult;

  @override
  Widget build(BuildContext context) {
    final isShowingResult = _diagnosisResult != null;
    final progress = isShowingResult
        ? '完了'
        : '${_currentQuestionIndex + 1}/${diagnosisQuestions.length}';

    return AppScaffold(
      appBar: TopBrandHeader(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.inputVertical),
            child: Center(
              child: Text(
                progress,
                style: AppTextStyles.meta.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        leading: SizedBox(
          width: 36,
          height: 36,
          child: IconButton(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back, size: 20),
            onPressed: () {
              if (isShowingResult) {
                // 結果ページから戻る場合は質問ページに戻る
                setState(() {
                  _diagnosisResult = null;
                });
              } else if (_currentQuestionIndex > 0) {
                setState(() => _currentQuestionIndex--);
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
      ),
      body: isShowingResult
          ? _buildResultSlider(_diagnosisResult!)
          : _buildQuestionSlider(),
    );
  }

  bool get _isLastQuestion =>
      _currentQuestionIndex == diagnosisQuestions.length - 1;

  void _handleNext() {
    if (_saving) return;
    unawaited(Haptics.mediumImpact());
    final currentQuestion = diagnosisQuestions[_currentQuestionIndex];
    if (_answers[currentQuestion.id] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('選択肢を選んでください')));
      return;
    }

    if (_isLastQuestion) {
      _submit();
    } else {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  Future<void> _submit() async {
    final hasMissingAnswer = diagnosisQuestions.any(
      (question) => _answers[question.id] == null,
    );
    if (hasMissingAnswer) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('すべての質問に回答してください')));
      return;
    }

    final answers = diagnosisQuestions
        .map(
          (question) => DiagnosisAnswer(
            questionId: question.id,
            choiceId: (_answers[question.id] ?? '').toString(),
          ),
        )
        .toList();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final result = await widget.onCompleted(answers);
      if (!mounted) return;
      setState(() {
        _diagnosisResult = result;
        _saving = false;
      });
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _getErrorMessage(e);
        _saving = false;
      });
    }
  }

  String _getErrorMessage(ApiError error) {
    switch (error.errorCode) {
      case 'AUTH_INVALID':
      case 'AUTH_REQUIRED':
        return '認証を更新したよ。もう一度ためしてね';
      case 'VALIDATION_ERROR':
      case 'VALIDATION_FAILED':
        return 'うまく読めなかった。もう一度ためしてね';
      case 'SETTINGS_VERSION_CONFLICT':
        return '保存が競合したみたい。もう一度ためしてね';
      case 'RATE_LIMITED':
        return '少し混み合ってるみたい。少し待って、もう一度';
      case 'UPSTREAM_UNAVAILABLE':
      case 'UPSTREAM_TIMEOUT':
        return '今は不安定みたい。少し待って、もう一度';
      case 'INTERNAL_ERROR':
      case 'STORAGE_UNAVAILABLE':
        return 'サーバーが不安定みたい。少し待って、もう一度';
      default:
        return 'うまく反映できなかった。少し待って、もう一度';
    }
  }

  Widget _buildQuestionSlider() {
    final question = diagnosisQuestions[_currentQuestionIndex];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(
              question.title,
              style: AppTextStyles.primaryTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            ...question.choices.map((choice) {
              final isSelected = _answers[question.id] == choice.id;
              return _ChoiceCard(
                choiceId: choice.id,
                label: choice.label,
                isSelected: isSelected,
                enabled: !_saving,
                onTap: () {
                  setState(() {
                    _answers[question.id] = choice.id;
                  });
                  Future.delayed(
                    const Duration(milliseconds: 300),
                    _handleNext,
                  );
                },
              );
            }),
            const SizedBox(height: AppSpacing.md),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                _error!,
                style: AppTextStyles.body.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                text: _saving ? '処理中...' : 'もう一度',
                onPressed: !_saving ? _handleNext : null,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultSlider(DiagnosisResult result) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            const Text(
              'きみのペルソナはこれ',
              style: AppTextStyles.primaryTitle,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            _buildResultSection(
              title: '普段の自分',
              value: getTrueSelfTypeName(result.trueSelfType),
              description: '日常で大事にしていることを表しています',
              imagePath: getTrueSelfTypeImagePath(result.trueSelfType),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildResultSection(
              title: '夜の私',
              value: getNightSelfTypeName(result.nightSelfType),
              description: 'LINE返信時のあなたのスタイルを表しています',
              imagePath: getNightSelfTypeImagePath(result.nightSelfType),
            ),
            const SizedBox(height: AppSpacing.lg),
            _buildStyleScores(result),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              text: '詳しく見る',
              variant: AppButtonVariant.secondary,
              onPressed: () {
                unawaited(Haptics.lightImpact());
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => PersonaDiagnosisResultScreen(
                      trueType: result.trueSelfType,
                      nightType: result.nightSelfType,
                      assertiveness: result.styleAssertiveness,
                      warmth: result.styleWarmth,
                      riskGuard: result.styleRiskGuard,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              text: _saving ? '処理中...' : 'さっそく使ってみる',
              onPressed: !_saving ? _onResultConfirmed : null,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection({
    required String title,
    required String value,
    required String description,
    String? imagePath,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryPink, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.meta.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTextStyles.primaryTitle),
          if (imagePath != null) ...[
            const SizedBox(height: AppSpacing.inputVertical),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.highlight,
                    alignment: Alignment.center,
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(description, style: AppTextStyles.small),
        ],
      ),
    );
  }

  Widget _buildStyleScores(DiagnosisResult result) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.primaryPink, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppSectionHeader(title: 'スタイルスコア'),
          const SizedBox(height: AppSpacing.md),
          _buildScoreRow('主張度', result.styleAssertiveness),
          const SizedBox(height: AppSpacing.inputVertical),
          _buildScoreRow('温かみ', result.styleWarmth),
          const SizedBox(height: AppSpacing.inputVertical),
          _buildScoreRow('リスク回避', result.styleRiskGuard),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, int value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.meta.copyWith(
            color: AppColors.bodyText,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: AppSpacing.sm,
                  backgroundColor: AppColors.separator,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(
                      AppColors.secondaryPink,
                      AppColors.primaryPink,
                      1 - (value / 100),
                    )!,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text('$value%', style: AppTextStyles.small),
          ],
        ),
      ],
    );
  }

  Future<void> _onResultConfirmed() async {
    // 結果ページを閉じて Settings に戻る
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }
}

class _ChoiceCard extends StatefulWidget {
  const _ChoiceCard({
    required this.choiceId,
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
  });

  final String choiceId;
  final String label;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_ChoiceCard> createState() => _ChoiceCardState();
}

class _ChoiceCardState extends State<_ChoiceCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.inputVertical),
      child: InkWell(
        onTap: widget.enabled
            ? () {
                widget.onTap();
                unawaited(Haptics.lightImpact());
              }
            : null,
        onHover: (hovering) {
          setState(() => _isHovering = hovering);
        },
        splashColor: AppColors.highlight,
        highlightColor: AppColors.highlight,
        child: Container(
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: _isHovering ? AppColors.highlight : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: AppColors.separator, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.lightPink,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.asset(
                    'assets/images/diagnosis_choices/${widget.choiceId}.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) {
                      return const Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: AppColors.primaryPink,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(widget.label, style: AppTextStyles.body)),
              if (widget.isSelected)
                const Icon(
                  Icons.check_circle,
                  color: AppColors.secondaryPink,
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
