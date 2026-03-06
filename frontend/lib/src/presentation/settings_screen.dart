import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import '../domain/persona_diagnosis.dart';
import '../domain/persona_type_helper.dart';
import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import 'about_privacy_screen.dart';
import 'diagnosis_screen.dart';
import 'migration_screen.dart';
import 'onboarding_screen.dart';
import 'persona_diagnosis_result_screen.dart';
import 'widgets/primary_button.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({required this.apiClient, super.key});

  final AppApiClient apiClient;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _currentETag = '';
  Map<String, dynamic> _settings = {};
  bool _loading = true;
  bool _saving = false;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
          onCompleted: (List<DiagnosisAnswer> answers) async {
            await widget.apiClient.completeDiagnosis(answers);
            if (!diagnosisContext.mounted) return;
            Navigator.of(diagnosisContext).pop(true);
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
                        SectionHeader(title: 'もっと知る'),
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
    final forbidden =
        (_settings['forbidden_type_ids'] as List?)
            ?.map((e) => (e as num).toInt())
            .toList() ??
        [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('禁止ワード・表現を設定してください。\n実装は後日予定です。'),
        const SizedBox(height: 12),
        Text('現在の禁止設定: ${forbidden.isEmpty ? 'なし' : forbidden.join(', ')}'),
      ],
    );
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
