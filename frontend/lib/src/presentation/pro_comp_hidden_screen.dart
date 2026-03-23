import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/utils/haptics.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import '../domain/models.dart';
import '../infrastructure/api_client.dart';

class ProCompHiddenScreen extends StatefulWidget {
  const ProCompHiddenScreen({required this.apiClient, super.key});

  final AppApiClient apiClient;

  @override
  State<ProCompHiddenScreen> createState() => _ProCompHiddenScreenState();
}

class _ProCompHiddenScreenState extends State<ProCompHiddenScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('メールアドレスを入力してね')));
      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      final result = await widget.apiClient.requestProComp(email);
      if (!mounted) return;
      if (result.approved) {
        await Haptics.mediumImpact();
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('承認できなかったよ（依頼回数: ${result.requestCount}）')),
      );
    } on ApiError catch (e) {
      if (!mounted) return;
      String message;
      if (e.errorCode == 'ACCOUNT_LOCKED') {
        message = 'このアカウントはロックされているよ';
      } else if (e.errorCode == 'PRO_COMP_EMAIL_NOT_ALLOWED') {
        final r = e.remainingAttempts;
        message = r != null && r > 0
            ? '対象外のメールアドレスだよ。残り$r回でアカウントはロックされます'
            : '対象外のメールアドレスだよ。アカウントがロックされました';
      } else if (e.errorCode == 'PRO_COMP_EMAIL_ALREADY_APPROVED') {
        final r = e.remainingAttempts;
        message = r != null && r > 0
            ? 'このメールアドレスは既に承認済みだよ。残り$r回でアカウントはロックされます'
            : 'このメールアドレスは既に承認済みだよ。アカウントがロックされました';
      } else if (e.errorCode == 'PRO_COMP_REQUEST_ALREADY_USED') {
        final r = e.remainingAttempts;
        message = r != null && r > 0
            ? 'このメールは承認依頼回数が上限だよ。残り$r回でアカウントはロックされます'
            : 'このメールは承認依頼回数が上限だよ。アカウントがロックされました';
      } else if (e.errorCode == 'VALIDATION_FAILED') {
        message = 'メールアドレスの形式を確認してね';
      } else {
        message = '承認依頼に失敗したよ';
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('承認依頼')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppSectionHeader(title: 'メールアドレス入力'),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.email],
            decoration: const InputDecoration(
              hintText: 'example@domain.com',
              border: OutlineInputBorder(),
            ),
            style: AppTextStyles.body,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            text: _submitting ? '送信中...' : '送信',
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
