import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_error_message_box.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';
import '../domain/models.dart';
import '../domain/persona_type_helper.dart';
import '../domain/telemetry_event.dart';
import '../domain/history_text.dart';
import '../domain/line_history_parser.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/customer_generate_selection_store.dart';
import '../infrastructure/line_name_store.dart';
import '../infrastructure/purchase_service.dart';
import '../infrastructure/share_receiver.dart';
import '../infrastructure/telemetry_queue.dart';
import 'premium_comp_hidden_screen.dart';
import 'pro_upgrade_screen.dart';
import 'customer_list_screen.dart';
import 'settings_screen.dart';
import 'widgets/line_name_dialog.dart';
import 'widgets/top_brand_header.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({
    required this.apiClient,
    required this.shareReceiver,
    required this.telemetryQueue,
    required this.purchaseService,
    this.shareCandidateHandler,
    super.key,
  });

  final AppApiClient apiClient;
  final ShareInput shareReceiver;
  final TelemetryQueue telemetryQueue;
  final PurchaseService purchaseService;
  final Future<void> Function(String text)? shareCandidateHandler;

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen>
    with WidgetsBindingObserver {
  static const String _linePersona = 'ぼくはきみの分身・・・';
  static const String _lineDelegate = 'ぼくに任せて・・・';
  static const String _lineShareSplashImagePath =
      'assets/images/splash/line_share_splash.png';
  static const Duration _lineShareSplashTotalDuration = Duration(
    milliseconds: 1400,
  );
  static const Duration _lineShareSplashFadeDuration = Duration(
    milliseconds: 500,
  );
  static const Duration _lineShareSplashVisibleDuration = Duration(
    milliseconds: 850,
  );
  static const Map<String, String> _relationshipLabels = {
    'new': '新規（初めて）',
    'regular': '常連（何度も来てる）',
    'big_client': '太客（大切なお客様）',
    'caution': '慎重（距離を見たい）',
    'peer': '同業・友達寄り',
  };

  StreamSubscription<SharePayload>? _shareSubscription;
  Timer? _generationLineTimer;
  Timer? _shareSplashFadeTimer;
  Timer? _shareSplashHideTimer;
  String? _sharedText;
  String? _sharedFileName;
  bool _loading = false;
  bool _isGeneratingSequence = false;
  bool _showLineShareSplash = false;
  double _lineShareSplashOpacity = 0;
  int _generationLineIndex = 0;
  List<Candidate> _candidates = <Candidate>[];
  DailyInfo? _daily;
  String _plan = 'free';
  int? _metaPro;
  int _comboId = 0;
  String? _copiedLabel;
  String? _trueTypeValue;
  String? _nightTypeValue;
  String _trueTypeLabel = '診断待機中...';
  String _nightTypeLabel = '診断待機中...';
  String _relationshipType = 'new';
  String _replyLengthPref = 'short';
  String _lineBreakPref = 'few';
  String _emojiAmountPref = 'none';
  String _reactionLevelPref = 'low';
  String _partnerNameUsagePref = 'none';
  String _candidateTapAction = 'copy';
  bool _savingAdjustments = false;
  int _dropdownResetVersion = 0;
  final _lineNameStore = LineNameStore();
  String? _selectedCustomerId;
  String? _selectedCustomerName;
  Map<String, dynamic>? _selectedCustomerContext;
  late final VoidCallback _customerSelectionListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _customerSelectionListener = () {
      unawaited(_consumeSelectedCustomer());
    };
    CustomerGenerateSelectionStore.instance.selectionNotifier.addListener(
      _customerSelectionListener,
    );
    unawaited(_consumeSelectedCustomer());
    _bootstrap();
  }

  Future<void> _consumeSelectedCustomer() async {
    final selected = CustomerGenerateSelectionStore.instance.current;
    if (selected == null) {
      return;
    }

    final mappedRelationship = _mapCustomerStageToRelationship(
      selected.relationshipStage,
    );
    setState(() {
      _selectedCustomerId = selected.customerId;
      _selectedCustomerName = selected.displayName;
      _selectedCustomerContext = null;
      _relationshipType = mappedRelationship;
    });
    unawaited(_updateRelationshipType(mappedRelationship));
    CustomerGenerateSelectionStore.instance.clear();

    await _loadSelectedCustomerContext(selected.customerId);
  }

  String _mapCustomerStageToRelationship(String stage) {
    switch (stage) {
      case 'important':
        return 'big_client';
      case 'inactive':
        return 'caution';
      case 'regular':
      case 'caution':
      case 'new':
        return stage;
      default:
        return 'new';
    }
  }

  Future<void> _loadSelectedCustomerContext(String customerId) async {
    try {
      final detail = await widget.apiClient.getCustomerDetail(customerId);
      if (!mounted || _selectedCustomerId != customerId) {
        return;
      }
      setState(() {
        _selectedCustomerContext = _buildCustomerContext(detail);
      });
    } catch (_) {
      if (!mounted || _selectedCustomerId != customerId) {
        return;
      }
      setState(() {
        _selectedCustomerContext = null;
      });
    }
  }

  Map<String, dynamic> _buildCustomerContext(CustomerDetail detail) {
    String compact(String? text, {int maxChars = 40}) {
      final value = (text ?? '').trim();
      if (value.isEmpty) {
        return '';
      }
      if (value.length <= maxChars) {
        return value;
      }
      return '${value.substring(0, maxChars)}…';
    }

    final preferredCategories = <String>{
      'topic',
      'birthday',
      'drink',
      'style',
      'mood',
    };
    final tags =
        detail.tags
            .map(
              (tag) => <String, String>{
                'category': tag.category,
                'value': compact(tag.value, maxChars: 18),
              },
            )
            .where((tag) => (tag['value'] ?? '').isNotEmpty)
            .toList()
          ..sort((a, b) {
            final aPreferred = preferredCategories.contains(a['category']);
            final bPreferred = preferredCategories.contains(b['category']);
            if (aPreferred == bPreferred) {
              return 0;
            }
            return aPreferred ? -1 : 1;
          });

    final visitSummaries = detail.visitLogs
        .take(3)
        .map((log) {
          final chunks = <String>[log.visitedOn, log.visitType];
          if (log.moodTag != null && log.moodTag!.trim().isNotEmpty) {
            chunks.add(compact(log.moodTag, maxChars: 16));
          }
          if (log.memoShort != null && log.memoShort!.trim().isNotEmpty) {
            chunks.add(compact(log.memoShort, maxChars: 24));
          }
          return compact(chunks.join(' '), maxChars: 44);
        })
        .where((item) => item.isNotEmpty)
        .take(1)
        .toList();

    final eventSummaries = detail.events
        .take(3)
        .map((event) {
          final chunks = <String>[
            event.eventDate,
            event.eventType,
            event.title,
          ];
          if (event.note != null && event.note!.trim().isNotEmpty) {
            chunks.add(compact(event.note, maxChars: 24));
          }
          return compact(chunks.join(' '), maxChars: 44);
        })
        .where((item) => item.isNotEmpty)
        .take(1)
        .toList();

    return <String, dynamic>{
      'customer_id': detail.customer.customerId,
      'display_name': detail.customer.displayName,
      'call_name': detail.customer.callName,
      'relationship_stage': detail.customer.relationshipStage,
      'visit_frequency_tag': detail.customer.visitFrequencyTag,
      'drink_style_tag': detail.customer.drinkStyleTag,
      'last_visit_at': detail.customer.lastVisitAt,
      'last_contact_at': detail.customer.lastContactAt,
      'memo_summary': compact(detail.customer.memoSummary, maxChars: 56),
      'tags': tags.take(4).toList(),
      'recent_visit_log_summaries': visitSummaries,
      'upcoming_event_summaries': eventSummaries,
    };
  }

  Future<void> _bootstrap() async {
    await widget.apiClient.bootstrapAuth();
    unawaited(_loadScreenSettings());
    final initialPayload = await widget.shareReceiver.getInitialPayload();
    if (initialPayload != null && mounted) {
      _applySharePayload(initialPayload);
    }
    _shareSubscription = widget.shareReceiver.payloadStream.listen((payload) {
      if (!mounted) return;
      _applySharePayload(payload);
    });
  }

  void _applySharePayload(SharePayload payload) {
    _shareSplashFadeTimer?.cancel();
    _shareSplashHideTimer?.cancel();

    setState(() {
      _sharedText = payload.text;
      _sharedFileName = payload.fileName;
      _showLineShareSplash = true;
      _lineShareSplashOpacity = 0;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showLineShareSplash) return;
      setState(() {
        _lineShareSplashOpacity = 1;
      });
    });

    _shareSplashFadeTimer = Timer(_lineShareSplashVisibleDuration, () {
      if (!mounted || !_showLineShareSplash) return;
      setState(() {
        _lineShareSplashOpacity = 0;
      });
    });

    _shareSplashHideTimer = Timer(_lineShareSplashTotalDuration, () {
      if (!mounted) return;
      setState(() {
        _showLineShareSplash = false;
      });
    });
  }

  Future<void> _loadScreenSettings() async {
    try {
      final snapshot = await widget.apiClient.getSettings();
      if (!mounted) return;
      final trueType = snapshot.settings['true_self_type']?.toString();
      final nightType = snapshot.settings['night_self_type']?.toString();
      final relationshipType = snapshot.settings['relationship_type']
          ?.toString();
      final replyLengthPref = snapshot.settings['reply_length_pref']
          ?.toString();
      final lineBreakPref = snapshot.settings['line_break_pref']?.toString();
      final emojiAmountPref = snapshot.settings['emoji_amount_pref']
          ?.toString();
      final reactionLevelPref = snapshot.settings['reaction_level_pref']
          ?.toString();
      final partnerNameUsagePref = snapshot.settings['partner_name_usage_pref']
          ?.toString();
      final candidateTapAction = snapshot.settings['candidate_tap_action']
          ?.toString();
      final isProActive = _isProActive();
      final featureTier = snapshot.settings['feature_tier']?.toString();
      final billingTier = snapshot.settings['billing_tier']?.toString();
      final plan = snapshot.settings['plan']?.toString();
      final inferredPlan =
          (plan == 'premium' ||
              featureTier == 'premium' ||
              billingTier == 'premium_store' ||
              billingTier == 'premium_comp')
          ? 'premium'
          : ((plan == 'pro' ||
                    featureTier == 'pro' ||
                    billingTier == 'pro_store')
                ? 'pro'
                : _plan);
      setState(() {
        _plan = inferredPlan;
        _trueTypeValue = trueType;
        _nightTypeValue = nightType;
        _trueTypeLabel = (trueType == null || trueType.isEmpty)
            ? '診断待機中...'
            : getTrueSelfTypeName(trueType);
        _nightTypeLabel = (nightType == null || nightType.isEmpty)
            ? '診断待機中...'
            : getNightSelfTypeName(nightType);
        _relationshipType = _relationshipLabels.containsKey(relationshipType)
            ? relationshipType!
            : 'new';
        _replyLengthPref = _normalizeReplyLengthPref(
          replyLengthPref,
          isPro: isProActive,
        );
        _lineBreakPref = _normalizeLineBreakPref(
          lineBreakPref,
          isPro: isProActive,
        );
        _emojiAmountPref = _normalizeEmojiAmountPref(
          emojiAmountPref,
          isPro: isProActive,
        );
        _reactionLevelPref = _normalizeReactionLevelPref(
          reactionLevelPref,
          isPro: isProActive,
        );
        _partnerNameUsagePref = _normalizePartnerNameUsagePref(
          partnerNameUsagePref,
          isPro: isProActive,
        );
        _candidateTapAction = candidateTapAction == 'share' ? 'share' : 'copy';
      });
    } catch (_) {
      // ペルソナ取得失敗時は既定表示を維持
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasSharedText = _sharedText?.trim().isNotEmpty ?? false;
    final canGenerate = !_loading && !_savingAdjustments && hasSharedText;

    return AppScaffold(
      appBar: TopBrandHeader(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, size: 28),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(
                    apiClient: widget.apiClient,
                    purchaseService: widget.purchaseService,
                  ),
                ),
              );
              if (!mounted) return;
              await _loadScreenSettings();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Stack(
              children: [
                SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const AppSectionHeader(title: '顧客メモ'),
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: const Text(
                                '顧客管理を開く',
                                style: AppTextStyles.body,
                              ),
                              subtitle: Text(
                                _isPremiumActive()
                                    ? '顧客情報とリマインドを確認できるよ'
                                    : 'Premiumで顧客管理とリマインド機能が使えるよ',
                                style: AppTextStyles.meta,
                              ),
                              trailing: const Icon(
                                Icons.chevron_right,
                                color: AppColors.metaText,
                              ),
                              onTap: _openCustomerMemoFromGenerate,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      if (!hasSharedText) ...[
                        const _SharePromptHero(),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                      if (hasSharedText) ...[
                        _SharedHistoryPreview(
                          fileName: _sharedFileName,
                          sharedText: _sharedText!,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        if (_selectedCustomerName != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.white.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'この顧客で返信作成中: $_selectedCustomerName',
                                    style: AppTextStyles.body,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _selectedCustomerId = null;
                                      _selectedCustomerName = null;
                                      _selectedCustomerContext = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.md,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: AppButton(
                            text: _loading ? '生成中...' : 'ぼくが返信案を考えるよ',
                            onPressed: canGenerate ? _onGeneratePressed : null,
                          ),
                        ),
                        if (_selectedCustomerContext != null) ...[
                          const SizedBox(height: AppSpacing.sm),
                          OutlinedButton.icon(
                            onPressed: canGenerate
                                ? _runCustomerContextComparison
                                : null,
                            icon: const Icon(Icons.compare_arrows),
                            label: const Text('顧客あり/なしを比較生成（2回消費）'),
                          ),
                        ],
                        if (_candidates.isNotEmpty) ...[
                          const SizedBox(height: AppSpacing.xl),
                          _ResultArea(
                            candidates: _candidates,
                            copiedLabel: _copiedLabel,
                            candidateTapAction: _candidateTapAction,
                            onCopyCandidate: _copyCandidate,
                            onShareCandidate: _shareCandidate,
                          ),
                        ],
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      _GenerateAdjustmentsCard(
                        currentRelationshipType: _relationshipType,
                        currentReplyLengthPref: _replyLengthPref,
                        currentLineBreakPref: _lineBreakPref,
                        currentEmojiAmountPref: _emojiAmountPref,
                        currentReactionLevelPref: _reactionLevelPref,
                        currentPartnerNameUsagePref: _partnerNameUsagePref,
                        dropdownResetVersion: _dropdownResetVersion,
                        selectedCombo: _comboId,
                        isPro: _isProActive(),
                        isSaving: _savingAdjustments,
                        isDisabled: _loading || _isGeneratingSequence,
                        onRelationshipChanged: _updateRelationshipType,
                        onReplyLengthChanged: _updateReplyLengthPref,
                        onLineBreakChanged: _updateLineBreakPref,
                        onEmojiAmountChanged: _updateEmojiAmountPref,
                        onReactionLevelChanged: _updateReactionLevelPref,
                        onPartnerNameUsageChanged: _updatePartnerNameUsagePref,
                        onComboChanged: (int value) {
                          final isPro = value >= 2; // combo 2-5 は Pro のみ
                          if (isPro && !_isProActive()) {
                            setState(() {
                              _dropdownResetVersion += 1;
                            });
                            _openProUpgradePage();
                            return;
                          }
                          setState(() {
                            _comboId = value;
                          });
                        },
                      ),
                      if (hasSharedText) const SizedBox(height: AppSpacing.xl),
                      if (_daily != null ||
                          (_plan == 'pro' && _metaPro != null)) ...[
                        _GenerateMetaInfo(
                          daily: _daily,
                          planLabel: _planLabel(_plan),
                          metaPro: _plan == 'pro' ? _metaPro : null,
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      _PersonaSummaryCard(
                        trueTypeLabel: _trueTypeLabel,
                        nightTypeLabel: _nightTypeLabel,
                        trueTypeImagePath: _trueTypeValue == null
                            ? null
                            : getTrueSelfTypeImagePath(_trueTypeValue!),
                        nightTypeImagePath: _nightTypeValue == null
                            ? null
                            : getNightSelfTypeImagePath(_nightTypeValue!),
                        isDisabled: _loading || _isGeneratingSequence,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
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
                              color: AppColors.primaryTitle,
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
          if (_showLineShareSplash)
            Positioned.fill(
              child: IgnorePointer(
                child: _LineShareSplashOverlay(
                  opacity: _lineShareSplashOpacity,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _onGeneratePressed() async {
    await _generateCandidates(triggerHaptics: true);
  }

  int _scoreCandidates(
    List<Candidate> candidates, {
    String? customerName,
    String? callName,
  }) {
    if (candidates.isEmpty) {
      return 0;
    }

    final allText = candidates.map((c) => c.text).join('\n');
    var score = 0;

    for (final candidate in candidates) {
      final len = candidate.text.trim().length;
      if (len >= 45) {
        score += 8;
      }
      if (len >= 70) {
        score += 4;
      }
      if (candidate.text.contains('○○') || candidate.text.contains('{name}')) {
        score -= 12;
      }
    }

    final uniqueTexts = candidates.map((c) => c.text.trim()).toSet().length;
    score += uniqueTexts * 5;

    final n1 = (customerName ?? '').trim();
    final n2 = (callName ?? '').trim();
    if (n1.isNotEmpty && allText.contains(n1)) {
      score += 8;
    }
    if (n2.isNotEmpty && allText.contains(n2)) {
      score += 8;
    }
    return score;
  }

  Future<void> _runCustomerContextComparison() async {
    final rawText = _sharedText?.trim();
    if (rawText == null || rawText.isEmpty) {
      return;
    }
    if (_selectedCustomerContext == null) {
      return;
    }

    final shouldRun = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('比較生成を実行する？'),
        content: const Text('同じ履歴で「顧客あり」と「顧客なし」を比較します。\n生成回数を2回消費します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('比較する'),
          ),
        ],
      ),
    );
    if (shouldRun != true || !mounted) {
      return;
    }

    final planFromStore = widget.purchaseService.isPro
        ? widget.purchaseService.currentPlan
        : _plan;
    final text = trimHistoryForGenerate(rawText, plan: planFromStore);
    if (text.isEmpty) {
      return;
    }

    final parsedLine = LineHistoryParser.parse(rawText);
    if (parsedLine is LineGroupResult) {
      return;
    }
    String? myLineName;
    if (parsedLine is LineDuoResult) {
      myLineName = await _resolveMyLineName(parsedLine.names);
    }

    setState(() {
      _loading = true;
    });

    try {
      final withContext = await widget.apiClient.generate(
        historyText: text,
        comboId: _comboId,
        myLineName: myLineName,
        customerContext: _selectedCustomerContext,
      );
      final withoutContext = await widget.apiClient.generate(
        historyText: text,
        comboId: _comboId,
        myLineName: myLineName,
        customerContext: null,
      );

      final withScore = _scoreCandidates(
        withContext.candidates,
        customerName: _selectedCustomerName,
        callName: _selectedCustomerContext?['call_name']?.toString(),
      );
      final withoutScore = _scoreCandidates(withoutContext.candidates);
      final useContext = withScore >= withoutScore;
      final picked = useContext ? withContext : withoutContext;

      if (!mounted) {
        return;
      }
      setState(() {
        _candidates = picked.candidates;
        _daily = picked.daily;
        _plan = picked.plan;
        _metaPro = picked.metaPro;
      });

      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('比較結果'),
          content: Text(
            '顧客あり: $withScore 点\n顧客なし: $withoutScore 点\n\n採用: ${useContext ? '顧客あり' : '顧客なし'}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('閉じる'),
            ),
          ],
        ),
      );
    } on ApiError catch (error) {
      if (!mounted) {
        return;
      }
      _showErrorMessageBox(error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 保存済みLINE名を確認し、必要なら「きみはどっち？」ダイアログを表示する
  Future<String?> _resolveMyLineName(List<String> names) async {
    final savedName = await _lineNameStore.read();
    if (savedName != null && names.contains(savedName)) {
      return savedName;
    }
    if (!mounted) return null;
    final selected = await LineNameDialog.show(context, names);
    if (selected != null) {
      await _lineNameStore.write(selected);
    }
    return selected;
  }

  Future<void> _generateCandidates({bool triggerHaptics = false}) async {
    if (triggerHaptics) {
      unawaited(Haptics.mediumImpact());
    }

    final rawText = _sharedText?.trim();
    if (rawText == null || rawText.isEmpty) return;

    final planFromStore = widget.purchaseService.isPro
        ? widget.purchaseService.currentPlan
        : _plan;
    final text = trimHistoryForGenerate(rawText, plan: planFromStore);
    if (text.isEmpty) {
      final error = ApiError(
        errorCode: 'VALIDATION_FAILED',
        message: '共有テキストを読み取れなかった',
        httpStatus: 422,
      );
      setState(() {});
      _showErrorMessageBox(error);
      return;
    }

    // LINE名解決
    final parsedLine = LineHistoryParser.parse(rawText);
    if (parsedLine is LineGroupResult) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('グループトークには対応していないよ'),
          content: const Text('2名のトーク履歴を共有してね'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    String? myLineName;
    if (parsedLine is LineDuoResult) {
      myLineName = await _resolveMyLineName(parsedLine.names);
    }

    // Pro専用コンボ（2,3,4,5）をFreeで選択した場合
    if (_plan == 'free' && _comboId >= 2) {
      _openProUpgradePage();
      return;
    }

    setState(() {
      _loading = true;
      _isGeneratingSequence = true;
      _generationLineIndex = 0;
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
        myLineName: myLineName,
        customerContext: _selectedCustomerContext,
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
      _showErrorMessageBox(error);
    } finally {
      _generationLineTimer?.cancel();
      if (mounted) {
        setState(() {
          _loading = false;
          _isGeneratingSequence = false;
          _generationLineIndex = 0;
        });
      }
    }
  }

  String _planLabel(String plan) {
    if (plan == 'premium') {
      return 'Premium';
    }
    if (plan == 'pro') {
      return 'Pro';
    }
    return 'Free';
  }

  bool _isPremiumActive() =>
      widget.purchaseService.currentPlan == 'premium' || _plan == 'premium';

  Future<void> _openCustomerMemoFromGenerate() async {
    if (_isPremiumActive()) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CustomerListScreen(apiClient: widget.apiClient),
        ),
      );
      return;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('顧客メモはPremium機能だよ'),
        content: const Text('顧客情報の管理やリマインドはPremiumで使えるよ。\nこのままPremiumに変更する？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('あとで'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Premiumに変更'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) {
      return;
    }

    try {
      final available = await widget.purchaseService.isAvailable();
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ストアが利用できません')));
        return;
      }

      await widget.purchaseService.purchase(plan: 'premium');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Premium購入処理を開始しました')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Premium購入の開始に失敗したよ')));
    }
  }

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

  Future<void> _shareCandidate(Candidate candidate) async {
    unawaited(Haptics.selection());

    try {
      if (widget.shareCandidateHandler != null) {
        await widget.shareCandidateHandler!(candidate.text);
      } else {
        await Share.share(
          candidate.text,
          subject: 'Permy 返信案 ${candidate.label}',
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共有に失敗したよ')));
    }
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
        return '今日はここまで。続きは明日か、Proで使える';
      case 'PLAN_REQUIRED':
        return 'この機能はProで使えるよ';
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
    unawaited(
      showAppErrorDialog(
        context: context,
        title: 'エラーが発生したよ',
        message: message,
        errorCode: error.errorCode,
        detail: detailMessage,
      ),
    );
  }

  void _openProUpgradePage() {
    if (_isProActive()) {
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (upgradeContext) => ProUpgradeScreen(
          isProActive: _isProActive(),
          onTapChangePro: () {
            Navigator.of(upgradeContext).push(
              MaterialPageRoute(
                builder: (settingsContext) => SettingsScreen(
                  apiClient: widget.apiClient,
                  purchaseService: widget.purchaseService,
                ),
              ),
            );
          },
          onOpenHiddenPage: () {
            Navigator.of(upgradeContext)
                .push(
                  MaterialPageRoute(
                    builder: (_) =>
                        PremiumCompHiddenScreen(apiClient: widget.apiClient),
                  ),
                )
                .then((approved) {
                  if (approved == true && mounted) {
                    setState(() {
                      _plan = 'pro';
                    });
                  }
                });
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CustomerGenerateSelectionStore.instance.selectionNotifier.removeListener(
      _customerSelectionListener,
    );
    _shareSubscription?.cancel();
    _generationLineTimer?.cancel();
    _shareSplashFadeTimer?.cancel();
    _shareSplashHideTimer?.cancel();
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
      ).showSnackBar(const SnackBar(content: Text('情報を反映したよ。返信案を更新するね')));
      await _generateCandidates();
    } on ApiError catch (error) {
      if (!mounted) return;
      _showErrorMessageBox(error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _updateRelationshipType(String relationshipType) async {
    if (_savingAdjustments || _relationshipType == relationshipType) {
      return;
    }

    final previous = _relationshipType;
    setState(() {
      _relationshipType = relationshipType;
      _savingAdjustments = true;
    });

    try {
      final snapshot = await widget.apiClient.getSettings();
      final updated = Map<String, dynamic>.from(snapshot.settings);
      updated['relationship_type'] = relationshipType;
      await widget.apiClient.updateSettings(updated, snapshot.etag);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        _relationshipType = previous;
        _savingAdjustments = false;
      });
      _showErrorMessageBox(error);
      return;
    }

    if (!mounted) return;
    setState(() {
      _savingAdjustments = false;
    });
  }

  bool _isProActive() =>
      widget.purchaseService.isPro || _plan == 'pro' || _plan == 'premium';

  String _normalizeReplyLengthPref(String? value, {required bool isPro}) {
    const freeValue = 'short';
    const proValues = {'standard', 'long'};
    final resolved = (value == null || value.isEmpty) ? 'standard' : value;
    if (isPro || !proValues.contains(resolved)) {
      return resolved;
    }
    return freeValue;
  }

  String _normalizeLineBreakPref(String? value, {required bool isPro}) {
    const freeValue = 'few';
    const proValues = {'infer', 'many'};
    final resolved = (value == null || value.isEmpty) ? 'infer' : value;
    if (isPro || !proValues.contains(resolved)) {
      return resolved;
    }
    return freeValue;
  }

  String _normalizeEmojiAmountPref(String? value, {required bool isPro}) {
    const freeValue = 'none';
    const proValues = {'standard', 'many'};
    final resolved = (value == null || value.isEmpty) ? 'standard' : value;
    if (isPro || !proValues.contains(resolved)) {
      return resolved;
    }
    return freeValue;
  }

  String _normalizeReactionLevelPref(String? value, {required bool isPro}) {
    const freeValue = 'low';
    const proValues = {'standard', 'high'};
    final resolved = (value == null || value.isEmpty) ? 'standard' : value;
    if (isPro || !proValues.contains(resolved)) {
      return resolved;
    }
    return freeValue;
  }

  String _normalizePartnerNameUsagePref(String? value, {required bool isPro}) {
    const freeValue = 'none';
    const proValues = {'once', 'many'};
    final resolved = (value == null || value.isEmpty) ? 'once' : value;
    if (isPro || !proValues.contains(resolved)) {
      return resolved;
    }
    return freeValue;
  }

  Future<void> _updateReplyLengthPref(String value) async {
    await _updateGenerateSetting(
      key: 'reply_length_pref',
      value: value,
      currentValue: _replyLengthPref,
      setLocal: () => _replyLengthPref = value,
      rollback: (previous) => _replyLengthPref = previous,
      isProOnly: value != 'short',
    );
  }

  Future<void> _updateLineBreakPref(String value) async {
    await _updateGenerateSetting(
      key: 'line_break_pref',
      value: value,
      currentValue: _lineBreakPref,
      setLocal: () => _lineBreakPref = value,
      rollback: (previous) => _lineBreakPref = previous,
      isProOnly: value != 'few',
    );
  }

  Future<void> _updateEmojiAmountPref(String value) async {
    await _updateGenerateSetting(
      key: 'emoji_amount_pref',
      value: value,
      currentValue: _emojiAmountPref,
      setLocal: () => _emojiAmountPref = value,
      rollback: (previous) => _emojiAmountPref = previous,
      isProOnly: value != 'none',
    );
  }

  Future<void> _updateReactionLevelPref(String value) async {
    await _updateGenerateSetting(
      key: 'reaction_level_pref',
      value: value,
      currentValue: _reactionLevelPref,
      setLocal: () => _reactionLevelPref = value,
      rollback: (previous) => _reactionLevelPref = previous,
      isProOnly: value != 'low',
    );
  }

  Future<void> _updatePartnerNameUsagePref(String value) async {
    await _updateGenerateSetting(
      key: 'partner_name_usage_pref',
      value: value,
      currentValue: _partnerNameUsagePref,
      setLocal: () => _partnerNameUsagePref = value,
      rollback: (previous) => _partnerNameUsagePref = previous,
      isProOnly: value != 'none',
    );
  }

  Future<void> _updateGenerateSetting({
    required String key,
    required String value,
    required String currentValue,
    required VoidCallback setLocal,
    required ValueChanged<String> rollback,
    required bool isProOnly,
  }) async {
    if (_savingAdjustments || currentValue == value) {
      return;
    }
    if (isProOnly && !_isProActive()) {
      setState(() {
        _dropdownResetVersion += 1;
      });
      _openProUpgradePage();
      return;
    }

    final previous = currentValue;
    setState(() {
      setLocal();
      _savingAdjustments = true;
    });

    try {
      final snapshot = await widget.apiClient.getSettings();
      final updated = Map<String, dynamic>.from(snapshot.settings);
      updated[key] = value;
      await widget.apiClient.updateSettings(updated, snapshot.etag);
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() {
        rollback(previous);
        _savingAdjustments = false;
      });
      _showErrorMessageBox(error);
      return;
    }

    if (!mounted) return;
    setState(() {
      _savingAdjustments = false;
    });
  }
}

class _LineShareSplashOverlay extends StatelessWidget {
  const _LineShareSplashOverlay({required this.opacity});

  static const double _splashImageScale = 1.55;

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      key: const Key('line_share_splash_overlay'),
      opacity: opacity,
      duration: _GenerateScreenState._lineShareSplashFadeDuration,
      curve: Curves.easeInOut,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.backgroundStart, AppColors.backgroundEnd],
              ),
            ),
          ),
          Transform.scale(
            scale: _splashImageScale,
            child: Image.asset(
              _GenerateScreenState._lineShareSplashImagePath,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.high,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.image_not_supported_outlined,
                    color: AppColors.metaText,
                    size: 48,
                  ),
                );
              },
            ),
          ),
          Container(color: AppColors.white.withValues(alpha: 0.08)),
        ],
      ),
    );
  }
}

class _SharePromptHero extends StatelessWidget {
  const _SharePromptHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        'まずは、LINEからトーク履歴を共有してね♪',
        style: AppTextStyles.primaryTitle.copyWith(fontSize: 28, height: 1.5),
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PersonaSummaryCard extends StatelessWidget {
  const _PersonaSummaryCard({
    required this.trueTypeLabel,
    required this.nightTypeLabel,
    required this.trueTypeImagePath,
    required this.nightTypeImagePath,
    required this.isDisabled,
  });

  final String trueTypeLabel;
  final String nightTypeLabel;
  final String? trueTypeImagePath;
  final String? nightTypeImagePath;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
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
          _PersonaValueRow(
            label: '普段の属性',
            value: trueTypeLabel,
            imagePath: trueTypeImagePath,
            isDisabled: isDisabled,
          ),
          const SizedBox(height: AppSpacing.xs),
          _PersonaValueRow(
            label: '夜の属性',
            value: nightTypeLabel,
            imagePath: nightTypeImagePath,
            isDisabled: isDisabled,
          ),
        ],
      ),
    );
  }
}

class _PersonaValueRow extends StatelessWidget {
  const _PersonaValueRow({
    required this.label,
    required this.value,
    required this.imagePath,
    required this.isDisabled,
  });

  final String label;
  final String value;
  final String? imagePath;
  final bool isDisabled;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(label, style: AppTextStyles.meta)),
        Expanded(
          flex: 2,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: AppTextStyles.body,
                  textAlign: TextAlign.right,
                ),
              ),
              if (imagePath != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Opacity(
                  opacity: isDisabled ? 0.38 : 1,
                  child: Image.asset(
                    imagePath!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.contain,
                  ),
                ),
              ],
            ],
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

class _GenerateAdjustmentsCard extends StatelessWidget {
  const _GenerateAdjustmentsCard({
    required this.currentRelationshipType,
    required this.currentReplyLengthPref,
    required this.currentLineBreakPref,
    required this.currentEmojiAmountPref,
    required this.currentReactionLevelPref,
    required this.currentPartnerNameUsagePref,
    required this.dropdownResetVersion,
    required this.selectedCombo,
    required this.isPro,
    required this.isSaving,
    required this.isDisabled,
    required this.onRelationshipChanged,
    required this.onReplyLengthChanged,
    required this.onLineBreakChanged,
    required this.onEmojiAmountChanged,
    required this.onReactionLevelChanged,
    required this.onPartnerNameUsageChanged,
    required this.onComboChanged,
  });

  final String currentRelationshipType;
  final String currentReplyLengthPref;
  final String currentLineBreakPref;
  final String currentEmojiAmountPref;
  final String currentReactionLevelPref;
  final String currentPartnerNameUsagePref;
  final int dropdownResetVersion;
  final int selectedCombo;
  final bool isPro;
  final bool isSaving;
  final bool isDisabled;
  final ValueChanged<String> onRelationshipChanged;
  final ValueChanged<String> onReplyLengthChanged;
  final ValueChanged<String> onLineBreakChanged;
  final ValueChanged<String> onEmojiAmountChanged;
  final ValueChanged<String> onReactionLevelChanged;
  final ValueChanged<String> onPartnerNameUsageChanged;
  final ValueChanged<int> onComboChanged;

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

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: isDisabled ? 0.62 : 1,
      child: Container(
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
            const AppSectionHeader(title: '返信案の調整'),
            const SizedBox(height: AppSpacing.sm),
            const Text('お客様との関係', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: currentRelationshipType,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white.withValues(alpha: 0.88),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.inputVertical,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
              items: _GenerateScreenState._relationshipLabels.entries.map((
                entry,
              ) {
                return DropdownMenuItem<String>(
                  value: entry.key,
                  child: Text(entry.value, style: AppTextStyles.body),
                );
              }).toList(),
              onChanged: (isSaving || isDisabled)
                  ? null
                  : (String? value) {
                      if (value == null) return;
                      unawaited(Haptics.selection());
                      onRelationshipChanged(value);
                    },
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('生成方針', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int>(
              key: ValueKey<String>(
                'combo-$selectedCombo-$dropdownResetVersion',
              ),
              initialValue: selectedCombo,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.white.withValues(alpha: 0.88),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.inputVertical,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  borderSide: BorderSide.none,
                ),
              ),
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
                      if (isProOnly && !isPro)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.proBadgeBackground,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Text(
                            'Pro',
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
              onChanged: isDisabled
                  ? null
                  : (int? value) {
                      if (value == null) return;
                      unawaited(Haptics.selection());
                      onComboChanged(value);
                    },
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProAwareDropdown(
              label: '返信の長さ',
              value: currentReplyLengthPref,
              resetVersion: dropdownResetVersion,
              isPro: isPro,
              isDisabled: isDisabled,
              isSaving: isSaving,
              options: const [
                ('短め', 'short', false),
                ('標準', 'standard', true),
                ('長め', 'long', true),
              ],
              onChanged: onReplyLengthChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProAwareDropdown(
              label: '改行設定',
              value: currentLineBreakPref,
              resetVersion: dropdownResetVersion,
              isPro: isPro,
              isDisabled: isDisabled,
              isSaving: isSaving,
              options: const [
                ('少なめ', 'few', false),
                ('履歴から推測', 'infer', true),
                ('多め', 'many', true),
              ],
              onChanged: onLineBreakChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProAwareDropdown(
              label: '絵文字の量',
              value: currentEmojiAmountPref,
              resetVersion: dropdownResetVersion,
              isPro: isPro,
              isDisabled: isDisabled,
              isSaving: isSaving,
              options: const [
                ('なし', 'none', false),
                ('標準', 'standard', true),
                ('多め', 'many', true),
              ],
              onChanged: onEmojiAmountChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProAwareDropdown(
              label: 'リアクション',
              value: currentReactionLevelPref,
              resetVersion: dropdownResetVersion,
              isPro: isPro,
              isDisabled: isDisabled,
              isSaving: isSaving,
              options: const [
                ('低め', 'low', false),
                ('標準', 'standard', true),
                ('高め', 'high', true),
              ],
              onChanged: onReactionLevelChanged,
            ),
            const SizedBox(height: AppSpacing.lg),
            _ProAwareDropdown(
              label: '相手の呼び方',
              value: currentPartnerNameUsagePref,
              resetVersion: dropdownResetVersion,
              isPro: isPro,
              isDisabled: isDisabled,
              isSaving: isSaving,
              options: const [
                ('使わない', 'none', false),
                ('1回程度', 'once', true),
                ('多めに', 'many', true),
              ],
              onChanged: onPartnerNameUsageChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProAwareDropdown extends StatelessWidget {
  const _ProAwareDropdown({
    required this.label,
    required this.value,
    required this.resetVersion,
    required this.isPro,
    required this.isDisabled,
    required this.isSaving,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final int resetVersion;
  final bool isPro;
  final bool isDisabled;
  final bool isSaving;
  final List<(String label, String value, bool isProOnly)> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          key: ValueKey<String>('pro-$label-$value-$resetVersion'),
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.white.withValues(alpha: 0.88),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.inputVertical,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              borderSide: BorderSide.none,
            ),
          ),
          items: options.map((option) {
            final isLocked = option.$3 && !isPro;
            return DropdownMenuItem<String>(
              value: option.$2,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      option.$1,
                      style: AppTextStyles.body.copyWith(
                        color: isLocked
                            ? AppColors.metaText
                            : AppColors.bodyText,
                      ),
                    ),
                  ),
                  if (isLocked)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.proBadgeBackground,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(
                        'Pro',
                        style: AppTextStyles.small.copyWith(
                          color: AppColors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (isDisabled || isSaving)
              ? null
              : (String? newValue) {
                  if (newValue == null) return;
                  unawaited(Haptics.selection());
                  onChanged(newValue);
                },
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
      padding: const EdgeInsets.only(top: AppSpacing.sm),
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
    required this.candidates,
    required this.copiedLabel,
    required this.candidateTapAction,
    required this.onCopyCandidate,
    required this.onShareCandidate,
  });

  final List<Candidate> candidates;
  final String? copiedLabel;
  final String candidateTapAction;
  final ValueChanged<Candidate> onCopyCandidate;
  final ValueChanged<Candidate> onShareCandidate;

  @override
  Widget build(BuildContext context) {
    assert(candidates.isEmpty || candidates.length == 3);

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
          const SizedBox(height: AppSpacing.sm),
          ...candidates.map((candidate) {
            final isCopied = copiedLabel == candidate.label;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _ResultCandidateCard(
                candidate: candidate,
                isCopied: isCopied,
                tapActionLabel: candidateTapAction == 'share'
                    ? 'タップで共有'
                    : 'タップでコピー',
                onTap: () {
                  if (candidateTapAction == 'share') {
                    onShareCandidate(candidate);
                    return;
                  }
                  onCopyCandidate(candidate);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ResultCandidateCard extends StatelessWidget {
  const _ResultCandidateCard({
    required this.candidate,
    required this.isCopied,
    required this.tapActionLabel,
    required this.onTap,
  });

  final Candidate candidate;
  final bool isCopied;
  final String tapActionLabel;
  final VoidCallback onTap;

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
        onTap: onTap,
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
                    isCopied ? 'コピー済み' : tapActionLabel,
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
