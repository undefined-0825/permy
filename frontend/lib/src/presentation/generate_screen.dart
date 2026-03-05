import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/share_receiver.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({
    required this.apiClient,
    required this.shareReceiver,
    super.key,
  });

  final AppApiClient apiClient;
  final ShareInput shareReceiver;

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen>
    with WidgetsBindingObserver {
  StreamSubscription<SharePayload>? _shareSubscription;
  String? _sharedText;
  String? _sharedFileName;
  bool _loading = false;
  ApiError? _error;
  List<Candidate> _candidates = <Candidate>[];
  DailyInfo? _daily;
  String _plan = 'free';
  String? _copiedLabel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await widget.apiClient.bootstrapAuth();
    final initialPayload = await widget.shareReceiver.getInitialPayload();
    if (initialPayload != null && mounted) {
      setState(() {
        _sharedText = initialPayload.text;
        _sharedFileName = initialPayload.fileName;
      });
    }
    _shareSubscription = widget.shareReceiver.payloadStream.listen((payload) {
      if (!mounted) return;
      setState(() {
        _sharedText = payload.text;
        _sharedFileName = payload.fileName;
        _error = null;
      });
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _discardSensitiveState();
    }
  }

  void _discardSensitiveState() {
    if (!mounted) return;
    setState(() {
      _sharedText = null;
      _sharedFileName = null;
      _candidates = <Candidate>[];
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = !_loading && (_sharedText?.trim().isNotEmpty ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Permy')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('ぼくはきみの分身・・・'),
              const Text('ぼくに任せて・・・'),
              const SizedBox(height: 12),
              _ShareStatusCard(
                fileName: _sharedFileName,
                hasText: _sharedText?.isNotEmpty ?? false,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: canGenerate ? _onGeneratePressed : null,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('返信案を作る'),
              ),
              if (_daily != null) ...[
                const SizedBox(height: 8),
                Text(
                  '今日の残り: ${_daily!.remaining}/${_daily!.limit}（${_plan.toUpperCase()}）',
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                _ErrorBanner(message: _errorMessage(_error!)),
              ],
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: _candidates.length,
                  itemBuilder: (context, index) {
                    final candidate = _candidates[index];
                    final isCopied = _copiedLabel == candidate.label;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 400),
                        decoration: BoxDecoration(
                          color: isCopied
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: OutlinedButton(
                          onPressed: () => _copyCandidate(candidate),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Text(
                                '${candidate.label}: ${candidate.text}',
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _onGeneratePressed() async {
    final text = _sharedText?.trim();
    if (text == null || text.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
      _candidates = <Candidate>[];
    });

    try {
      final result = await widget.apiClient.generate(historyText: text);
      if (!mounted) return;
      setState(() {
        _candidates = result.candidates;
        _daily = result.daily;
        _plan = result.plan;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _copyCandidate(Candidate candidate) async {
    await Clipboard.setData(ClipboardData(text: candidate.text));
    if (!mounted) return;

    setState(() {
      _copiedLabel = candidate.label;
    });
    Future<void>.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        _copiedLabel = null;
      });
    });
  }

  String _errorMessage(ApiError error) {
    switch (error.errorCode) {
      case 'AUTH_INVALID':
      case 'AUTH_REQUIRED':
        return '認証を更新したよ。もう一度ためしてね';
      case 'SETTINGS_VERSION_CONFLICT':
      case 'ETAG_MISMATCH':
        return '設定が更新されていたみたい。読み込み直してね';
      case 'RATE_LIMITED':
        return '少し混み合ってるみたい。少し待って、もう一度';
      case 'DAILY_LIMIT_REACHED':
      case 'DAILY_LIMIT_EXCEEDED':
        return '今日はここまで。続きは明日か、Proで使える';
      case 'PLAN_REQUIRED':
        return 'この機能はProで使えるよ';
      case 'OPENAI_DISABLED':
        return 'この環境では生成を止めているよ';
      case 'UPSTREAM_UNAVAILABLE':
      case 'UPSTREAM_TIMEOUT':
        return '今は不安定みたい。少し待って、もう一度';
      default:
        return 'うまく読めなかった。もう一度共有して';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSubscription?.cancel();
    super.dispose();
  }
}

class _ShareStatusCard extends StatelessWidget {
  const _ShareStatusCard({required this.fileName, required this.hasText});

  final String? fileName;
  final bool hasText;

  @override
  Widget build(BuildContext context) {
    final title = hasText ? '受け取り完了' : '共有待ち';
    final description = hasText
        ? (fileName == null ? '.txtを受け取ったよ' : '$fileName を受け取ったよ')
        : 'LINEでトーク履歴を送信して、このアプリに共有して';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(description),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(10), child: Text(message)),
    );
  }
}
