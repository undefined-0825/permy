import 'package:flutter/material.dart';

import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import 'migration_screen.dart';

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('設定を保存しました')),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e;
      });

      if (e.errorCode == 'ETAG_MISMATCH') {
        // 再取得を促す
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('設定が更新されました。再読込してください。')),
        );
        await _loadSettings();
      }
    }
  }

  void _updateSetting(String key, dynamic value) {
    setState(() {
      _settings[key] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('設定')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('エラー: ${_error!.errorCode}'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadSettings,
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
                          ElevatedButton(
                            onPressed: () {
                              // 再診断フロー（別画面）
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('再診断は別途実装予定')),
                              );
                            },
                            child: const Text('再診断する'),
                          ),
                          const SizedBox(height: 32),
                          const SectionHeader(title: '生成設定'),
                          const SizedBox(height: 12),
                          _buildComboSetting(),
                          const SizedBox(height: 32),
                          const SectionHeader(title: 'NG設定'),
                          const SizedBox(height: 12),
                          _buildNGSetting(),
                          const SizedBox(height: 32),
                          const SectionHeader(title: '端末移行'),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () {
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
                          ElevatedButton(
                            onPressed: _saving ? null : _saveSettings,
                            child: _saving
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('保存'),
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
    );
  }

  Widget _buildPersonaInfo() {
    final trueType =
        _settings['true_self_type']?.toString() ?? '診断待機中...';
    final nightType =
        _settings['night_self_type']?.toString() ?? '診断待機中...';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SettingRow(
          label: 'ホンネの属性',
          value: trueType,
        ),
        const SizedBox(height: 12),
        _SettingRow(
          label: 'ヨルノジブン属性',
          value: nightType,
        ),
      ],
    );
  }

  Widget _buildComboSetting() {
    final currentCombo = (_settings['combo_id'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('生成戦術'),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(
              value: 0,
              label: Text('通常'),
            ),
            ButtonSegment(
              value: 1,
              label: Text('短め'),
            ),
            ButtonSegment(
              value: 2,
              label: Text('長め'),
            ),
          ],
          selected: <int>{currentCombo},
          onSelectionChanged: (Set<int> newSelection) {
            _updateSetting('combo_id', newSelection.first);
          },
        ),
      ],
    );
  }

  Widget _buildNGSetting() {
    final forbidden = (_settings['forbidden_type_ids'] as List?)
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
      style: Theme.of(context).textTheme.titleMedium,
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
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
