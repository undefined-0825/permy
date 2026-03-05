import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/token_store.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({required this.apiClient, super.key});

  final AppApiClient apiClient;

  @override
  State<MigrationScreen> createState() => _MigrationScreenState();
}

class _MigrationScreenState extends State<MigrationScreen> {
  int _currentStep = 0; // 0: 選択, 1: 発行, 2: 消費
  bool _loading = false;
  ApiError? _error;
  String _migrationCode = '';
  String _expiresAt = '';
  final TextEditingController _codeInputController = TextEditingController();

  @override
  void dispose() {
    _codeInputController.dispose();
    super.dispose();
  }

  Future<void> _handleIssueMigration() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final result = await widget.apiClient.issueMigrationCode();
      if (!mounted) return;
      setState(() {
        _migrationCode = result.migrationCode;
        _expiresAt = result.expiresAt;
        _currentStep = 1;
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

  Future<void> _handleConsumeMigration() async {
    final code = _codeInputController.text.trim();
    if (code.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('12桁コードを入力してください')));
      return;
    }

    try {
      setState(() {
        _loading = true;
        _error = null;
      });

      final result = await widget.apiClient.consumeMigrationCode(code);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('端末情報を引き継ぎました（ユーザーID: ${result.userId}）')),
      );

      // 画面を戻る
      Navigator.of(context).pop();
    } on ApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });

      String message = 'エラーが発生しました';
      if (e.errorCode == 'MIGRATION_CODE_INVALID') {
        message = 'コードが無効です。入力を確認してください。';
      } else if (e.errorCode == 'MIGRATION_CODE_EXPIRED') {
        message = 'コードの有効期限が切れました。新しいコードを発行してください。';
      } else if (e.errorCode == 'MIGRATION_CODE_ALREADY_USED') {
        message = 'このコードは既に使用済みです。新しいコードを発行してください。';
      } else if (e.errorCode == 'RATE_LIMITED') {
        message = '試行回数が多すぎます。しばらく待ってからお試しください。';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _copyCodeToClipboard() {
    Clipboard.setData(ClipboardData(text: _migrationCode)).then((_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コードをコピーしました')));
    });
  }

  void _shareCode() {
    // OS 共有（実装例）
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('共有機能は後日実装予定')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('端末移行')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_currentStep == 0) {
      return _buildSelectScreen();
    } else if (_currentStep == 1) {
      return _buildIssueScreen();
    } else {
      return _buildConsumeScreen();
    }
  }

  Widget _buildSelectScreen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '端末を移行しますか？',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Text('このアプリのアカウント情報を別の端末に移行できます。', textAlign: TextAlign.center),
        const SizedBox(height: 32),
        ElevatedButton(
          onPressed: _loading ? null : _handleIssueMigration,
          child: _loading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('この端末から移行コードを発行'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            setState(() {
              _currentStep = 2;
            });
          },
          child: const Text('別の端末からコードを入力'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!.message,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildIssueScreen() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '移行コードが発行されました',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  '12桁のコード',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  _migrationCode,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  '有効期限: $_expiresAt',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.content_copy),
            onPressed: _copyCodeToClipboard,
            label: const Text('コードをコピー'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.share),
            onPressed: _shareCode,
            label: const Text('共有する'),
          ),
          const SizedBox(height: 24),
          const Text(
            '新しい端末で以下の手順を実行してください：\n'
            '1. 新しい端末でこのアプリを起動\n'
            '2. 設定 → 端末移行 → 「別の端末からコードを入力」\n'
            '3. 上のコードを入力して完了',
            style: TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
                _migrationCode = '';
                _expiresAt = '';
                _error = null;
              });
            },
            child: const Text('戻る'),
          ),
        ],
      ),
    );
  }

  Widget _buildConsumeScreen() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '移行コードを入力',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const Text(
            'もとの端末から発行された12桁のコードを入力してください。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeInputController,
            decoration: InputDecoration(
              labelText: '移行コード（12桁）',
              hintText: '000000000000',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            keyboardType: TextInputType.number,
            maxLength: 12,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loading ? null : _handleConsumeMigration,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('アカウントを引き継ぐ'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
                _codeInputController.clear();
                _error = null;
              });
            },
            child: const Text('戻る'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!.message,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
