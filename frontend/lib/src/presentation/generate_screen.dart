import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../domain/models.dart';
import '../domain/telemetry_event.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/share_receiver.dart';
import '../infrastructure/telemetry_queue.dart';
import 'settings_screen.dart';
import 'widgets/primary_button.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({
    required this.apiClient,
    required this.shareReceiver,
    required this.telemetryQueue,
    super.key,
  });

  final AppApiClient apiClient;
  final ShareInput shareReceiver;
  final TelemetryQueue telemetryQueue;

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
  int? _metaPro;
  int _comboId = 0;
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
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/icons/permy_icon.png',
              width: 24,
              height: 24,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            const Text('Permy'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) =>
                      SettingsScreen(apiClient: widget.apiClient),
                ),
              );
            },
          ),
        ],
      ),
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
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ぼくはきみの分身・・・',
                          style: TextStyle(color: Color(0xFF374151)),
                        ),
                        const Text(
                          'ぼくに任せて・・・',
                          style: TextStyle(color: Color(0xFF374151)),
                        ),
                        const SizedBox(height: 12),
                        _ShareStatusCard(
                          fileName: _sharedFileName,
                          hasText: _sharedText?.isNotEmpty ?? false,
                        ),
                        const SizedBox(height: 12),
                        _ComboSelector(
                          selectedCombo: _comboId,
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
                                    title: const Text('Permy'),
                                    backgroundColor: Colors.transparent,
                                    elevation: 0,
                                    actions: [
                                      IconButton(
                                        icon: const Icon(Icons.settings),
                                        onPressed: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  SettingsScreen(apiClient: widget.apiClient),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.stretch,
                                        children: [
                                          const Text(
                                            'ぼくはきみの分身・・・',
                                            style: TextStyle(color: Color(0xFF374151)),
                                          ),
                            padding: const EdgeInsets.only(bottom: 8),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              decoration: BoxDecoration(
                                color: isCopied
                                    ? const Color(0xFFFFE5ED)
                                    : const Color(0xFFFFFFFF),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: OutlinedButton(
                                onPressed: () => _copyCandidate(candidate),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 6,
                                    ),
                                    child: Text(
                                      '${candidate.label}: ${candidate.text}',
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onGeneratePressed() async {
    HapticFeedback.mediumImpact();
    final text = _sharedText?.trim();
    if (text == null || text.isEmpty) return;

    // Pro専用コンボ（2,3,4,5）をFreeで選択した場合
    if (_plan == 'free' && _comboId >= 2) {
      _showUpsellDialog();
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _candidates = <Candidate>[];
    });

    final startTime = DateTime.now();

    // generate_requested イベント送信
    // TODO: 設定から has_ng_setting を取得（diagnose後の設定確認が必要）
    widget.telemetryQueue.enqueue(
      GenerateRequestedEvent(
        appVersion: '1.0.0',
        os: 'android',
        dailyUsed: _daily?.used ?? 0,
        dailyRemaining: _daily?.remaining ?? 3,
        hasNgSetting: false, // ペルソナ診断後に設定が存在するか
        personaVersion: 3,
      ),
    );

    try {
      final result = await widget.apiClient.generate(
        historyText: text,
        comboId: _comboId,
      );
      final latencyMs = DateTime.now().difference(startTime).inMilliseconds;

      if (!mounted) return;
      setState(() {
        _candidates = result.candidates;
        _daily = result.daily;
        _plan = result.plan;
        _metaPro = result.metaPro;
      });

      // generate_succeeded イベント送信
      widget.telemetryQueue.enqueue(
        GenerateSucceededEvent(
          appVersion: '1.0.0',
          os: 'android',
          latencyMs: latencyMs,
          ngGateTriggered: result.modelHint == 'blocked',
          followupReturned: result.followup != null,
        ),
      );

      // followup がある場合はダイアログ表示
      if (result.followup != null) {
        if (!mounted) return;
        _showFollowupDialog(result.followup!);
      }
    } on ApiError catch (error) {
      final latencyMs = DateTime.now().difference(startTime).inMilliseconds;

      // generate_failed イベント送信
      widget.telemetryQueue.enqueue(
        GenerateFailedEvent(
          appVersion: '1.0.0',
          os: 'android',
          latencyMs: latencyMs,
          errorCode: error.errorCode,
        ),
      );

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
    HapticFeedback.selectionClick();
    await Clipboard.setData(ClipboardData(text: candidate.text));

    // candidate_copied イベント送信
    widget.telemetryQueue.enqueue(
      CandidateCopiedEvent(
        appVersion: '1.0.0',
        os: 'android',
        candidateId: candidate.label,
      ),
    );

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

  void _showUpsellDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('有料版のみ'),
          content: const Text('このモードはProで使える機能だよ。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('了解'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shareSubscription?.cancel();
    super.dispose();
  }

  void _showFollowupDialog(FollowupInfo followup) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('情報補足'),
          content: Text(followup.question),
          actions: followup.choices
              .map(
                (choice) => TextButton(
                  onPressed: () {
                    // TODO: 選択値をサーバへ保存（PUT /me/settings）
                    Navigator.of(context).pop();
                  },
                  child: Text(choice.label),
                ),
              )
              .toList(),
        );
      },
    );
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

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(color: PermyColors.separator, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: PermyColors.primaryTitle,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.normal,
                color: PermyColors.metaText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ComboSelector extends StatelessWidget {
  const _ComboSelector({
    required this.selectedCombo,
    required this.isPro,
    required this.onChanged,
  });

  final int selectedCombo;
  final bool isPro;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    const combos = [
      ('次回来店の約束', false), // 0: Free
      ('休眠復活', false), // 1: Free
      ('新規客の集客', true), // 2: Pro
      ('火消し（大事な対応）', true), // 3: Pro
      ('同伴誘導', true), // 4: Pro
      ('落とす（恋愛寄せ）', true), // 5: Pro
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.transparent,
          border: Border(
            bottom: BorderSide(color: PermyColors.separator, width: 0.5),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '生成方針',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: PermyColors.primaryTitle,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: DropdownButton<int>(
                value: selectedCombo,
                isExpanded: true,
                items: List.generate(combos.length, (index) {
                  final (label, isProOnly) = combos[index];
                  final isLocked = isProOnly && !isPro;
                  return DropdownMenuItem<int>(
                    value: index,
                    enabled: !isLocked,
                    child: Text(
                      label,
                      style: TextStyle(
                        color: isLocked
                            ? PermyColors.metaText
                            : PermyColors.bodyText,
                        fontSize: 15,
                      ),
                    ),
                  );
                }),
                onChanged: (int? value) {
                  if (value != null) {
                    HapticFeedback.selectionClick();
                    onChanged(value);
                  }
                },
              ),
            ),
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
        color: const Color(0xFFFFE5E5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(padding: const EdgeInsets.all(10), child: Text(message)),
    );
  }
}
