import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/utils/paginated.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/revenue.dart';
import 'package:jamcon/domain/services/services.dart';
import 'package:jamcon/features/admin/widgets/admin_widgets.dart';
import 'package:jamcon/features/common/queries.dart';

class AdminRevenueScreen extends ConsumerWidget {
  const AdminRevenueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(revenueProvider);
    final completed = ref.watch(adminBookingsProvider(const BookingFilter(status: BookingStatus.completed, pageSize: 8)));
    return AdminPage(
      title: 'Revenue',
      subtitle: 'Realized revenue counts completed orders. Confirmed orders are shown as upcoming; pending and cancelled orders are excluded.',
      child: AsyncValueView<RevenueSummary>(
        value: async,
        loading: const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        data: (r) {
          final done = r.count(BookingStatus.completed);
          final avg = done == 0 ? 0 : r.realized ~/ done;
          final payTotal = r.byPayment.values.fold<int>(0, (a, b) => a + b);
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TileGrid(children: [
              StatTile(label: 'Total revenue (completed)', value: Fmt.money(r.realized), icon: Icons.payments_outlined, color: AppColors.success),
              StatTile(label: 'Upcoming (confirmed)', value: Fmt.money(r.bookedValue), icon: Icons.event_available_outlined, color: AppColors.info),
              StatTile(label: 'Awaiting confirmation', value: Fmt.money(r.pendingValue), icon: Icons.hourglass_bottom, color: AppColors.warning),
              StatTile(label: 'Average order value', value: Fmt.money(avg), icon: Icons.calculate_outlined, color: AppColors.primary, sub: '$done completed orders'),
            ]),
            const SizedBox(height: 16),
            Panel(
              title: 'Revenue by date · last 14 days',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BarChartLite(points: r.byDay, label: Fmt.dayShort), const SizedBox(height: 12), const ChartLegend()]),
            ),
            const SizedBox(height: 16),
            Panel(
              title: 'Monthly revenue · last 6 months',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BarChartLite(points: r.byMonth, label: Fmt.monthShort, height: 230), const SizedBox(height: 12), const ChartLegend()]),
            ),
            const SizedBox(height: 16),
            TwoCol(
              left: Panel(title: 'Revenue by package', child: HBarList(data: r.byPackage, max: 8)),
              right: Panel(
                title: 'Payment method breakdown',
                child: Column(children: [
                  for (final m in PaymentMethod.values)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(children: [
                        Row(children: [
                          Icon(m == PaymentMethod.online ? Icons.credit_card : Icons.payments_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(m.label, style: context.titleSm)),
                          Text('${Fmt.money(r.byPayment[m] ?? 0)}  (${payTotal == 0 ? 0 : ((r.byPayment[m] ?? 0) * 100 / payTotal).round()}%)'),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: payTotal == 0 ? 0 : (r.byPayment[m] ?? 0) / payTotal, minHeight: 8, color: m == PaymentMethod.online ? AppColors.secondary : AppColors.primary, backgroundColor: context.border)),
                      ]),
                    ),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            Text('Order-based revenue · latest completed orders', style: context.titleLg),
            const SizedBox(height: 10),
            AsyncValueView<Paginated<Booking>>(
              value: completed,
              loading: const SizedBox(height: 120, child: ListSkeleton(count: 2, itemHeight: 40)),
              data: (p) => p.items.isEmpty
                  ? const EmptyState(icon: Icons.receipt_long_outlined, title: 'No completed orders yet')
                  : AdminTable(
                      columns: const ['Booking ID', 'Package', 'Event date', 'Payment', 'Revenue'],
                      rows: [
                        for (final b in p.items)
                          DataRow(cells: [
                            DataCell(Text(b.code, style: context.titleSm.copyWith(color: AppColors.primary))),
                            DataCell(Text(b.packageName)),
                            DataCell(Text(Fmt.date(b.schedule.date))),
                            DataCell(Text(b.payment.method.label)),
                            DataCell(Text(Fmt.money(b.pricing.total), style: context.titleSm)),
                          ]),
                      ],
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
