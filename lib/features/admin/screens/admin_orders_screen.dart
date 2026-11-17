import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/utils/paginated.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/rules/booking_policy.dart';
import 'package:jamcon/domain/services/services.dart';
import 'package:jamcon/features/admin/widgets/admin_widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/booking_details.dart';
import 'package:jamcon/features/common/queries.dart';

class AdminOrdersScreen extends ConsumerStatefulWidget {
  const AdminOrdersScreen({super.key});
  @override
  ConsumerState<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends ConsumerState<AdminOrdersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  BookingStatus? _status;
  DateTime? _date;
  int _page = 1;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() {
        _query = v;
        _page = 1;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final filter = BookingFilter(query: _query, status: _status, eventDate: _date, page: _page, pageSize: 15);
    final async = ref.watch(adminBookingsProvider(filter));
    return AdminPage(
      title: 'Orders',
      subtitle: 'Review, confirm, cancel and complete customer bookings.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 320,
            child: TextField(
              controller: _search,
              onChanged: _onSearch,
              decoration: const InputDecoration(hintText: 'Search booking ID, customer, package', prefixIcon: Icon(Icons.search)),
            ),
          ),
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<BookingStatus?>(
              initialValue: _status,
              isExpanded: true,
              hint: const Text('All statuses'),
              items: [const DropdownMenuItem<BookingStatus?>(value: null, child: Text('All statuses')), for (final s in BookingStatus.values) DropdownMenuItem<BookingStatus?>(value: s, child: Text(s.label))],
              onChanged: (v) => setState(() {
                _status = v;
                _page = 1;
              }),
            ),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: const Size(0, 50)),
            icon: const Icon(Icons.event),
            label: Text(_date == null ? 'Event date' : Fmt.date(_date!)),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(2024), lastDate: DateTime(2030));
              if (d != null) setState(() {
                _date = DateTime(d.year, d.month, d.day);
                _page = 1;
              });
            },
          ),
          if (_date != null) TextButton(onPressed: () => setState(() => _date = null), child: const Text('Clear date')),
        ]),
        const SizedBox(height: 16),
        AsyncValueView<Paginated<Booking>>(
          value: async,
          loading: const SizedBox(height: 300, child: ListSkeleton(count: 4, itemHeight: 56)),
          data: (page) {
            if (page.items.isEmpty) return const EmptyState(icon: Icons.receipt_long_outlined, title: 'No orders match your filters');
            return Column(children: [
              AdminTable(
                columns: const ['Booking ID', 'Customer', 'Package', 'Event date', 'Total', 'Payment', 'Status', ''],
                rows: [
                  for (final b in page.items)
                    DataRow(onSelectChanged: (_) => context.go('/admin/orders/${b.id}'), cells: [
                      DataCell(Text(b.code, style: context.titleSm.copyWith(color: AppColors.primary))),
                      DataCell(Text(b.contact.name)),
                      DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 180), child: Text(b.packageName, overflow: TextOverflow.ellipsis))),
                      DataCell(Text(Fmt.date(b.schedule.date))),
                      DataCell(Text(Fmt.money(b.pricing.total), style: context.titleSm)),
                      DataCell(Text(b.payment.method.label)),
                      DataCell(StatusBadge(b.status)),
                      DataCell(TextButton(onPressed: () => context.go('/admin/orders/${b.id}'), child: const Text('View'))),
                    ]),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Text('Showing ${page.items.length} of ${page.total}', style: context.small),
                const Spacer(),
                if (page.hasMore) AppButton(label: 'Load more', expand: false, variant: AppButtonVariant.secondary, onPressed: () => setState(() => _page++)),
              ]),
            ]);
          },
        ),
      ]),
    );
  }
}

class AdminOrderDetailScreen extends ConsumerStatefulWidget {
  const AdminOrderDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends ConsumerState<AdminOrderDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<Booking> Function() job, String done) async {
    setState(() => _busy = true);
    try {
      await job();
      if (mounted) ErrorHandler.success(context, done);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookingByIdProvider(widget.id));
    final session = ref.watch(sessionProvider)!;
    final svc = ref.read(bookingServiceProvider);
    return AdminPage(
      title: 'Order details',
      actions: [TextButton.icon(onPressed: () => context.go('/admin/orders'), icon: const Icon(Icons.arrow_back), label: const Text('All orders'))],
      child: AsyncValueView<Booking?>(
        value: async,
        data: (b) {
          if (b == null) return const EmptyState(icon: Icons.search_off, title: 'Order not found');
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(b.code, style: context.hMd.copyWith(color: AppColors.primary))),
                  StatusBadge(b.status),
                ]),
                const SizedBox(height: 4),
                Text('${b.packageName} · ${Fmt.money(b.pricing.total)} · placed ${Fmt.dateTime(b.createdAt)}', style: context.small),
                const SizedBox(height: 16),
                Wrap(spacing: 10, runSpacing: 10, children: [
                  if (BookingPolicy.canAdminConfirm(b))
                    AppButton(label: 'Confirm order', icon: Icons.verified_outlined, expand: false, loading: _busy, onPressed: () async {
                      final ok = await confirmDialog(context, title: 'Confirm this order?', message: 'The customer will no longer be able to cancel it.', confirmLabel: 'Confirm');
                      if (ok) await _run(() => svc.confirm(b.id, session), 'Order confirmed');
                    }),
                  if (BookingPolicy.canAdminComplete(b))
                    AppButton(label: 'Mark as completed', icon: Icons.task_alt, expand: false, loading: _busy, onPressed: () async {
                      final ok = await confirmDialog(context, title: 'Mark as completed?', message: 'This records the event as done and counts it as realized revenue.', confirmLabel: 'Complete');
                      if (ok) await _run(() => svc.complete(b.id, session), 'Order completed');
                    }),
                  if (BookingPolicy.canAdminCancel(b))
                    AppButton(label: 'Cancel order', icon: Icons.cancel_outlined, expand: false, variant: AppButtonVariant.danger, loading: _busy, onPressed: () async {
                      final r = await reasonDialog(context, title: 'Cancel this order?', message: b.status == BookingStatus.confirmed ? 'This order is confirmed. Only admins can cancel it. The customer will be notified.' : 'The customer will be notified of the cancellation.', confirmLabel: 'Cancel order', hint: 'Cancellation reason (shown to the customer)', cancelLabel: 'Keep order');
                      if (r.ok) await _run(() => svc.cancelByAdmin(b.id, session, reason: r.reason), 'Order cancelled');
                    }),
                  TextButton.icon(onPressed: () => context.go('/admin/customers/${b.customerId}'), icon: const Icon(Icons.person_outline), label: const Text('View customer')),
                ]),
                if (!BookingPolicy.canAdminConfirm(b) && !BookingPolicy.canAdminCancel(b) && !BookingPolicy.canAdminComplete(b))
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text('No further actions: this order is ${b.status.label.toLowerCase()}.', style: context.small)),
              ]),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: BookingDetailSections(booking: b)),
          ]);
        },
      ),
    );
  }
}
