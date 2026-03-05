import 'package:flutter/material.dart';

import '../domain/persona_diagnosis.dart';

class DiagnosisScreen extends StatefulWidget {
  const DiagnosisScreen({
    required this.onCompleted,
    super.key,
  });

  final Future<void> Function(List<int> answers) onCompleted;

  @override
  State<DiagnosisScreen> createState() => _DiagnosisScreenState();
}

class _DiagnosisScreenState extends State<DiagnosisScreen> {
  final List<int?> _answers = List<int?>.filled(diagnosisQuestions.length, null);
  bool _saving = false;
  String? _error;

  bool get _ready => _answers.every((answer) => answer != null);

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
                child: Text('ぼくと11問だけ、きみのペースで答えてね'),
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
                    value: _answers[index],
                    onChanged: (value) {
                      setState(() {
                        _answers[index] = value;
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
    final answers = _answers.map((value) => value ?? 3).toList();
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
  final int? value;
  final ValueChanged<int> onChanged;

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
              children: List<Widget>.generate(5, (optionIndex) {
                final score = optionIndex + 1;
                return ChoiceChip(
                  label: Text(score.toString()),
                  selected: value == score,
                  onSelected: (_) => onChanged(score),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}
