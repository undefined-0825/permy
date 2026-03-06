import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/persona_diagnosis.dart';
import 'widgets/primary_button.dart';

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({required this.onCompleted, super.key});

  final Future<void> Function(List<DiagnosisAnswer> answers) onCompleted;

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final Map<String, String> _answers = <String, String>{};
  bool _saving = false;
  String? _error;
  int _currentQuestionIndex = 0;

  @override
  Widget build(BuildContext context) {
    final question = diagnosisQuestions[_currentQuestionIndex];
    final progress =
        '${_currentQuestionIndex + 1}/${diagnosisQuestions.length}';

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
                    if (_currentQuestionIndex > 0) {
                      setState(() => _currentQuestionIndex--);
                    } else {
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ),
            SliverToBoxAdapter(
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
                        label: choice.label,
                        isSelected: isSelected,
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
                  ],
                ),
              ),
            ),
            // エラー表示
            if (_error != null)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
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
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  bool get _isLastQuestion =>
      _currentQuestionIndex == diagnosisQuestions.length - 1;

  void _handleNext() {
    HapticFeedback.mediumImpact();
    if (_isLastQuestion) {
      _submit();
    } else {
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  Future<void> _submit() async {
    final answers = diagnosisQuestions
        .map(
          (question) => DiagnosisAnswer(
            questionId: question.id,
            choiceId: _answers[question.id]!,
          ),
        )
        .toList();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onCompleted(answers);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'うまく反映できなかった。少し待って、もう一度';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _saving = false;
      });
    }
  }
}

class _ChoiceCard extends StatefulWidget {
  const _ChoiceCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
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
        onTap: () {
          widget.onTap();
          HapticFeedback.lightImpact();
        },
        onHover: (hovering) {
          setState(() => _isHovering = hovering);
        },
        splashColor: const Color(0xFFF3F4F6),
        highlightColor: const Color(0xFFF3F4F6),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _isHovering ? const Color(0xFFF3F4F6) : Colors.transparent,
            border: Border(
              bottom: BorderSide(color: const Color(0xFFE5E7EB), width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // プレースホルダー画像エリア（後でキャラクター画像に差し替え）
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCE7F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.image_outlined,
                  size: 20,
                  color: Color(0xFFFBCFE8),
                ),
              ),
              const SizedBox(width: 16),
              // テキスト
              Expanded(
                child: Text(
                  widget.label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF374151),
                    height: 1.6,
                  ),
                ),
              ),
              // チェックマーク
              if (widget.isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFFF69B4),
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
