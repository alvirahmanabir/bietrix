import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/revenue.dart';
import 'package:jamcon/domain/rules/permissions.dart';
import 'package:jamcon/features/admin/widgets/admin_widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final async = ref.watch(dashboardProvider);
    return AdminPage(
      title: 'Overview',
      subtitle: 'Welcome back, ${session?.name.split(' ').first ?? ''} · ${session?.role?.label ?? ''}',
      child: AsyncValueView<DashboardStats>(
        value: async,
        loading: const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        data: (d) {
          final r = d.revenue;
          final cancelled = r.count(BookingStatus.cancelledByCustomer) + r.count(BookingStatus.cancelledByAdmin);
          final canRevenue = session?.can(Permission.viewRevenue) ?? false;
          final canOrders = session?.can(Permission.manageOrders) ?? false;
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TileGrid(children: [
              if (canRevenue) StatTile(label: 'Total revenue', value: Fmt.money(r.realized), icon: Icons.payments_outlined, color: AppColors.success, sub: '${Fmt.money(r.bookedValue)} upcoming'),
              StatTile(label: 'Total orders', value: '${r.totalOrders}', icon: Icons.receipt_long_outlined, color: AppColors.primary),
              StatTile(label: 'Pending orders', value: '${r.count(BookingStatus.pendingConfirmation)}', icon: Icons.hourglass_bottom, color: AppColors.warning),
              StatTile(label: 'Confirmed orders', value: '${r.count(BookingStatus.confirmed)}', icon: Icons.verified_outlined, color: AppColors.info),
              StatTile(label: 'Completed orders', value: '${r.count(BookingStatus.completed)}', icon: Icons.task_alt, color: AppColors.success),
              StatTile(label: 'Cancelled orders', value: '$cancelled', icon: Icons.cancel_outlined, color: AppColors.danger),
              StatTile(label: 'Total customers', value: '${d.totalCustomers}', icon: Icons.people_outline, color: AppColors.secondary),
            ]),
            const SizedBox(height: 16),
            TwoCol(
              left: canRevenue
                  ? Panel(
                      title: 'Revenue · last 14 days',
                      trailing: TextButton(onPressed: () => context.go('/admin/revenue'), child: const Text('Details')),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [BarChartLite(points: r.byDay, label: Fmt.dayShort), const SizedBox(height: 12), const ChartLegend()]),
                    )
                  : _StatusPanel(r: r),
              right: Panel(title: 'Popular packages', child: HBarList(data: r.ordersByPackage, money: false, max: 5, color: AppColors.secondary)),
            ),
            if (canRevenue) ...[const SizedBox(height: 16), _StatusPanel(r: r)],
            const SizedBox(height: 16),
            TwoCol(
              left: Panel(
                title: 'Recent orders',
                trailing: canOrders ? TextButton(onPressed: () => context.go('/admin/orders'), child: const Text('View all')) : null,
                child: Column(children: [
                  for (final b in d.recentOrders)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      onTap: canOrders ? () => context.go('/admin/orders/${b.id}') : null,
                      title: Text('${b.code} · ${b.packageName}', style: context.titleSm, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${b.contact.name} · ${Fmt.date(b.schedule.date)} · ${Fmt.money(b.pricing.total)}'),
                      trailing: StatusBadge(b.status),
                    ),
                ]),
              ),
              right: Column(children: [
                Panel(title: 'Quick actions', child: Wrap(spacing: 10, runSpacing: 10, children: [
                  Can(Permission.manageOrders, child: AppButton(label: 'Review orders', icon: Icons.receipt_long_outlined, expand: false, onPressed: () => context.go('/admin/orders'))),
                  Can(Permission.managePackages, child: AppButton(label: 'Packages', icon: Icons.inventory_2_outlined, expand: false, variant: AppButtonVariant.secondary, onPressed: () => context.go('/admin/packages'))),
                  Can(Permission.manageCoupons, child: AppButton(label: 'Coupons', icon: Icons.local_offer_outlined, expand: false, variant: AppButtonVariant.secondary, onPressed: () => context.go('/admin/coupons'))),
                  Can(Permission.manageSupport, child: AppButton(label: 'Support inbox', icon: Icons.support_agent_outlined, expand: false, variant: AppButtonVariant.secondary, onPressed: () => context.go('/admin/support'))),
                ])),
                const SizedBox(height: 16),
                Panel(
                  title: 'New customers',
                  child: Column(children: [
                    for (final u in d.recentCustomers)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(backgroundColor: AppColors.primarySoft, child: Text(u.name[0], style: const TextStyle(color: AppColors.primaryDark))),
                        title: Text(u.name, style: context.titleSm),
                        subtitle: Text('Joined ${Fmt.date(u.createdAt)}'),
                      ),
                  ]),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.r});
  final RevenueSummary r;
  @override
  Widget build(BuildContext context) {
    final total = r.totalOrders == 0 ? 1 : r.totalOrders;
    return Panel(
      title: 'Booking statistics',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 14,
            child: Row(children: [
              for (final s in BookingStatus.values)
                if (r.count(s) > 0) Expanded(flex: r.count(s), child: Container(color: statusColor(s))),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(spacing: 18, runSpacing: 8, children: [
          for (final s in BookingStatus.values)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: statusColor(s), borderRadius: BorderRadius.circular(3))),
              const SizedBox(width: 6),
              Text('${s.label}: ${r.count(s)} (${(r.count(s) * 100 / total).round()}%)', style: context.small),
            ]),
        ]),
      ]),
    );
  }
}
