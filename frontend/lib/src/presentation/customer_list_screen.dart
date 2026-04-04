import 'dart:async';

import 'package:flutter/material.dart';

import 'package:sample_app/core/theme/app_colors.dart';
import 'package:sample_app/core/theme/app_spacing.dart';
import 'package:sample_app/core/theme/app_text_styles.dart';
import 'package:sample_app/core/widgets/app_error_message_box.dart';
import 'package:sample_app/core/widgets/app_list_item.dart';
import 'package:sample_app/core/widgets/app_scaffold.dart';
import 'package:sample_app/core/widgets/app_section_header.dart';

import '../domain/models.dart';
import '../infrastructure/api_client.dart';
import '../infrastructure/customer_generate_selection_store.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';
import 'customer_search_results_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({required this.apiClient, super.key});

  final AppApiClient apiClient;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 350);

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _relationshipFilter = 'all';

  List<CustomerSummary> _customers = <CustomerSummary>[];
  List<CustomerReminder> _reminders = <CustomerReminder>[];
  bool _loading = true;
  bool _saving = false;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(_searchDebounceDuration, _loadCustomers);
  }

  List<CustomerSummary> _applyRelationshipFilter(List<CustomerSummary> source) {
    if (_relationshipFilter == 'all') {
      return source;
    }
    return source
        .where((customer) => customer.relationshipStage == _relationshipFilter)
        .toList();
  }

  List<CustomerSummary> _visibleCustomers() {
    return _applyRelationshipFilter(_customers);
  }

  Future<void> _loadCustomers() async {
    try {
      setState(() {
        _loading = true;
        _error = null;
      });
      final list = await widget.apiClient.getCustomers(
        query: _searchController.text,
      );
      var reminders = <CustomerReminder>[];
      try {
        reminders = await widget.apiClient.getCustomerReminders(daysAhead: 21);
      } on ApiError {
        reminders = <CustomerReminder>[];
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _customers = list;
        _reminders = reminders;
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

  String _daysDeltaLabel(int value) {
    if (value == 0) {
      return '今日';
    }
    if (value < 0) {
      return '${-value}日超過';
    }
    return 'あと$value日';
  }

  Widget _buildReminderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: '通知リマインド'),
        const SizedBox(height: AppSpacing.xs),
        if (_reminders.isEmpty)
          Text(
            '期限が近い通知はありません',
            style: AppTextStyles.small.copyWith(color: AppColors.metaText),
          )
        else
          ..._reminders.take(4).map((reminder) {
            final subtitle = [
              _daysDeltaLabel(reminder.daysDelta),
              reminder.dueDate,
              _relationshipLabel(reminder.customer.relationshipStage),
            ].join(' / ');
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: AppListItem(
                title: reminder.title,
                subtitle: subtitle,
                trailing: IconButton(
                  tooltip: 'この顧客で返信を作る',
                  icon: const Icon(
                    Icons.send,
                    color: AppColors.buttonBackground,
                  ),
                  onPressed: () => _startGenerateForCustomer(reminder.customer),
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => CustomerDetailScreen(
                        apiClient: widget.apiClient,
                        customerId: reminder.customer.customerId,
                      ),
                    ),
                  );
                },
              ),
            );
          }),
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

  Widget _buildRelationshipFilterChips() {
    final options = <MapEntry<String, String>>[
      const MapEntry<String, String>('all', '全て'),
      const MapEntry<String, String>('new', '新規'),
      const MapEntry<String, String>('regular', '常連'),
      const MapEntry<String, String>('important', '重要'),
      const MapEntry<String, String>('caution', '慎重'),
      const MapEntry<String, String>('inactive', '休眠'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: options.map((option) {
          final selected = _relationshipFilter == option.key;
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: ChoiceChip(
              label: Text(option.value),
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _relationshipFilter = option.key;
                });
              },
              selectedColor: AppColors.buttonBackground.withValues(alpha: 0.18),
            ),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _openCreateCustomerForm() async {
    final input = await Navigator.of(context).push<CreateCustomerInput>(
      MaterialPageRoute(builder: (context) => const CustomerFormScreen()),
    );
    if (input == null) {
      return;
    }

    try {
      setState(() {
        _saving = true;
        _error = null;
      });
      await widget.apiClient.createCustomer(input);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('顧客を登録しました')));
      await _loadCustomers();
    } on ApiError catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = e;
      });
      await showAppErrorDialog(
        context: context,
        title: '顧客登録に失敗したよ',
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

  Future<void> _openSearchResultsScreen() async {
    final query = _searchController.text.trim();
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomerSearchResultsScreen(
          apiClient: widget.apiClient,
          initialQuery: query,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('顧客メモ')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          _buildReminderSection(),
          const SizedBox(height: AppSpacing.md),
          const AppSectionHeader(title: '顧客一覧'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: '名前・タグ・メモで検索',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _openSearchResultsScreen(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: _loading ? null : _openSearchResultsScreen,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildRelationshipFilterChips(),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildListBody()),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _openCreateCustomerForm,
        backgroundColor: AppColors.buttonBackground,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(_saving ? '保存中...' : '顧客を追加'),
      ),
    );
  }

  Widget _buildListBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: AppErrorMessageBox(
          title: '顧客一覧の取得に失敗したよ',
          message: '通信状態を確認して、再読込してね。',
          errorCode: _error!.errorCode,
          detail: _error!.message,
          actionLabel: '再読込',
          onAction: _loadCustomers,
        ),
      );
    }

    if (_customers.isEmpty) {
      return Center(
        child: Text(
          'まだ顧客が登録されていません',
          style: AppTextStyles.body.copyWith(color: AppColors.bodyText),
        ),
      );
    }

    final visible = _visibleCustomers();
    if (visible.isEmpty) {
      return Center(
        child: Text(
          '条件に一致する顧客がいません',
          style: AppTextStyles.body.copyWith(color: AppColors.bodyText),
        ),
      );
    }

    return ListView.separated(
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final customer = visible[index];
        final subtitle = [
          _relationshipLabel(customer.relationshipStage),
          if ((customer.memoSummary ?? '').isNotEmpty) customer.memoSummary!,
        ].join(' / ');

        return AppListItem(
          title: customer.displayName,
          subtitle: subtitle,
          trailing: const Icon(Icons.chevron_right, color: AppColors.metaText),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CustomerDetailScreen(
                  apiClient: widget.apiClient,
                  customerId: customer.customerId,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
