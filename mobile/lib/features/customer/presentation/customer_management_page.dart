import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/page_header.dart';
import '../data/customers_repository.dart';
import 'customer_details_page.dart';
import 'customer_form_page.dart';

/// Quản lý khách hàng (Figma "25 Customer Management" + "26 Empty search").
class CustomerManagementPage extends ConsumerStatefulWidget {
  const CustomerManagementPage({super.key});

  @override
  ConsumerState<CustomerManagementPage> createState() => _CustomerManagementPageState();
}

class _CustomerManagementPageState extends ConsumerState<CustomerManagementPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final customers = ref.watch(customersProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.terracotta,
        foregroundColor: Colors.white,
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CustomerFormPage()));
          ref.invalidate(customersProvider);
        },
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Add'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            customers.maybeWhen(
              data: (list) => PageHeader(title: 'Customers', subtitle: '${list.length} members'),
              orElse: () => const PageHeader(title: 'Customers'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                decoration: const InputDecoration(
                  hintText: 'Search by name or phone…',
                  prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                ),
              ),
            ),
            Expanded(
              child: customers.when(
                loading: () => const Center(child: CircularProgressIndicator(color: AppColors.terracotta)),
                error: (e, _) => Center(child: Text(apiErrorMessage(e), style: const TextStyle(color: AppColors.danger))),
                data: (list) {
                  final filtered = _query.isEmpty
                      ? list
                      : list.where((c) => c.fullName.toLowerCase().contains(_query) || (c.phone ?? '').contains(_query)).toList();
                  if (filtered.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('No customers match your search.', style: TextStyle(color: AppColors.textMuted)),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => ref.invalidate(customersProvider),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            leading: CircleAvatar(
                              backgroundColor: AppColors.terracotta.withValues(alpha: 0.16),
                              child: Text(c.initials,
                                  style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700)),
                            ),
                            title: Text(c.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(c.phone ?? '—', style: const TextStyle(fontSize: 13)),
                            trailing: Text('${c.loyaltyPoints} pts',
                                style: const TextStyle(color: AppColors.terracottaDark, fontWeight: FontWeight.w700)),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => CustomerDetailsPage(customerId: c.id)),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
