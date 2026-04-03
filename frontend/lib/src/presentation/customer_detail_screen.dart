import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_button.dart';
import 'package:sample_app/core/widgets/app_error_message_box.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/customer_generate_selection_store.dart';
import 'customer_edit_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  const CustomerDetailScreen({
    required this.apiClient,
    required this.customerId,
    super.key,
  });

  final AppApiClient apiClient;
  final String customerId;

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  CustomerDetail? _detail;
  ApiError? _error;
  bool _loading = true;
  bool _saving = false;

  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _visitDateController = TextEditingController();
  final TextEditingController _visitMemoController = TextEditingController();
  final TextEditingController _eventDateController = TextEditingController();
  final TextEditingController _eventTitleController = TextEditingController();
  final TextEditingController _eventNoteController = TextEditingController();

  String _tagCategory = 'topic';
  String _visitType = 'store';
  String _eventType = 'birthday';

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final detail = await widget.apiClient.getCustomerDetail(
        widget.customerId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
      });
    } on ApiError catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _tagsController.dispose();
    _visitDateController.dispose();
    _visitMemoController.dispose();
    _eventDateController.dispose();
    _eventTitleController.dispose();
    _eventNoteController.dispose();
    super.dispose();
  }

  Future<void> _saveTags() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    final raw = _tagsController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タグを1つ以上入力してね')));
      return;
    }
    final values = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (values.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タグを1つ以上入力してね')));
      return;
    }

    try {
      setState(() {
        _saving = true;
      });
      await widget.apiClient.replaceCustomerTags(
        detail.customer.customerId,
        ReplaceCustomerTagsInput(
          tags: values
              .map(
                (value) =>
                    CustomerTagInput(category: _tagCategory, value: value),
              )
              .toList(),
        ),
      );
      _tagsController.clear();
      await _loadDetail();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('タグを更新しました')));
    } on ApiError catch (e) {
      if (!mounted) {
        return;
      }
      await showAppErrorDialog(
        context: context,
        title: 'タグ更新に失敗したよ',
        message: '入力内容を確認して、もう一度ためしてね。',
        errorCode: e.errorCode,
        detail: e.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _openEditCustomer() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }

    final input = await Navigator.of(context).push<UpdateCustomerInput>(
      MaterialPageRoute(
        builder: (context) =>
            CustomerEditScreen(initialCustomer: detail.customer),
      ),
    );
    if (input == null) {
      return;
    }

    try {
      setState(() {
        _saving = true;
      });
      await widget.apiClient.updateCustomer(detail.customer.customerId, input);
      await _loadDetail();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('顧客情報を更新しました')));
    } on ApiError catch (e) {
      if (!mounted) {
        return;
      }
      await showAppErrorDialog(
        context: context,
        title: '顧客更新に失敗したよ',
        message: '入力内容を確認して、もう一度ためしてね。',
        errorCode: e.errorCode,
        detail: e.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _addVisitLog() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    final visitedOn = _visitDateController.text.trim();
    if (visitedOn.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('来店日を入力してね（YYYY-MM-DD）')));
      return;
    }

    try {
      setState(() {
        _saving = true;
      });
      await widget.apiClient.createCustomerVisitLog(
        detail.customer.customerId,
        CreateVisitLogInput(
          visitedOn: visitedOn,
          visitType: _visitType,
          memoShort: _visitMemoController.text.trim().isEmpty
              ? null
              : _visitMemoController.text.trim(),
        ),
      );
      _visitDateController.clear();
      _visitMemoController.clear();
      await _loadDetail();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('来店ログを追加しました')));
    } on ApiError catch (e) {
      if (!mounted) {
        return;
      }
      await showAppErrorDialog(
        context: context,
        title: '来店ログ追加に失敗したよ',
        message: '日付形式と入力内容を確認してね。',
        errorCode: e.errorCode,
        detail: e.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _addEvent() async {
    final detail = _detail;
    if (detail == null) {
      return;
    }
    final eventDate = _eventDateController.text.trim();
    final title = _eventTitleController.text.trim();
    if (eventDate.isEmpty || title.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('イベント日とタイトルを入力してね')));
      return;
    }

    try {
      setState(() {
        _saving = true;
      });
      await widget.apiClient.createCustomerEvent(
        detail.customer.customerId,
        CreateCustomerEventInput(
          eventType: _eventType,
          eventDate: eventDate,
          title: title,
          note: _eventNoteController.text.trim().isEmpty
              ? null
              : _eventNoteController.text.trim(),
        ),
      );
      _eventDateController.clear();
      _eventTitleController.clear();
      _eventNoteController.clear();
      await _loadDetail();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('イベントを追加しました')));
    } on ApiError catch (e) {
      if (!mounted) {
        return;
      }
      await showAppErrorDialog(
        context: context,
        title: 'イベント追加に失敗したよ',
        message: '日付形式と入力内容を確認してね。',
        errorCode: e.errorCode,
        detail: e.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _editEventReminder(CustomerEvent event) async {
    final detail = _detail;
    if (detail == null) {
      return;
    }

    final controller = TextEditingController(
      text: event.remindDaysBefore.toString(),
    );
    final value = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('通知日数を更新'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: '何日前に通知するか（0-365）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed < 0 || parsed > 365) {
                return;
              }
              Navigator.of(dialogContext).pop(parsed);
            },
            child: const Text('更新する'),
          ),
        ],
      ),
    );

    if (value == null) {
      return;
    }

    try {
      setState(() {
        _saving = true;
      });
      await widget.apiClient.updateCustomerEventReminder(
        detail.customer.customerId,
        event.eventId,
        UpdateCustomerEventReminderInput(remindDaysBefore: value),
      );
      await _loadDetail();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('イベント通知日数を更新しました')));
    } on ApiError catch (e) {
      if (!mounted) {
        return;
      }
      await showAppErrorDialog(
        context: context,
        title: '通知日数の更新に失敗したよ',
        message: '入力値を確認して、もう一度ためしてね。',
        errorCode: e.errorCode,
        detail: e.message,
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _startGenerateForCustomer(CustomerSummary customer) {
    CustomerGenerateSelectionStore.instance.setSelection(
      CustomerGenerateSelection(
        customerId: customer.customerId,
        displayName: customer.displayName,
        relationshipStage: customer.relationshipStage,
      ),
    );
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('顧客詳細')),
      scrollable: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_error != null)
            AppErrorMessageBox(
              title: '顧客詳細の取得に失敗したよ',
              message: '通信状態を確認して、再読込してね。',
              errorCode: _error!.errorCode,
              detail: _error!.message,
              actionLabel: '再読込',
              onAction: _loadDetail,
            )
          else if (_detail != null)
            _buildContent(_detail!)
          else
            const Text('データがありません', style: AppTextStyles.body),
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildContent(CustomerDetail detail) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: '基本情報'),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                detail.customer.displayName,
                style: AppTextStyles.primaryTitle,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '関係性: ${_relationshipLabel(detail.customer.relationshipStage)}',
                style: AppTextStyles.body,
              ),
              if ((detail.customer.memoSummary ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(detail.customer.memoSummary!, style: AppTextStyles.body),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppButton(
          text: 'この顧客で返信を作る',
          onPressed: () => _startGenerateForCustomer(detail.customer),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: _saving ? null : _openEditCustomer,
          child: const Text('顧客情報を編集'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(title: 'タグ'),
        const SizedBox(height: AppSpacing.sm),
        if (detail.tags.isEmpty)
          const Text('タグは未登録です', style: AppTextStyles.small)
        else
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: detail.tags
                .map(
                  (tag) => Chip(
                    label: Text('${tag.category}:${tag.value}'),
                    backgroundColor: AppColors.white.withValues(alpha: 0.8),
                  ),
                )
                .toList(),
          ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          value: _tagCategory,
          decoration: const InputDecoration(
            labelText: 'タグカテゴリ',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'topic', child: Text('topic')),
            DropdownMenuItem(value: 'personality', child: Text('personality')),
            DropdownMenuItem(value: 'event', child: Text('event')),
            DropdownMenuItem(
              value: 'relationship',
              child: Text('relationship'),
            ),
            DropdownMenuItem(value: 'ng', child: Text('ng')),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  setState(() {
                    _tagCategory = value ?? 'topic';
                  });
                },
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _tagsController,
          decoration: const InputDecoration(
            hintText: 'タグをカンマ区切りで入力（例: 誕生日,転職）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FilledButton(
          onPressed: _saving ? null : _saveTags,
          child: Text(_saving ? '更新中...' : 'タグを更新'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(title: '直近来店ログ'),
        const SizedBox(height: AppSpacing.sm),
        if (detail.visitLogs.isEmpty)
          const Text('来店ログは未登録です', style: AppTextStyles.small)
        else
          ...detail.visitLogs
              .take(3)
              .map(
                (log) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text(
                    '${log.visitedOn} / ${log.visitType}${(log.memoShort ?? '').isNotEmpty ? ' / ${log.memoShort}' : ''}',
                    style: AppTextStyles.body,
                  ),
                ),
              ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _visitDateController,
          decoration: const InputDecoration(
            labelText: '来店日（YYYY-MM-DD）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<String>(
          value: _visitType,
          decoration: const InputDecoration(
            labelText: '来店種別',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'store', child: Text('store')),
            DropdownMenuItem(value: 'douhan', child: Text('douhan')),
            DropdownMenuItem(value: 'after', child: Text('after')),
            DropdownMenuItem(value: 'other', child: Text('other')),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  setState(() {
                    _visitType = value ?? 'store';
                  });
                },
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _visitMemoController,
          decoration: const InputDecoration(
            labelText: 'メモ（任意）',
            border: OutlineInputBorder(),
          ),
          maxLength: 80,
        ),
        const SizedBox(height: AppSpacing.xs),
        FilledButton(
          onPressed: _saving ? null : _addVisitLog,
          child: Text(_saving ? '追加中...' : '来店ログを追加'),
        ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(title: 'イベント'),
        const SizedBox(height: AppSpacing.sm),
        if (detail.events.isEmpty)
          const Text('イベントは未登録です', style: AppTextStyles.small)
        else
          ...detail.events
              .take(3)
              .map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${event.eventDate} / ${event.title}',
                          style: AppTextStyles.body,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          '通知: ${event.remindDaysBefore}日前',
                          style: AppTextStyles.small,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        OutlinedButton(
                          onPressed: _saving
                              ? null
                              : () => _editEventReminder(event),
                          child: const Text('通知日数を更新'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        const SizedBox(height: AppSpacing.sm),
        DropdownButtonFormField<String>(
          value: _eventType,
          decoration: const InputDecoration(
            labelText: 'イベント種別',
            border: OutlineInputBorder(),
          ),
          items: const [
            DropdownMenuItem(value: 'birthday', child: Text('birthday')),
            DropdownMenuItem(
              value: 'first_visit_anniversary',
              child: Text('first_visit_anniversary'),
            ),
            DropdownMenuItem(value: 'special_day', child: Text('special_day')),
            DropdownMenuItem(value: 'custom', child: Text('custom')),
          ],
          onChanged: _saving
              ? null
              : (value) {
                  setState(() {
                    _eventType = value ?? 'birthday';
                  });
                },
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _eventDateController,
          decoration: const InputDecoration(
            labelText: 'イベント日（YYYY-MM-DD）',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _eventTitleController,
          decoration: const InputDecoration(
            labelText: 'タイトル',
            border: OutlineInputBorder(),
          ),
          maxLength: 80,
        ),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _eventNoteController,
          decoration: const InputDecoration(
            labelText: 'メモ（任意）',
            border: OutlineInputBorder(),
          ),
          maxLength: 80,
        ),
        const SizedBox(height: AppSpacing.xs),
        FilledButton(
          onPressed: _saving ? null : _addEvent,
          child: Text(_saving ? '追加中...' : 'イベントを追加'),
        ),
      ],
    );
  }

  String _relationshipLabel(String value) {
    switch (value) {
      case 'regular':
        return '常連';
      case 'important':
        return '重要';
      case 'caution':
        return '慎重';
      case 'inactive':
        return '休眠';
      default:
        return '新規';
    }
  }
}
