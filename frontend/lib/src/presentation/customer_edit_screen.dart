import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import '../domain/models.dart';

class CustomerEditScreen extends StatefulWidget {
  const CustomerEditScreen({required this.initialCustomer, super.key});

  final CustomerSummary initialCustomer;

  @override
  State<CustomerEditScreen> createState() => _CustomerEditScreenState();
}

class _CustomerEditScreenState extends State<CustomerEditScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayNameController;
  late final TextEditingController _nicknameController;
  late final TextEditingController _callNameController;
  late final TextEditingController _areaTagController;
  late final TextEditingController _jobTagController;
  late final TextEditingController _memoSummaryController;

  late String _relationshipStage;

  @override
  void initState() {
    super.initState();
    final customer = widget.initialCustomer;
    _displayNameController = TextEditingController(text: customer.displayName);
    _nicknameController = TextEditingController(text: customer.nickname ?? '');
    _callNameController = TextEditingController(text: customer.callName ?? '');
    _areaTagController = TextEditingController(text: customer.areaTag ?? '');
    _jobTagController = TextEditingController(text: customer.jobTag ?? '');
    _memoSummaryController = TextEditingController(
      text: customer.memoSummary ?? '',
    );
    _relationshipStage = customer.relationshipStage;
  }

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

    final result = UpdateCustomerInput(
      displayName: _displayNameController.text.trim(),
      nickname: _emptyToNull(_nicknameController.text),
      callName: _emptyToNull(_callNameController.text),
      areaTag: _emptyToNull(_areaTagController.text),
      jobTag: _emptyToNull(_jobTagController.text),
      memoSummary: _emptyToNull(_memoSummaryController.text),
      relationshipStage: _relationshipStage,
      isArchived: widget.initialCustomer.isArchived,
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
      appBar: AppBar(title: const Text('顧客を編集')),
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
                  initialValue: _relationshipStage,
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
          AppButton(text: '保存する', onPressed: _submit),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }
}
