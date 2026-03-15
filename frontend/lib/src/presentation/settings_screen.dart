import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import 'package:sample_app/core/widgets/app_button.dart';
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

  static const Map<String, String> _replyLengthLabels = {
    'short': '短め',
    'standard': '標準',
    'long': '長め',
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('設定の反映に失敗したよ。もう一度ためしてね')));
      }
    }
  }

  void _scheduleAutoPersist() {
    _autoPersistDebounce?.cancel();
    _autoPersistDebounce = Timer(const Duration(milliseconds: 450), () {
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('エラー: ${_error!.errorCode}'),
                  const SizedBox(height: AppSpacing.md),
                  AppButton(
                    text: '再読込',
                    onPressed: () {
                      _loadSettings();
                    },
                  ),
                ],
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
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: 'デフォルトの返信スタイル'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildComboSetting(),
                  const SizedBox(height: AppSpacing.lg),
                  _buildReplyLengthSetting(),
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: '返信案のNG設定'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildNGSetting(),
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: 'チュートリアル'),
                  const SizedBox(height: AppSpacing.sm),
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
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: 'Plus版（月額2,980円）'),
                  const SizedBox(height: AppSpacing.sm),
                  _buildPurchaseSection(),
                  const SizedBox(height: AppSpacing.xl),
                  const AppSectionHeader(title: 'サポート・規約・その他設定'),
                  const SizedBox(height: AppSpacing.sm),
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
                ],
              ),
            ),
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
                        color: AppColors.primaryPink,
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

  Widget _buildReplyLengthSetting() {
    final currentReplyLength =
        _settings['reply_length_pref']?.toString() ?? 'standard';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('返信の長さ', style: AppTextStyles.body),
        const SizedBox(height: AppSpacing.sm),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'short', label: Text('短め')),
            ButtonSegment(value: 'standard', label: Text('標準')),
            ButtonSegment(value: 'long', label: Text('長め')),
          ],
          selected: <String>{currentReplyLength},
          onSelectionChanged: (Set<String> newSelection) {
            unawaited(Haptics.selection());
            _updateSetting('reply_length_pref', newSelection.first);
          },
        ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isPro)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.highlight,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Text(
              'Plus版をご利用中です\n1日100回まで生成できます',
              style: AppTextStyles.body,
              textAlign: TextAlign.center,
            ),
          )
        else
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('購入に失敗しました: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('復元に失敗しました: $e')));
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('削除に失敗しました: ${e.errorCode}')));
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
      setState(() {});
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('課金状態をサーバーに反映しました')));
    } on ApiError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('課金状態の反映に失敗しました: ${e.errorCode}')));
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
