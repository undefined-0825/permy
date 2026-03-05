import 'package:flutter/material.dart';

import '../domain/persona_diagnosis.dart';

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

  bool get _ready => _answers.length == diagnosisQuestions.length;

  @override
  Widget build(BuildContext context) {
    final question = diagnosisQuestions[_currentQuestionIndex];
    final progress = '${_currentQuestionIndex + 1}/${diagnosisQuestions.length}';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          // 背景画像
          image: DecorationImage(
            image: AssetImage('assets/images/backgrounds/diagnosis_background.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 上部：ペルミィアイコン + 進捗表示
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(
                  children: [
                    // プレースホルダーアイコン（後で黒猫画像に差し替え）
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.pets,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 進捗表示
                    Text(
                      progress,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),

              // 中央：質問と選択肢
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 24),
                      // 質問文
                      Text(
                        question.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                          height: 1.5,
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
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),

              // エラー表示
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

              // 下部：次へボタン
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _canProceed && !_saving ? _handleNext : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFFB3C1),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            _isLastQuestion ? 'この内容で進む' : '次へ',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool get _canProceed => _answers.containsKey(diagnosisQuestions[_currentQuestionIndex].id);

  bool get _isLastQuestion => _currentQuestionIndex == diagnosisQuestions.length - 1;

  void _handleNext() {
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

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFFFF69B4) : Colors.transparent,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // プレースホルダー画像エリア（後でキャラクター画像に差し替え）
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.pink.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 40,
                  color: Colors.pink.shade200,
                ),
              ),
              const SizedBox(width: 16),
              // テキスト
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
              // チェックマーク
              if (isSelected)
                const Icon(
                  Icons.check_circle,
                  color: Color(0xFFFF69B4),
                  size: 28,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
