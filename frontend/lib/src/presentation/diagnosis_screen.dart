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

  bool get _ready => _answers.length == diagnosisQuestions.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ペルソナ診断')),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('ぼくと7問だけ、きみのペースで答えてね'),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: diagnosisQuestions.length,
                itemBuilder: (context, index) {
                  final question = diagnosisQuestions[index];
                  return _QuestionCard(
                    index: index,
                    question: question,
                    value: _answers[question.id],
                    onChanged: (value) {
                      setState(() {
                        _answers[question.id] = value;
                      });
                    },
                  );
                },
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _ready && !_saving ? _submit : null,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('この内容で進む'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
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

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.question,
    required this.value,
    required this.onChanged,
  });

  final int index;
  final DiagnosisQuestion question;
  final String? value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${index + 1}. ${question.title}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: question.choices
                  .map(
                    (choice) => ChoiceChip(
                      label: Text(choice.label),
                      selected: value == choice.id,
                      onSelected: (_) => onChanged(choice.id),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
