import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../domain/persona_diagnosis.dart';
import '../domain/persona_type_helper.dart';
import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/purchase_service.dart';
import 'about_privacy_screen.dart';
import 'diagnosis_screen.dart';
import 'help_screen.dart';
import 'migration_screen.dart';
import 'onboarding_screen.dart';
import 'persona_diagnosis_result_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';
import 'widgets/primary_button.dart';

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
  ApiError? _error;
  final TextEditingController _ngPhraseController = TextEditingController();

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
    _loadSettings();
  }

  @override
  void dispose() {
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
        _settings = Map<String, dynamic>.from(snapshot.settings);
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

  Future<void> _saveSettings() async {
    try {
      setState(() {
        _saving = true;
        _error = null;
      });

      await widget.apiClient.updateSettings(_settings, _currentETag);
      if (!mounted) return;
      setState(() {
        _saving = false;
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('設定を保存しました')));
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });

      if (e.errorCode == 'ETAG_MISMATCH') {
        // 再取得を促す
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('設定が更新されました。再読込してください。')));
        await _loadSettings();
      }
    }
  }

  void _updateSetting(String key, dynamic value) {
    setState(() {
      _settings[key] = value;
    });
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
            const Text('設定'),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [PermyColors.backgroundStart, PermyColors.backgroundEnd],
          ),
        ),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('エラー: ${_error!.errorCode}'),
                      const SizedBox(height: 16),
                      PrimaryButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          _loadSettings();
                        },
                        child: const Text('再読込'),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionHeader(title: 'ペルソナ'),
                        const SizedBox(height: 12),
                        _buildPersonaInfo(),
                        const SizedBox(height: 32),
                        const SectionHeader(title: 'ペルソナ再診断'),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _startRediagnosis();
                          },
                          child: const Text('再診断する'),
                        ),
                        const SizedBox(height: 32),
                        SectionHeader(title: '生成設定'),
                        const SizedBox(height: 12),
                        _buildComboSetting(),
                        const SizedBox(height: 32),
                        SectionHeader(title: 'NG設定'),
                        const SizedBox(height: 12),
                        _buildNGSetting(),
                        const SizedBox(height: 32),
                        SectionHeader(title: '端末移行'),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => MigrationScreen(
                                  apiClient: widget.apiClient,
                                ),
                              ),
                            );
                          },
                          child: const Text('端末移行の設定'),
                        ),
                        const SizedBox(height: 32),
                        SectionHeader(title: 'チュートリアル'),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (onboardingContext) =>
                                    OnboardingScreen(
                                      onCompleted: () {
                                        if (!onboardingContext.mounted) return;
                                        Navigator.of(onboardingContext).pop();
                                      },
                                    ),
                              ),
                            );
                          },
                          child: const Text('チュートリアルをもう一度確認する'),
                        ),
                        const SizedBox(height: 32),
                        SectionHeader(title: 'Pro版（月額2,980円）'),
                        const SizedBox(height: 12),
                        _buildPurchaseSection(),
                        const SizedBox(height: 32),
                        SectionHeader(title: 'もっと知る'),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const TermsOfServiceScreen(),
                              ),
                            );
                          },
                          child: const Text('利用規約'),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const PrivacyPolicyScreen(),
                              ),
                            );
                          },
                          child: const Text('プライバシーポリシー'),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const HelpScreen(),
                              ),
                            );
                          },
                          child: const Text('ヘルプ（使い方）'),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AboutPrivacyScreen(),
                              ),
                            );
                          },
                          child: const Text('このアプリについて'),
                        ),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
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
                          child: const Text('オープンソースライセンス'),
                        ),
                        const SizedBox(height: 32),
                        SectionHeader(title: 'アカウント管理'),
                        const SizedBox(height: 12),
                        PrimaryButton(
                          onPressed: () {
                            HapticFeedback.mediumImpact();
                            _confirmDeleteAccount();
                          },
                          child: const Text('アカウントを削除する'),
                        ),
                        const SizedBox(height: 32),
                        PrimaryButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  HapticFeedback.mediumImpact();
                                  _saveSettings();
                                },
                          isLoading: _saving,
                          child: const Text('保存'),
                        ),
                      ],
                    ),
                  ),
                ),
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
                  HapticFeedback.lightImpact();
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
              borderRadius: BorderRadius.circular(8),
              color: trueTypeValue != '診断待機中...' ? PermyColors.highlight : null,
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _SettingRow(label: '普段の属性', value: trueTypeDisplay),
                const SizedBox(height: 12),
                _SettingRow(label: '夜の属性', value: nightTypeDisplay),
                if (trueTypeValue != '診断待機中...')
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'タップして詳しく見る →',
                      style: const TextStyle(
                        fontSize: 12,
                        color: PermyColors.primaryPink,
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
        const Text('生成方針'),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('来店約束')),
            ButtonSegment(value: 1, label: Text('休眠復活')),
          ],
          selected: <int>{currentCombo},
          onSelectionChanged: (Set<int> newSelection) {
            HapticFeedback.selectionClick();
            _updateSetting('combo_id', newSelection.first);
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Pro版ではさらに 4種類の方針が選択できます',
          style: const TextStyle(fontSize: 12, color: PermyColors.bodyText),
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
        const Text(
          'NGタグ（複数選択可）',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: _ngTagLabels.entries.map((entry) {
            final isSelected = ngTags.contains(entry.key);
            return FilterChip(
              label: Text(entry.value),
              selected: isSelected,
              onSelected: (selected) {
                HapticFeedback.selectionClick();
                final updatedTags = List<String>.from(ngTags);
                if (selected) {
                  updatedTags.add(entry.key);
                } else {
                  updatedTags.remove(entry.key);
                }
                _updateSetting('ng_tags', updatedTags);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        const Text(
          '禁止フレーズ（自由入力、最大10件）',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _ngPhraseController,
                decoration: const InputDecoration(
                  hintText: '例: 会いたい',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                maxLength: 64,
                onSubmitted: (_) => _addNgPhrase(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.add_circle),
              onPressed: ngFreePhrases.length >= 10 ? null : _addNgPhrase,
              color: PermyColors.primaryPink,
            ),
          ],
        ),
        if (ngFreePhrases.length >= 10)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              '※ 最大10件まで登録できます',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ),
        const SizedBox(height: 12),
        if (ngFreePhrases.isEmpty)
          const Text(
            '禁止フレーズが登録されていません',
            style: TextStyle(fontSize: 12, color: PermyColors.bodyText),
          )
        else
          ...ngFreePhrases.asMap().entries.map((entry) {
            final index = entry.key;
            final phrase = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: PermyColors.lightPink.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(phrase),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _removeNgPhrase(index);
                    },
                    color: Colors.grey,
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

    HapticFeedback.lightImpact();
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
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PermyColors.highlight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Pro版をご利用中です\n1日100回まで生成できます',
              style: TextStyle(fontSize: 14),
              textAlign: TextAlign.center,
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Pro版の特典:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '• 1日100回まで生成可能（Freeは3回）\n• 推定メーター表示\n• すべての生成方針が選択可能',
                style: TextStyle(fontSize: 14, color: PermyColors.bodyText),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  _purchasePro();
                },
                child: const Text('Proにアップグレード（月額2,980円）'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        PrimaryButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            _restorePurchases();
          },
          child: const Text('購入を復元'),
        ),
        const SizedBox(height: 12),
        PrimaryButton(
          onPressed: () {
            HapticFeedback.mediumImpact();
            _openSubscriptionManagement();
          },
          child: const Text('サブスクリプション管理'),
        ),
      ],
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
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
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({required this.title, super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: PermyColors.primaryTitle,
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: PermyColors.bodyText)),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: PermyColors.bodyText,
            ),
          ),
        ],
      ),
    );
  }
}
