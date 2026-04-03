import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import '../domain/models.dart';

class CustomerFormScreen extends StatefulWidget {
  const CustomerFormScreen({super.key});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final TextEditingController _displayNameController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _callNameController = TextEditingController();
  final TextEditingController _areaTagController = TextEditingController();
  final TextEditingController _jobTagController = TextEditingController();
  final TextEditingController _memoSummaryController = TextEditingController();

  String _relationshipStage = 'new';

  @override
  void dispose() {
    _displayNameController.dispose();
    _nicknameController.dispose();
    _callNameController.dispose();
    _areaTagController.dispose();
    _jobTagController.dispose();
    _memoSummaryController.dispose();
    super.dispose();
  }

  void _submit() {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    final result = CreateCustomerInput(
      displayName: _displayNameController.text.trim(),
      nickname: _emptyToNull(_nicknameController.text),
      callName: _emptyToNull(_callNameController.text),
      areaTag: _emptyToNull(_areaTagController.text),
      jobTag: _emptyToNull(_jobTagController.text),
      memoSummary: _emptyToNull(_memoSummaryController.text),
      relationshipStage: _relationshipStage,
    );
    Navigator.of(context).pop(result);
  }

  String? _emptyToNull(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('顧客を追加')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const AppSectionHeader(title: '基本情報'),
          const SizedBox(height: AppSpacing.sm),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _displayNameController,
                  decoration: const InputDecoration(
                    labelText: '表示名 *',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 80,
                  validator: (value) {
                    if ((value ?? '').trim().isEmpty) {
                      return '表示名は必須です';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _nicknameController,
                  decoration: const InputDecoration(
                    labelText: 'ニックネーム',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 80,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _callNameController,
                  decoration: const InputDecoration(
                    labelText: '呼び名',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 80,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _areaTagController,
                  decoration: const InputDecoration(
                    labelText: 'エリアタグ',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 64,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _jobTagController,
                  decoration: const InputDecoration(
                    labelText: '職業タグ',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 64,
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  value: _relationshipStage,
                  decoration: const InputDecoration(
                    labelText: '関係性',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'new', child: Text('新規')),
                    DropdownMenuItem(value: 'regular', child: Text('常連')),
                    DropdownMenuItem(value: 'important', child: Text('重要')),
                    DropdownMenuItem(value: 'caution', child: Text('慎重')),
                    DropdownMenuItem(value: 'inactive', child: Text('休眠')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _relationshipStage = value ?? 'new';
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                TextFormField(
                  controller: _memoSummaryController,
                  decoration: const InputDecoration(
                    labelText: '要約メモ',
                    border: OutlineInputBorder(),
                    hintText: '120文字以内で要点を入力',
                  ),
                  maxLength: 120,
                  maxLines: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('会話本文や返信本文は保存されません。', style: AppTextStyles.small),
          const SizedBox(height: AppSpacing.md),
          AppButton(text: '登録する', onPressed: _submit),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
