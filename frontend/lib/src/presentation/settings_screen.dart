import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_error_message_box.dart';
import 'package:sample_app/core/widgets/app_list_item.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';
import '../domain/persona_diagnosis.dart';
import '../domain/persona_type_helper.dart';
import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/billing_proof.dart';
import '../infrastructure/purchase_service.dart';
import 'about_privacy_screen.dart';
import 'diagnosis_screen.dart';
import 'help_screen.dart';
import 'migration_screen.dart';
import 'onboarding_screen.dart';
import 'persona_diagnosis_result_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'widgets/app_version_footer.dart';
import 'widgets/top_brand_header.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.apiClient,
    required this.purchaseService,
    super.key,
  });

  final AppApiClient apiClient;
  final PurchaseService purchaseService;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _statusTierKey = 'status_tier';
  static const String _billingTierKey = 'billing_tier';
  static const String _featureTierKey = 'feature_tier';
  static const String _planKey = 'plan';
  static const String _lastBillingDateKey = 'last_billing_date';
  static const String _nextBillingDateKey = 'next_billing_date';

  String _currentETag = '';
  Map<String, dynamic> _settings = {};
  bool _loading = true;
  bool _saving = false;
  bool _persisting = false;
  bool _pendingPersist = false;
  Timer? _autoPersistDebounce;
  ApiError? _error;
  final TextEditingController _ngPhraseController = TextEditingController();
  StreamSubscription<BillingProof>? _billingProofSubscription;

  // NGタグの定義
  static const Map<String, String> _ngTagLabels = {
    'no_preach': '説教しない',
    'no_pressure': 'プレッシャーをかけない',
    'no_romance_bait': '恋愛的な駆け引きNG',
    'no_money_talk': 'お金の話をしない',
    'no_sexual_joke': '性的な冗談をしない',
    'no_late_reply_blame': '返信の催促をしない',
  };

  @override
  void initState() {
    super.initState();
    _billingProofSubscription = widget.purchaseService.billingProofStream
        .listen(_verifyBillingProof);
    _loadSettings();
  }

  @override
  void dispose() {
    _billingProofSubscription?.cancel();
    _autoPersistDebounce?.cancel();
    _ngPhraseController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final snapshot = await widget.apiClient.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = _normalizeSettings(snapshot.settings);
        _currentETag = snapshot.etag;
        _loading = false;
      });

      _ensureBillingDatesIfNeeded();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  Future<void> _persistSettings({bool showSuccessMessage = false}) async {
    try {
      setState(() {
        _saving = true;
        _error = null;
      });

      await widget.apiClient.updateSettings(_settings, _currentETag);
      final snapshot = await widget.apiClient.getSettings();
      if (!mounted) return;
      setState(() {
        _settings = _normalizeSettings(snapshot.settings);
        _currentETag = snapshot.etag;
        _saving = false;
      });

      if (showSuccessMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('設定を反映しました')));
      }
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });

      if (e.errorCode == 'ETAG_MISMATCH') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定が更新されていたので、最新状態を読み直したよ')),
        );
        await _loadSettings();
      } else {
        await showAppErrorDialog(
          context: context,
          title: '設定の反映に失敗したよ',
          message: '通信状態を確認して、もう一度ためしてね。',
          errorCode: e.errorCode,
          detail: e.message,
        );
      }
    }
  }

  void _scheduleAutoPersist() {
    _autoPersistDebounce?.cancel();
    _autoPersistDebounce = Timer(const Duration(milliseconds: 200), () {
      if (!mounted) return;
      if (_persisting) {
        _pendingPersist = true;
        return;
      }
      unawaited(_persistSettingsLoop());
    });
  }

  Future<void> _persistSettingsLoop() async {
    _persisting = true;
    do {
      _pendingPersist = false;
      await _persistSettings();
    } while (_pendingPersist && mounted);
    _persisting = false;
  }

  void _updateSetting(String key, dynamic value, {bool autoPersist = true}) {
    setState(() {
      _settings[key] = value;
    });
    if (autoPersist) {
      _scheduleAutoPersist();
    }
  }

  Map<String, dynamic> _normalizeSettings(Map<String, dynamic> settings) {
    final normalized = Map<String, dynamic>.from(settings);
    normalized.putIfAbsent('relationship_type', () => 'new');
    normalized.putIfAbsent('reply_length_pref', () => 'standard');
    normalized.putIfAbsent('line_break_pref', () => 'infer');
    normalized.putIfAbsent('emoji_amount_pref', () => 'standard');
    normalized.putIfAbsent('reaction_level_pref', () => 'standard');
    normalized.putIfAbsent('partner_name_usage_pref', () => 'once');
    normalized.putIfAbsent('candidate_tap_action', () => 'copy');
    normalized['ng_tags'] =
        (normalized['ng_tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    normalized['ng_free_phrases'] =
        (normalized['ng_free_phrases'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    return normalized;
  }

  void _ensureBillingDatesIfNeeded() {
    if (!_isPaidMember(_settings)) {
      return;
    }

    final hasLastBilling = _parseDate(_settings[_lastBillingDateKey]) != null;
    final hasNextBilling = _parseDate(_settings[_nextBillingDateKey]) != null;
    if (hasLastBilling && hasNextBilling) {
      return;
    }

    final now = DateTime.now();
    final lastBillingDate = hasLastBilling
        ? _parseDate(_settings[_lastBillingDateKey])!
        : now;
    final nextBillingDate = hasNextBilling
        ? _parseDate(_settings[_nextBillingDateKey])!
        : lastBillingDate.add(const Duration(days: 30));

    setState(() {
      _settings[_lastBillingDateKey] = _formatDate(lastBillingDate);
      _settings[_nextBillingDateKey] = _formatDate(nextBillingDate);
    });
    _scheduleAutoPersist();
  }

  bool _isPaidMember(Map<String, dynamic> settings) {
    final statusTier = settings[_statusTierKey]?.toString();
    final billingTier = settings[_billingTierKey]?.toString();
    final featureTier = settings[_featureTierKey]?.toString();
    final plan = settings[_planKey]?.toString();

    if (statusTier == 'special' || billingTier == 'pro_comp') {
      return true;
    }
    if (widget.purchaseService.isPro) {
      return true;
    }
    if (featureTier == 'plus' || plan == 'pro' || billingTier == 'pro_store') {
      return true;
    }
    return false;
  }

  String _currentStatusLabel() {
    final statusTier = _settings[_statusTierKey]?.toString();
    final billingTier = _settings[_billingTierKey]?.toString();
    final featureTier = _settings[_featureTierKey]?.toString();
    final plan = _settings[_planKey]?.toString();

    if (statusTier == 'special' || billingTier == 'pro_comp') {
      return '特別会員';
    }
    if (widget.purchaseService.isPro ||
        featureTier == 'plus' ||
        plan == 'pro' ||
        billingTier == 'pro_store') {
      return 'Plus';
    }
    return 'Free';
  }

  DateTime? _parseDate(dynamic rawValue) {
    final value = rawValue?.toString();
    if (value == null || value.isEmpty) {
      return null;
    }

    final parsed = DateTime.tryParse(value);
    if (parsed != null) {
      return parsed;
    }

    final match = RegExp(
      r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$',
    ).firstMatch(value);
    if (match == null) {
      return null;
    }
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final day = int.tryParse(match.group(3)!);
    if (year == null || month == null || day == null) {
      return null;
    }
    return DateTime(year, month, day);
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y/$m/$d';
  }

  String _statusDateLabel(String key) {
    final parsed = _parseDate(_settings[key]);
    if (parsed != null) {
      return _formatDate(parsed);
    }
    return _formatDate(DateTime.now());
  }

  Future<void> _startRediagnosis() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (diagnosisContext) => DiagnosisScreen(
          onCompleted: (List<DiagnosisAnswer> answers) {
            return widget.apiClient.completeDiagnosis(answers).then((result) {
              if (!diagnosisContext.mounted) return result;
              Navigator.of(diagnosisContext).pop(true);
              return result;
            });
          },
        ),
      ),
    );

    if (!mounted || updated != true) return;
    await _loadSettings();
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('再診断を反映しました')));
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: const TopBrandHeader(),
      scrollable: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: AppErrorMessageBox(
                title: '設定の読み込みに失敗したよ',
                message: '通信状態を確認して、もう一度ためしてね。',
                errorCode: _error!.errorCode,
                detail: _error!.message,
                actionLabel: '再読込',
                onAction: _loadSettings,
              ),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '設定',
                    style: AppTextStyles.primaryTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildStatusSection(),
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: 'ペルソナ'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPersonaInfo(),
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: 'ペルソナ再診断'),
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    text: '再診断する',
                    onPressed: () {
                      _startRediagnosis();
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _buildCandidateTapActionSetting(),
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: 'デフォルトの返信スタイル'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildComboSetting(),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '返信の長さ・改行設定・絵文字の量・リアクション・相手の呼び方は、Generate画面で送信前に変更できるよ',
                    style: AppTextStyles.small.copyWith(
                      color: AppColors.bodyText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: '返信案のNG設定'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNGSetting(),
                  const SizedBox(height: AppSpacing.xl),
                  AppButton(
                    text: 'チュートリアルをもう一度確認する',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (onboardingContext) => OnboardingScreen(
                            onCompleted: () {
                              if (!onboardingContext.mounted) return;
                              Navigator.of(onboardingContext).pop();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  if (!widget.purchaseService.isPro) ...[
                    const SizedBox(height: AppSpacing.xl),
                    const AppSectionHeader(title: 'Plus版（月額2,980円）'),
                    const SizedBox(height: AppSpacing.sm),
                    _buildPurchaseSection(),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  _buildAdvancedSettingsAccordion(),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _saving ? Icons.sync : Icons.check_circle_outline,
                          size: 18,
                          color: AppColors.metaText,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          _saving ? '変更を反映中...' : '変更は自動で反映されます',
                          style: AppTextStyles.small,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  const AppVersionFooter(),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
    );
  }

  Widget _buildStatusSection() {
    final status = _currentStatusLabel();
    final showBillingDates = status == 'Plus' || status == '特別会員';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: '現在のステータス'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SettingRow(label: '会員種別', value: status),
              if (showBillingDates) ...[
                const SizedBox(height: AppSpacing.sm),
                _SettingRow(
                  label: '前回の更新日',
                  value: _statusDateLabel(_lastBillingDateKey),
                ),
                const SizedBox(height: AppSpacing.sm),
                _SettingRow(
                  label: '次回の更新日',
                  value: _statusDateLabel(_nextBillingDateKey),
                ),
              ],
            ],
          ),
        ),
        if (showBillingDates) ...[
          const SizedBox(height: AppSpacing.xs),
          Align(
            alignment: Alignment.centerRight,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              onTap: () {
                unawaited(Haptics.lightImpact());
                _openSubscriptionManagement();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  '解約はこちら',
                  style: AppTextStyles.small.copyWith(
                    color: AppColors.metaText,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonaInfo() {
    final trueTypeValue = _settings['true_self_type']?.toString() ?? '診断待機中...';
    final nightTypeValue =
        _settings['night_self_type']?.toString() ?? '診断待機中...';

    final trueTypeDisplay = trueTypeValue == '診断待機中...'
        ? trueTypeValue
        : getTrueSelfTypeName(trueTypeValue);
    final nightTypeDisplay = nightTypeValue == '診断待機中...'
        ? nightTypeValue
        : getNightSelfTypeName(nightTypeValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: trueTypeValue != '診断待機中...' && nightTypeValue != '診断待機中...'
              ? () {
                  unawaited(Haptics.lightImpact());
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => PersonaDiagnosisResultScreen(
                        trueType: trueTypeValue,
                        nightType: nightTypeValue,
                        assertiveness:
                            (_settings['style_assertiveness'] as num?)
                                ?.toInt() ??
                            50,
                        warmth:
                            (_settings['style_warmth'] as num?)?.toInt() ?? 50,
                        riskGuard:
                            (_settings['style_risk_guard'] as num?)?.toInt() ??
                            50,
                      ),
                    ),
                  );
                }
              : null,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm),
              color: trueTypeValue != '診断待機中...' ? AppColors.highlight : null,
            ),
            padding: const EdgeInsets.all(AppSpacing.inputVertical),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingRow(label: '普段の属性', value: trueTypeDisplay),
                if (trueTypeValue != '診断待機中...')
                  _SettingTypeImage(
                    imagePath: getTrueSelfTypeImagePath(trueTypeValue),
                  ),
                const SizedBox(height: AppSpacing.inputVertical),
                _SettingRow(label: '夜の属性', value: nightTypeDisplay),
                if (nightTypeValue != '診断待機中...')
                  _SettingTypeImage(
                    imagePath: getNightSelfTypeImagePath(nightTypeValue),
                  ),
                if (trueTypeValue != '診断待機中...')
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Text(
                      'タップして詳しく見る →',
                      style: AppTextStyles.small.copyWith(
                        color: AppColors.bodyText,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComboSetting() {
    final currentCombo = (_settings['combo_id'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          style: _settingsSegmentedStyle(),
          segments: const [
            ButtonSegment(value: 0, label: Text('来店約束')),
            ButtonSegment(value: 1, label: Text('休眠復活')),
          ],
          selected: <int>{currentCombo},
          onSelectionChanged: (Set<int> newSelection) {
            unawaited(Haptics.selection());
            _updateSetting('combo_id', newSelection.first);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Plus版ではさらに 4種類の方針が選択できます',
          style: AppTextStyles.small.copyWith(color: AppColors.bodyText),
        ),
      ],
    );
  }

  Widget _buildCandidateTapActionSetting() {
    final currentTapAction =
        _settings['candidate_tap_action']?.toString() ?? 'copy';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('返信案のタップ', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          style: _settingsSegmentedStyle().copyWith(
            minimumSize: const WidgetStatePropertyAll<Size>(
              Size.fromHeight(AppSpacing.xxl),
            ),
          ),
          segments: const [
            ButtonSegment(value: 'copy', label: Text('コピー')),
            ButtonSegment(value: 'share', label: Text('共有')),
          ],
          selected: <String>{currentTapAction},
          onSelectionChanged: (Set<String> newSelection) {
            unawaited(Haptics.selection());
            _updateSetting('candidate_tap_action', newSelection.first);
          },
        ),
      ],
    );
  }

  ButtonStyle _settingsSegmentedStyle() {
    return ButtonStyle(
      backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.buttonBackground;
        }
        return AppColors.white.withValues(alpha: 0.75);
      }),
      foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.white;
        }
        return AppColors.bodyText;
      }),
      side: WidgetStateProperty.resolveWith<BorderSide?>((states) {
        if (states.contains(WidgetState.selected)) {
          return const BorderSide(color: AppColors.buttonBackground);
        }
        return const BorderSide(color: AppColors.separator);
      }),
    );
  }

  Widget _buildNGSetting() {
    final ngTags =
        (_settings['ng_tags'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    final ngFreePhrases =
        (_settings['ng_free_phrases'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          children: _ngTagLabels.entries.map((entry) {
            final isSelected = ngTags.contains(entry.key);
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                onTap: () {
                  unawaited(Haptics.selection());
                  final updatedTags = List<String>.from(ngTags);
                  if (isSelected) {
                    updatedTags.remove(entry.key);
                  } else {
                    updatedTags.add(entry.key);
                  }
                  _updateSetting('ng_tags', updatedTags);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.inputVertical,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.lightPink.withValues(alpha: 0.55)
                        : AppColors.white.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.secondaryPink
                          : AppColors.separator,
                    ),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        child: Icon(
                          isSelected
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 18,
                          color: isSelected
                              ? AppColors.secondaryPink
                              : AppColors.metaText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: AppTextStyles.body.copyWith(
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.lg),
        const Text('禁止フレーズ（自由入力、最大10件）', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ngPhraseController,
                decoration: const InputDecoration(
                  hintText: '例: 会いたい',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.inputVertical,
                    vertical: AppSpacing.sm,
                  ),
                ),
                maxLength: 64,
                onSubmitted: (_) => _addNgPhrase(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: ngFreePhrases.length >= 10 ? null : _addNgPhrase,
              color: AppColors.primaryPink,
            ),
          ],
        ),
        if (ngFreePhrases.length >= 10)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              '※ 最大10件まで登録できます',
              style: AppTextStyles.small.copyWith(color: AppColors.error),
            ),
          ),
        const SizedBox(height: AppSpacing.inputVertical),
        if (ngFreePhrases.isEmpty)
          Text(
            '禁止フレーズが登録されていません',
            style: AppTextStyles.small.copyWith(color: AppColors.bodyText),
          )
        else
          ...ngFreePhrases.asMap().entries.map((entry) {
            final index = entry.key;
            final phrase = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.inputVertical,
                        vertical: AppSpacing.sm,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.lightPink.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: Text(phrase),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {
                      unawaited(Haptics.lightImpact());
                      _removeNgPhrase(index);
                    },
                    color: AppColors.metaText,
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  void _addNgPhrase() {
    final phrase = _ngPhraseController.text.trim();
    if (phrase.isEmpty) return;

    final ngFreePhrases =
        (_settings['ng_free_phrases'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (ngFreePhrases.length >= 10) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('禁止フレーズは最大10件までです')));
      return;
    }

    if (ngFreePhrases.contains(phrase)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('既に登録されています')));
      return;
    }

    unawaited(Haptics.lightImpact());
    ngFreePhrases.add(phrase);
    _updateSetting('ng_free_phrases', ngFreePhrases);
    _ngPhraseController.clear();
  }

  void _removeNgPhrase(int index) {
    final ngFreePhrases =
        (_settings['ng_free_phrases'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (index >= 0 && index < ngFreePhrases.length) {
      ngFreePhrases.removeAt(index);
      _updateSetting('ng_free_phrases', ngFreePhrases);
    }
  }

  Widget _buildPurchaseSection() {
    final isPro = widget.purchaseService.isPro;

    if (isPro) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Plus版の特典:', style: AppTextStyles.body),
            const SizedBox(height: AppSpacing.sm),
            const Text(
              '• 1日100回まで生成可能（Freeは3回）\n• 推定メーター表示\n• すべての生成方針が選択可能',
              style: AppTextStyles.body,
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              text: 'Plusにアップグレード（月額2,980円）',
              onPressed: () {
                _purchasePro();
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdvancedSettingsAccordion() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: const Text('サポート・規約・その他設定', style: AppTextStyles.body),
          iconColor: AppColors.metaText,
          collapsedIconColor: AppColors.metaText,
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            0,
            AppSpacing.sm,
            AppSpacing.sm,
          ),
          children: [
            _InfoLinkTile(
              label: '利用規約',
              onTap: () {
                unawaited(Haptics.lightImpact());
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const TermsOfServiceScreen(),
                  ),
                );
              },
            ),
            _InfoLinkTile(
              label: 'プライバシーポリシー',
              onTap: () {
                unawaited(Haptics.lightImpact());
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const PrivacyPolicyScreen(),
                  ),
                );
              },
            ),
            _InfoLinkTile(
              label: 'ヘルプ（使い方）',
              onTap: () {
                unawaited(Haptics.lightImpact());
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const HelpScreen()),
                );
              },
            ),
            _InfoLinkTile(
              label: 'このアプリについて',
              onTap: () {
                unawaited(Haptics.lightImpact());
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const AboutPrivacyScreen(),
                  ),
                );
              },
            ),
            _InfoLinkTile(
              label: 'オープンソースライセンス',
              onTap: () {
                unawaited(Haptics.lightImpact());
                showLicensePage(
                  context: context,
                  applicationName: 'Permy',
                  applicationIcon: Image.asset(
                    'assets/images/icons/permy_icon.png',
                    width: 48,
                    height: 48,
                  ),
                );
              },
            ),
            _InfoLinkTile(
              label: '端末移行の設定',
              onTap: () {
                unawaited(Haptics.lightImpact());
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        MigrationScreen(apiClient: widget.apiClient),
                  ),
                );
              },
            ),
            _InfoLinkTile(
              label: '購入を復元',
              onTap: () {
                unawaited(Haptics.lightImpact());
                _restorePurchases();
              },
            ),
            _InfoLinkTile(
              label: 'サブスクリプション管理',
              onTap: () {
                unawaited(Haptics.lightImpact());
                _openSubscriptionManagement();
              },
            ),
            _InfoLinkTile(
              label: 'アカウントを削除する',
              onTap: () {
                unawaited(Haptics.lightImpact());
                _confirmDeleteAccount();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _purchasePro() async {
    try {
      final available = await widget.purchaseService.isAvailable();
      if (!available) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ストアが利用できません')));
        return;
      }

      await widget.purchaseService.purchase();
      // 購入結果は PurchaseService のリスナーで処理される
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('購入処理を開始しました')));
    } catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(
        context: context,
        title: '購入に失敗したよ',
        message: 'しばらく待って、もう一度ためしてね。',
        detail: e.toString(),
      );
    }
  }

  Future<void> _restorePurchases() async {
    try {
      await widget.purchaseService.restorePurchases();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('購入を復元しました')));
      setState(() {}); // 状態を更新
    } catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(
        context: context,
        title: '復元に失敗したよ',
        message: '通信状態を確認して、もう一度ためしてね。',
        detail: e.toString(),
      );
    }
  }

  Future<void> _openSubscriptionManagement() async {
    // iOS/Androidのサブスク管理画面へ遷移
    final Uri uri;
    if (Theme.of(context).platform == TargetPlatform.iOS) {
      uri = Uri.parse('https://apps.apple.com/account/subscriptions');
    } else {
      uri = Uri.parse('https://play.google.com/store/account/subscriptions');
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('サブスク管理画面を開けませんでした')));
    }
  }

  Future<void> _confirmDeleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('アカウントを削除しますか？'),
        content: const Text('すべてのデータが削除され、復元できません。この操作は取り消せません。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('削除する'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteAccount();
    }
  }

  Future<void> _deleteAccount() async {
    try {
      await widget.apiClient.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('アカウントを削除しました')));
    } on ApiError catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(
        context: context,
        title: '削除に失敗したよ',
        message: '時間をおいて、もう一度ためしてね。',
        errorCode: e.errorCode,
        detail: e.message,
      );
    }
  }

  Future<void> _verifyBillingProof(BillingProof proof) async {
    try {
      await widget.apiClient.verifyBilling(
        platform: proof.platform,
        productId: proof.productId,
        purchaseToken: proof.purchaseToken,
      );
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _settings[_lastBillingDateKey] = _formatDate(now);
        _settings[_nextBillingDateKey] = _formatDate(
          now.add(const Duration(days: 30)),
        );
      });
      _scheduleAutoPersist();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('課金状態をサーバーに反映しました')));
    } on ApiError catch (e) {
      if (!mounted) return;
      String title = '課金状態の反映に失敗したよ';
      String message = '通信状態を確認して、もう一度ためしてね。';
      if (e.errorCode == 'BILLING_NOT_CONFIGURED') {
        title = '課金検証は準備中だよ';
        message = '運用設定が完了するまで少し待ってね。';
      } else if (e.errorCode == 'BILLING_PRODUCT_INVALID') {
        title = '商品IDが無効だよ';
        message = 'アプリを更新してから、もう一度購入を試してね。';
      } else if (e.errorCode == 'BILLING_RECEIPT_INVALID') {
        title = '購入情報を確認できなかったよ';
        message = '購入を復元して、再度試してね。';
      }
      await showAppErrorDialog(
        context: context,
        title: title,
        message: message,
        errorCode: e.errorCode,
        detail: e.message,
      );
    }
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.inputVertical),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.body),
          Text(
            value,
            style: AppTextStyles.body.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _InfoLinkTile extends StatelessWidget {
  const _InfoLinkTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      title: label,
      trailing: const Icon(Icons.chevron_right, color: AppColors.metaText),
      showSeparator: true,
      onTap: onTap,
    );
  }
}

class _SettingTypeImage extends StatelessWidget {
  const _SettingTypeImage({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    if (imagePath == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AspectRatio(
          aspectRatio: 16 / 7,
          child: Image.asset(
            imagePath!,
            fit: BoxFit.cover,
            errorBuilder: (_, error, stackTrace) => Container(
              color: AppColors.highlight,
              alignment: Alignment.center,
              child: const Icon(Icons.image_not_supported_outlined),
            ),
          ),
        ),
      ),
    );
  }
}
