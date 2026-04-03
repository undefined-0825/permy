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
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({required this.apiClient, super.key});

  final AppApiClient apiClient;

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<CustomerSummary> _customers = <CustomerSummary>[];
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
    _searchController.dispose();
    super.dispose();
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
      if (!mounted) {
        return;
      }
      setState(() {
        _customers = list;
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('顧客メモ')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  onSubmitted: (_) => _loadCustomers(),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton(
                onPressed: _loading ? null : _loadCustomers,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
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

    return ListView.separated(
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final customer = _customers[index];
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
