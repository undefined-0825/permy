import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../domain/persona_diagnosis.dart';
import '../domain/persona_type_helper.dart';
import 'persona_diagnosis_result_screen.dart';
import 'widgets/primary_button.dart';

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

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8D4F8), // 淡いパープル
              Color(0xFFFCE4EC), // 淡いピンク
            ],
          ),
        ),
        child: CustomScrollView(
          slivers: [
            SliverAppBar.large(
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    'assets/images/icons/permy_icon.png',
                    width: 40,
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 8),
                  Text(progress),
                ],
              ),
              backgroundColor: Colors.transparent,
              elevation: 0,
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
            if (isShowingResult)
              _buildResultSlider()
            else
              _buildQuestionSlider(),
          ],
        ),
      ),
    );
  }

  bool get _isLastQuestion =>
      _currentQuestionIndex == diagnosisQuestions.length - 1;

  void _handleNext() {
    if (_saving) return;
    HapticFeedback.mediumImpact();
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

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // 質問文
            Text(
              question.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1C1E),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 選択肢カード
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
                  // 選択肢を選んだら自動で次へ進む
                  Future.delayed(
                    const Duration(milliseconds: 300),
                    _handleNext,
                  );
                },
              );
            }),
            const SizedBox(height: 24),
            // エラー表示
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: !_saving ? _handleNext : null,
                isLoading: _saving,
                child: const Text('もう一度'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResultSlider() {
    final result = _diagnosisResult!;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // タイトル
            const Text(
              'きみのペルソナはこれ',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1C1E),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            // 普段の自分
            _buildResultSection(
              title: '普段の自分',
              value: getTrueSelfTypeName(result.trueSelfType),
              description: '日常で大事にしていることを表しています',
            ),
            const SizedBox(height: 24),
            // 夜の私
            _buildResultSection(
              title: '夜の私',
              value: getNightSelfTypeName(result.nightSelfType),
              description: 'LINE返信時のあなたのスタイルを表しています',
            ),
            const SizedBox(height: 24),
            // スタイルスコア
            _buildStyleScores(result),
            const SizedBox(height: 32),
            // 詳しく見る ボタン
            OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
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
              child: const Text('詳しく見る'),
            ),
            const SizedBox(height: 16),
            // さっそく使ってみる ボタン
            PrimaryButton(
              onPressed: !_saving ? _onResultConfirmed : null,
              isLoading: _saving,
              child: const Text('さっそく使ってみる'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildResultSection({
    required String title,
    required String value,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB3C1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.normal,
              color: Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleScores(DiagnosisResult result) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB3C1), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'スタイルスコア',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          _buildScoreRow('主張度', result.styleAssertiveness),
          const SizedBox(height: 12),
          _buildScoreRow('温かみ', result.styleWarmth),
          const SizedBox(height: 12),
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Color.lerp(
                      const Color(0xFFFF69B4),
                      const Color(0xFFFFB3C1),
                      1 - (value / 100),
                    )!,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$value%',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: widget.enabled
            ? () {
                widget.onTap();
                HapticFeedback.lightImpact();
              }
            : null,
        onHover: (hovering) {
          setState(() => _isHovering = hovering);
        },
        splashColor: const Color(0xFFF3F4F6),
        highlightColor: const Color(0xFFF3F4F6),
        child: Container(
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: _isHovering ? const Color(0xFFF3F4F6) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: const Color(0xFFE5E7EB), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // 選択肢画像
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE7F3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset(
                    'assets/images/diagnosis_choices/${widget.choiceId}.png',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // 画像が存在しない場合はアイコンで代用
                      return const Icon(
                        Icons.image_outlined,
                        size: 24,
                        color: Color(0xFFFBCFE8),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 18),
              // テキスト
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF374151),
                    height: 1.45,
                  ),
                ),
              ),
              // チェックマーク
              if (widget.isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFFF69B4),
                  size: 26,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
