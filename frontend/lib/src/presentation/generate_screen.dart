import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';
import '../domain/models.dart';
import '../domain/persona_type_helper.dart';
import '../domain/telemetry_event.dart';
import '../domain/history_text.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/purchase_service.dart';
import '../infrastructure/share_receiver.dart';
import '../infrastructure/telemetry_queue.dart';
import 'settings_screen.dart';
import 'widgets/top_brand_header.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({
    required this.apiClient,
    required this.shareReceiver,
    required this.telemetryQueue,
    required this.purchaseService,
    super.key,
  });

  final AppApiClient apiClient;
  final ShareInput shareReceiver;
  final TelemetryQueue telemetryQueue;
  final PurchaseService purchaseService;

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen>
    with WidgetsBindingObserver {
  static const String _linePersona = 'ぼくはきみの分身・・・';
  static const String _lineDelegate = 'ぼくに任せて・・・';

  StreamSubscription<SharePayload>? _shareSubscription;
  Timer? _generationLineTimer;
  String? _sharedText;
  String? _sharedFileName;
  bool _loading = false;
  bool _isGeneratingSequence = false;
  int _generationLineIndex = 0;
  ApiError? _error;
  List<Candidate> _candidates = <Candidate>[];
  DailyInfo? _daily;
  String _plan = 'free';
  int? _metaPro;
  int _comboId = 0;
  String? _copiedLabel;
  String _trueTypeLabel = '診断待機中...';
  String _nightTypeLabel = '診断待機中...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await widget.apiClient.bootstrapAuth();
    unawaited(_loadPersonaSummary());
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

  Future<void> _loadPersonaSummary() async {
    try {
      final snapshot = await widget.apiClient.getSettings();
      if (!mounted) return;
      final trueType = snapshot.settings['true_self_type']?.toString();
      final nightType = snapshot.settings['night_self_type']?.toString();
      setState(() {
        _trueTypeLabel = (trueType == null || trueType.isEmpty)
            ? '診断待機中...'
            : getTrueSelfTypeName(trueType);
        _nightTypeLabel = (nightType == null || nightType.isEmpty)
            ? '診断待機中...'
            : getNightSelfTypeName(nightType);
      });
    } catch (_) {
      // ペルソナ取得失敗時は既定表示を維持
    }
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

    return AppScaffold(
      appBar: TopBrandHeader(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    apiClient: widget.apiClient,
                    purchaseService: widget.purchaseService,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(
                    'assets/images/backgrounds/background_pink.png',
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Stack(
              children: [
                if (_isGeneratingSequence)
                  Positioned.fill(
                    child: Container(
                      color: AppColors.generateBackground.withValues(
                        alpha: 0.95,
                      ),
                    ),
                  ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _PersonaSummaryCard(
                      trueTypeLabel: _trueTypeLabel,
                      nightTypeLabel: _nightTypeLabel,
                      fileName: _sharedFileName,
                      hasText: _sharedText?.isNotEmpty ?? false,
                    ),
                    if (_sharedText?.isNotEmpty ?? false) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _SharedHistoryPreview(
                        fileName: _sharedFileName,
                        sharedText: _sharedText!,
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    _ComboSelector(
                      selectedCombo: _comboId,
                      isPro: _plan == 'pro',
                      onChanged: (int value) {
                        final isPro = value >= 2; // combo 2-5 は Pro のみ
                        if (isPro && _plan == 'free') {
                          _showUpsellDialog();
                        } else {
                          setState(() {
                            _comboId = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    AppButton(
                      text: _loading ? '生成中...' : 'ぼくが返信案を考えるよ',
                      onPressed: canGenerate ? _onGeneratePressed : null,
                    ),
                    if (_daily != null || (_plan == 'pro' && _metaPro != null))
                      _GenerateMetaInfo(
                        daily: _daily,
                        planLabel: _planLabel(_plan),
                        metaPro: _plan == 'pro' ? _metaPro : null,
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Expanded(
                      child: _ResultArea(
                        isLoading: _loading,
                        canGenerate: canGenerate,
                        candidates: _candidates,
                        copiedLabel: _copiedLabel,
                        onCopyCandidate: _copyCandidate,
                      ),
                    ),
                  ],
                ),
                if (_isGeneratingSequence)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          child: Text(
                            _generationLineIndex == 0
                                ? _linePersona
                                : _lineDelegate,
                            key: ValueKey<int>(_generationLineIndex),
                            style: AppTextStyles.primaryTitle.copyWith(
                              color: AppColors.white,
                              fontSize: 20,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onGeneratePressed() async {
    unawaited(Haptics.mediumImpact());
    final rawText = _sharedText?.trim();
    if (rawText == null || rawText.isEmpty) return;

    final planFromStore = widget.purchaseService.isPro ? 'pro' : _plan;
    final text = trimHistoryForGenerate(rawText, plan: planFromStore);
    if (text.isEmpty) {
      final error = ApiError(
        errorCode: 'VALIDATION_FAILED',
        message: '共有テキストを読み取れなかった',
        httpStatus: 422,
      );
      setState(() {
        _error = error;
      });
      _showErrorMessageBox(error);
      return;
    }

    // Pro専用コンボ（2,3,4,5）をFreeで選択した場合
    if (_plan == 'free' && _comboId >= 2) {
      _showUpsellDialog();
      return;
    }

    setState(() {
      _loading = true;
      _isGeneratingSequence = true;
      _generationLineIndex = 0;
      _error = null;
      _candidates = <Candidate>[];
    });
    _generationLineTimer?.cancel();
    _generationLineTimer = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !_isGeneratingSequence) return;
      setState(() {
        _generationLineIndex = 1;
      });
    });
    final minSequenceFuture = Future<void>.delayed(
      const Duration(milliseconds: 700),
    );

    final startTime = DateTime.now();

    // 設定から ng_setting の有無を判定
    bool hasNgSetting = false;
    try {
      final settingsSnapshot = await widget.apiClient.getSettings();
      final settings = settingsSnapshot.settings;
      final ngTags = settings['ng_tags'];
      final ngFreePhrases = settings['ng_free_phrases'];

      hasNgSetting =
          (ngTags is List && ngTags.isNotEmpty) ||
          (ngFreePhrases is List && ngFreePhrases.isNotEmpty);
    } catch (_) {
      // 設定取得失敗の場合は false のまま
      hasNgSetting = false;
    }

    // generate_requested イベント送信
    widget.telemetryQueue.enqueue(
      GenerateRequestedEvent(
        appVersion: '1.0.0',
        os: 'android',
        dailyUsed: _daily?.used ?? 0,
        dailyRemaining: _daily?.remaining ?? 3,
        hasNgSetting: hasNgSetting,
        personaVersion: 3,
      ),
    );

    try {
      final result = await widget.apiClient.generate(
        historyText: text,
        comboId: _comboId,
      );
      await minSequenceFuture;
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
      await minSequenceFuture;
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
      _showErrorMessageBox(error);
    } finally {
      if (!mounted) return;
      _generationLineTimer?.cancel();
      setState(() {
        _loading = false;
        _isGeneratingSequence = false;
        _generationLineIndex = 0;
      });
    }
  }

  String _planLabel(String plan) => plan == 'pro' ? 'Plus' : 'Free';

  Future<void> _copyCandidate(Candidate candidate) async {
    unawaited(Haptics.selection());
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
      case 'VALIDATION_FAILED':
        return '履歴が長すぎるか形式が不正かも。LINEからもう一度共有してね';
      case 'RATE_LIMITED':
        return '少し混み合ってるみたい。少し待って、もう一度';
      case 'DAILY_LIMIT_REACHED':
      case 'DAILY_LIMIT_EXCEEDED':
        return '今日はここまで。続きは明日か、Plusで使える';
      case 'PLAN_REQUIRED':
        return 'この機能はPlusで使えるよ';
      case 'OPENAI_DISABLED':
        return 'この環境では生成を止めているよ';
      case 'UPSTREAM_UNAVAILABLE':
      case 'UPSTREAM_TIMEOUT':
        return '今は不安定みたい。少し待って、もう一度';
      case 'INTERNAL_ERROR':
        return 'サーバーで問題が起きたみたい。少し待って、もう一度ためしてね';
      default:
        return '処理に失敗したよ。内容を確認して、もう一度ためしてね';
    }
  }

  void _showErrorMessageBox(ApiError error) {
    if (!mounted) return;

    final message = _errorMessage(error);
    final detail = error.message.trim();
    final detailMessage = detail.isEmpty ? '詳細情報は取得できなかったよ' : detail;

    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('エラーが発生したよ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: AppSpacing.sm),
              Text('エラーコード: ${error.errorCode}', style: AppTextStyles.small),
              const SizedBox(height: AppSpacing.xs),
              Text('詳細: $detailMessage', style: AppTextStyles.small),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
            ),
          ],
        );
      },
    );
  }

  void _showUpsellDialog() {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('有料版のみ'),
          content: const Text('このモードはPlusで使える機能だよ。'),
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
    _generationLineTimer?.cancel();
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
                    unawaited(Haptics.selection());
                    _saveFollowupChoice(followup, choice);
                  },
                  child: Text(choice.label),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Future<void> _saveFollowupChoice(
    FollowupInfo followup,
    FollowupChoice choice,
  ) async {
    Navigator.of(context).pop();

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final snapshot = await widget.apiClient.getSettings();
      final updated = Map<String, dynamic>.from(snapshot.settings);

      if (followup.key == 'ng_tags' || followup.key == 'ng_free_phrases') {
        final values =
            (updated[followup.key] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            <String>[];
        if (!values.contains(choice.id)) {
          values.add(choice.id);
        }
        updated[followup.key] = values;
      } else {
        updated[followup.key] = choice.id;
      }

      await widget.apiClient.updateSettings(updated, snapshot.etag);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('情報を反映したよ。もう一度生成してみてね')));
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
      _showErrorMessageBox(error);
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }
}

class _PersonaSummaryCard extends StatelessWidget {
  const _PersonaSummaryCard({
    required this.trueTypeLabel,
    required this.nightTypeLabel,
    required this.fileName,
    required this.hasText,
  });

  final String trueTypeLabel;
  final String nightTypeLabel;
  final String? fileName;
  final bool hasText;

  @override
  Widget build(BuildContext context) {
    final shareDescription = hasText
        ? (fileName == null ? '.txtを受け取ったよ' : '$fileName を受け取ったよ')
        : 'LINEでトーク履歴を送信して、このアプリに共有して';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('現在のペルソナ情報', style: AppTextStyles.sectionHeader),
          const SizedBox(height: AppSpacing.xs),
          _PersonaValueRow(label: '普段の属性', value: trueTypeLabel),
          const SizedBox(height: AppSpacing.xs),
          _PersonaValueRow(label: '夜の属性', value: nightTypeLabel),
          if (!hasText) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(shareDescription, style: AppTextStyles.small),
          ],
        ],
      ),
    );
  }
}

class _PersonaValueRow extends StatelessWidget {
  const _PersonaValueRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: AppTextStyles.meta)),
        Expanded(
          child: Text(
            value,
            style: AppTextStyles.body,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _SharedHistoryPreview extends StatelessWidget {
  const _SharedHistoryPreview({
    required this.fileName,
    required this.sharedText,
  });

  final String? fileName;
  final String sharedText;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        title: const Text(
          '共有されたトーク履歴（確認用）',
          style: AppTextStyles.sectionHeader,
        ),
        subtitle: Text(
          fileName == null || fileName!.isEmpty
              ? 'タップで内容を確認できるよ'
              : '$fileName（タップで内容を確認）',
          style: AppTextStyles.small,
        ),
        children: [
          SizedBox(
            height: 140,
            child: TextFormField(
              key: const Key('shared_history_preview_textfield'),
              initialValue: sharedText,
              readOnly: true,
              expands: true,
              minLines: null,
              maxLines: null,
              style: AppTextStyles.body,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white,
                contentPadding: const EdgeInsets.all(AppSpacing.md),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
        ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('生成方針', style: AppTextStyles.sectionHeader),
        const SizedBox(height: AppSpacing.xs),
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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTextStyles.body.copyWith(
                          color: isLocked
                              ? AppColors.metaText
                              : AppColors.bodyText,
                        ),
                      ),
                    ),
                    if (isProOnly)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.plusBadgeBackground,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          'Plus',
                          style: AppTextStyles.small.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
            onChanged: (int? value) {
              if (value != null) {
                unawaited(Haptics.selection());
                onChanged(value);
              }
            },
          ),
        ),
      ],
    );
  }
}

class _GenerateMetaInfo extends StatelessWidget {
  const _GenerateMetaInfo({
    required this.daily,
    required this.planLabel,
    required this.metaPro,
  });

  final DailyInfo? daily;
  final String planLabel;
  final int? metaPro;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (daily != null)
            Text(
              '今日の残り: ${daily!.remaining}/${daily!.limit}（$planLabel）',
              style: AppTextStyles.meta,
            ),
          if (metaPro != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text('推定メーター: $metaPro%', style: AppTextStyles.meta),
          ],
        ],
      ),
    );
  }
}

class _ResultArea extends StatelessWidget {
  const _ResultArea({
    required this.isLoading,
    required this.canGenerate,
    required this.candidates,
    required this.copiedLabel,
    required this.onCopyCandidate,
  });

  final bool isLoading;
  final bool canGenerate;
  final List<Candidate> candidates;
  final String? copiedLabel;
  final ValueChanged<Candidate> onCopyCandidate;

  @override
  Widget build(BuildContext context) {
    assert(candidates.isEmpty || candidates.length == 3);
    const fixedLabels = <String>['A', 'B', 'C'];
    final stateMessage = isLoading
        ? '生成中...'
        : canGenerate
        ? 'ここに返信案が表示されるよ'
        : 'まずLINEのトーク履歴を共有してね';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.inputVertical,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(title: '返信案'),
          const SizedBox(height: AppSpacing.xs),
          Expanded(
            child: ListView.builder(
              itemCount: fixedLabels.length,
              itemBuilder: (context, index) {
                if (candidates.isNotEmpty) {
                  final candidate = candidates[index];
                  final isCopied = copiedLabel == candidate.label;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _ResultCandidateCard(
                      candidate: candidate,
                      isCopied: isCopied,
                      onCopy: () => onCopyCandidate(candidate),
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _ResultPlaceholderCard(
                    label: fixedLabels[index],
                    message: stateMessage,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultPlaceholderCard extends StatelessWidget {
  const _ResultPlaceholderCard({required this.label, required this.message});

  final String label;
  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.separator,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Text('$label案', style: AppTextStyles.small),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message, style: AppTextStyles.meta)),
          ],
        ),
      ),
    );
  }
}

class _ResultCandidateCard extends StatelessWidget {
  const _ResultCandidateCard({
    required this.candidate,
    required this.isCopied,
    required this.onCopy,
  });

  final Candidate candidate;
  final bool isCopied;
  final VoidCallback onCopy;

  String _labelTitle(String label) {
    switch (label) {
      case 'A':
        return 'A案';
      case 'B':
        return 'B案';
      case 'C':
        return 'C案';
      default:
        return label;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isCopied ? AppColors.lightPink : AppColors.white,
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onCopy,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryPink,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Text(
                      _labelTitle(candidate.label),
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isCopied ? 'コピー済み' : 'タップでコピー',
                    style: AppTextStyles.small.copyWith(
                      color: isCopied
                          ? AppColors.primaryPink
                          : AppColors.metaText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(candidate.text, style: AppTextStyles.body),
            ],
          ),
        ),
      ),
    );
  }
}

