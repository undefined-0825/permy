import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import 'widgets/primary_button.dart';
import 'widgets/top_brand_header.dart';

class MigrationScreen extends StatefulWidget {
  const MigrationScreen({
    required this.apiClient,
    this.shareCodeHandler,
    super.key,
  });

  final AppApiClient apiClient;
  final Future<void> Function(String text)? shareCodeHandler;

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
    unawaited(Haptics.selection());
    Clipboard.setData(ClipboardData(text: _migrationCode)).then((_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('コードをコピーしました')));
    });
  }

  Future<void> _shareCode() async {
    unawaited(Haptics.selection());

    if (_migrationCode.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共有するコードがありません')));
      return;
    }

    final shareText =
        'Permy 端末移行コード\n'
        'コード: $_migrationCode\n'
        '有効期限: $_expiresAt';

    try {
      if (widget.shareCodeHandler != null) {
        await widget.shareCodeHandler!(shareText);
      } else {
        await Share.share(shareText, subject: 'Permy 端末移行コード');
      }

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共有シートを開きました')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('共有に失敗しました')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const TopBrandHeader(),
      body: Padding(padding: const EdgeInsets.all(16), child: _buildContent()),
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
          '端末移行',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.primaryTitle,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        const Text(
          '端末を移行しますか？',
          style: AppTextStyles.primaryTitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        const Text(
          'このアプリのアカウント情報を別の端末に移行できます。',
          style: AppTextStyles.body,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          onPressed: _loading
              ? null
              : () {
                  unawaited(Haptics.mediumImpact());
                  _handleIssueMigration();
                },
          isLoading: _loading,
          child: const Text('この端末から移行コードを発行'),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () {
            unawaited(Haptics.selection());
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
              color: AppColors.lightPink,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _error!.message,
              style: const TextStyle(color: AppColors.error),
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
            '端末移行',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryTitle,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const Text(
            '移行コードが発行されました',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: 0.9),
              border: Border.all(color: AppColors.separator),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              children: [
                const Text(
                  '12桁のコード',
                  style: TextStyle(fontSize: 12, color: AppColors.bodyText),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.bodyText,
                  ),
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
              unawaited(Haptics.selection());
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
            '端末移行',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryTitle,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
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
            decoration: const InputDecoration(
              labelText: '移行コード（12桁）',
              hintText: '000000000000',
              border: UnderlineInputBorder(),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.primaryPink, width: 2),
              ),
            ),
            keyboardType: TextInputType.number,
            maxLength: 12,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, letterSpacing: 1),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            onPressed: _loading
                ? null
                : () {
                    unawaited(Haptics.mediumImpact());
                    _handleConsumeMigration();
                  },
            isLoading: _loading,
            child: const Text('アカウントを引き継ぐ'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () {
              unawaited(Haptics.selection());
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
                color: AppColors.lightPink,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _error!.message,
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
