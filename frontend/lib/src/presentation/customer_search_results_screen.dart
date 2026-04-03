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
import 'customer_detail_screen.dart';

class CustomerSearchResultsScreen extends StatefulWidget {
  const CustomerSearchResultsScreen({
    required this.apiClient,
    this.initialQuery = '',
    super.key,
  });

  final AppApiClient apiClient;
  final String initialQuery;

  @override
  State<CustomerSearchResultsScreen> createState() =>
      _CustomerSearchResultsScreenState();
}

class _CustomerSearchResultsScreenState
    extends State<CustomerSearchResultsScreen> {
  static const Duration _searchDebounceDuration = Duration(milliseconds: 350);

  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  List<CustomerSummary> _customers = <CustomerSummary>[];
  bool _loading = true;
  ApiError? _error;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      appBar: AppBar(title: const Text('顧客検索結果')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),
          const AppSectionHeader(title: '検索'),
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
          Text(
            '検索結果: ${_customers.length}件',
            style: AppTextStyles.small.copyWith(color: AppColors.metaText),
          ),
          const SizedBox(height: AppSpacing.sm),
          Expanded(child: _buildListBody()),
        ],
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
          title: '検索結果の取得に失敗したよ',
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
          '条件に一致する顧客がいません',
          style: AppTextStyles.body.copyWith(color: AppColors.bodyText),
        ),
      );
    }

    return ListView.separated(
      itemCount: _customers.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final customer = _customers[index];
        return AppListItem(
          title: customer.displayName,
          subtitle: customer.memoSummary,
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
