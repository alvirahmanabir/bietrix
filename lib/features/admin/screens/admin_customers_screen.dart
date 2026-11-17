import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/rules/permissions.dart';
import 'package:jamcon/features/admin/widgets/admin_widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

class AdminCustomersScreen extends ConsumerStatefulWidget {
  const AdminCustomersScreen({super.key});
  @override
  ConsumerState<AdminCustomersScreen> createState() => _AdminCustomersScreenState();
}

class _AdminCustomersScreenState extends ConsumerState<AdminCustomersScreen> {
  Timer? _debounce;
  String _query = '';
  AccountStatus? _status;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(customersProvider((query: _query, status: _status)));
    return AdminPage(
      title: 'Customers',
      subtitle: 'Registered customers. Profile details are read-only for admins.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 320,
            child: TextField(
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  if (mounted) setState(() => _query = v);
                });
              },
              decoration: const InputDecoration(hintText: 'Search name, email or phone', prefixIcon: Icon(Icons.search)),
            ),
          ),
          for (final s in [null, ...AccountStatus.values])
            ChoiceChip(label: Text(s?.label ?? 'All'), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
        ]),
        const SizedBox(height: 16),
        AsyncValueView<List<AppUser>>(
          value: async,
          loading: const SizedBox(height: 300, child: ListSkeleton(count: 4, itemHeight: 56)),
          data: (list) {
            if (list.isEmpty) return const EmptyState(icon: Icons.people_outline, title: 'No customers found');
            return AdminTable(
              columns: const ['Customer', 'Email', 'Phone', 'Joined', 'Status', ''],
              rows: [
                for (final u in list)
                  DataRow(onSelectChanged: (_) => context.go('/admin/customers/${u.id}'), cells: [
                    DataCell(Text(u.name, style: context.titleSm)),
                    DataCell(Text(u.email)),
                    DataCell(Text(u.phone)),
                    DataCell(Text(Fmt.date(u.createdAt))),
                    DataCell(Pill(u.status.label, color: u.status == AccountStatus.active ? AppColors.success : AppColors.danger)),
                    DataCell(TextButton(onPressed: () => context.go('/admin/customers/${u.id}'), child: const Text('View'))),
                  ]),
              ],
            );
          },
        ),
      ]),
    );
  }
}

class AdminCustomerDetailScreen extends ConsumerWidget {
  const AdminCustomerDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(customersProvider((query: '', status: null)));
    final bookings = ref.watch(customerBookingsProvider(id));
    final canOrders = ref.watch(sessionProvider)?.can(Permission.manageOrders) ?? false;
    return AdminPage(
      title: 'Customer profile',
      actions: [TextButton.icon(onPressed: () => context.go('/admin/customers'), icon: const Icon(Icons.arrow_back), label: const Text('All customers'))],
      child: AsyncValueView<List<AppUser>>(
        value: user,
        data: (all) {
          final u = all.where((x) => x.id == id).firstOrNull;
          if (u == null) return const EmptyState(icon: Icons.person_off_outlined, title: 'Customer not found', message: 'The account may have been deleted.');
          final list = bookings.value ?? const <Booking>[];
          final spent = list.where((b) => b.status == BookingStatus.completed).fold<int>(0, (s, b) => s + b.pricing.total);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  CircleAvatar(radius: 28, backgroundColor: AppColors.primarySoft, child: Text(u.name[0], style: context.hMd.copyWith(color: AppColors.primaryDark))),
                  const SizedBox(width: 14),
                  Expanded(child: Text(u.name, style: context.hMd)),
                  Pill(u.status.label, color: u.status == AccountStatus.active ? AppColors.success : AppColors.danger),
                ]),
                const Divider(height: 28),
                InfoRow('Customer ID', u.id),
                InfoRow('Email', u.email),
                InfoRow('Phone', u.phone),
                InfoRow('Address', u.address.isEmpty ? '-' : u.address),
                InfoRow('Registered', Fmt.dateTime(u.createdAt)),
                InfoRow('Completed spend', Fmt.money(spent)),
                const SizedBox(height: 6),
                Text('Customer profile data is read-only here. Customers manage their own details.', style: context.small),
              ]),
            ),
            const SizedBox(height: 16),
            Text('Booking history (${list.length})', style: context.titleLg),
            const SizedBox(height: 10),
            if (list.isEmpty)
              const EmptyState(icon: Icons.receipt_long_outlined, title: 'No bookings yet')
            else
              AdminTable(
                columns: const ['Booking ID', 'Package', 'Event date', 'Total', 'Status'],
                rows: [
                  for (final b in list)
                    DataRow(onSelectChanged: canOrders ? (_) => context.go('/admin/orders/${b.id}') : null, cells: [
                      DataCell(Text(b.code, style: context.titleSm.copyWith(color: AppColors.primary))),
                      DataCell(Text(b.packageName)),
                      DataCell(Text(Fmt.date(b.schedule.date))),
                      DataCell(Text(Fmt.money(b.pricing.total))),
                      DataCell(StatusBadge(b.status)),
                    ]),
                ],
              ),
          ]);
        },
      ),
    );
  }
}
