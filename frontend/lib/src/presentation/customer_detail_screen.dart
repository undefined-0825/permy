import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_radius.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_error_message_box.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import '../domain/models.dart';
import '../infrastructure/api_client.dart';

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
      final detail = await widget.apiClient.getCustomerDetail(widget.customerId);
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
              Text(detail.customer.displayName, style: AppTextStyles.primaryTitle),
              const SizedBox(height: AppSpacing.xs),
              Text('関係性: ${_relationshipLabel(detail.customer.relationshipStage)}', style: AppTextStyles.body),
              if ((detail.customer.memoSummary ?? '').isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(detail.customer.memoSummary!, style: AppTextStyles.body),
              ],
            ],
          ),
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
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(title: '直近来店ログ'),
        const SizedBox(height: AppSpacing.sm),
        if (detail.visitLogs.isEmpty)
          const Text('来店ログは未登録です', style: AppTextStyles.small)
        else
          ...detail.visitLogs.take(3).map(
            (log) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${log.visitedOn} / ${log.visitType}${(log.memoShort ?? '').isNotEmpty ? ' / ${log.memoShort}' : ''}',
                style: AppTextStyles.body,
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(title: 'イベント'),
        const SizedBox(height: AppSpacing.sm),
        if (detail.events.isEmpty)
          const Text('イベントは未登録です', style: AppTextStyles.small)
        else
          ...detail.events.take(3).map(
            (event) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '${event.eventDate} / ${event.title}',
                style: AppTextStyles.body,
              ),
            ),
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
