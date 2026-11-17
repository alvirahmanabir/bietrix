import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/features/common/queries.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});
  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen> {
  BookingStatus? _filter;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myBookingsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: AsyncValueView<List<Booking>>(
        value: async,
        data: (all) {
          final list = _filter == null ? all : all.where((b) => b.status == _filter).toList();
          return Column(children: [
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text('All (${all.length})'), selected: _filter == null, onSelected: (_) => setState(() => _filter = null))),
                  for (final s in BookingStatus.values)
                    Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(s.label), selected: _filter == s, onSelected: (_) => setState(() => _filter = s))),
                ],
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: all.isEmpty ? 'No bookings yet' : 'No orders with this status',
                      message: all.isEmpty ? 'Your bookings will appear here.' : null,
                      actionLabel: all.isEmpty ? 'Browse packages' : null,
                      onAction: () => context.go('/packages'),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _OrderCard(b: list[i]),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.b});
  final Booking b;
  @override
  Widget build(BuildContext context) => AppCard(
        onTap: () => context.push('/orders/${b.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(b.code, style: context.titleSm.copyWith(color: AppColors.primary))),
            StatusBadge(b.status),
          ]),
          const SizedBox(height: 8),
          Text(b.packageName, style: context.title),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.event, size: 15, color: context.muted),
            const SizedBox(width: 6),
            Text('Event ${Fmt.date(b.schedule.date)}', style: context.small),
            const SizedBox(width: 14),
            Icon(Icons.history, size: 15, color: context.muted),
            const SizedBox(width: 6),
            Expanded(child: Text('Booked ${Fmt.date(b.createdAt)}', style: context.small, overflow: TextOverflow.ellipsis)),
          ]),
          const Divider(height: 20),
          Row(children: [
            Expanded(child: Text(b.payment.method.label, style: context.small)),
            Text(Fmt.money(b.pricing.total), style: context.title),
          ]),
        ]),
      );
}
