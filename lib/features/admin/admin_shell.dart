import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/config/env.dart';
import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/rules/permissions.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/auth/presentation/auth_screens.dart';

class _NavItem {
  const _NavItem(this.label, this.icon, this.path, [this.permission]);
  final String label;
  final IconData icon;
  final String path;
  final Permission? permission;
}

const _items = [
  _NavItem('Overview', Icons.dashboard_outlined, '/admin/overview', Permission.viewDashboard),
  _NavItem('Orders', Icons.receipt_long_outlined, '/admin/orders', Permission.manageOrders),
  _NavItem('Packages', Icons.inventory_2_outlined, '/admin/packages', Permission.managePackages),
  _NavItem('Services', Icons.camera_alt_outlined, '/admin/services', Permission.manageServices),
  _NavItem('Customers', Icons.people_outline, '/admin/customers', Permission.viewCustomers),
  _NavItem('Coupons', Icons.local_offer_outlined, '/admin/coupons', Permission.manageCoupons),
  _NavItem('Support', Icons.support_agent_outlined, '/admin/support', Permission.manageSupport),
  _NavItem('Revenue', Icons.bar_chart_rounded, '/admin/revenue', Permission.viewRevenue),
  _NavItem('Profile', Icons.manage_accounts_outlined, '/admin/profile'),
];

/// Sidebar on desktop (>=1024px), drawer on tablet/phone. Items are filtered by role permissions.
class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.location, required this.child});
  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final visible = _items.where((i) => i.permission == null || (session?.can(i.permission!) ?? false)).toList();
    final current = visible.firstWhere((i) => location.startsWith(i.path), orElse: () => visible.first);

    Widget sidebar({bool inDrawer = false}) => _Sidebar(items: visible, current: current, inDrawer: inDrawer);

    if (context.isWide) {
      return Scaffold(body: Row(children: [SizedBox(width: 250, child: sidebar()), VerticalDivider(width: 1, color: context.border), Expanded(child: child)]));
    }
    return Scaffold(
      appBar: AppBar(title: Text(current.label)),
      drawer: Drawer(child: SafeArea(child: sidebar(inDrawer: true))),
      body: child,
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({required this.items, required this.current, required this.inDrawer});
  final List<_NavItem> items;
  final _NavItem current;
  final bool inDrawer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    return Container(
      color: context.surface,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(children: [
            const BrandMark(size: 38),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(Env.appName, style: context.titleLg), Text('Admin', style: context.small)])),
          ]),
        ),
        Expanded(
          child: ListView(padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final i in items)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: ListTile(
                  dense: true,
                  selected: i == current,
                  selectedTileColor: AppColors.primary.withValues(alpha: 0.1),
                  selectedColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(i.icon),
                  title: Text(i.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    if (inDrawer) Navigator.pop(context);
                    context.go(i.path);
                  },
                ),
              ),
          ]),
        ),
        const Divider(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            CircleAvatar(backgroundColor: AppColors.primarySoft, child: Text((session?.name ?? '?')[0], style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w700))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(session?.name ?? '', style: context.titleSm, overflow: TextOverflow.ellipsis), Text(session?.role?.label ?? '', style: context.small)])),
            IconButton(
              tooltip: 'Log out',
              icon: const Icon(Icons.logout),
              onPressed: () async {
                final ok = await confirmDialog(context, title: 'Log out?', message: 'You will be returned to the admin sign-in.', confirmLabel: 'Log out');
                if (ok) await ref.read(sessionProvider.notifier).logout();
              },
            ),
          ]),
        ),
      ]),
    );
  }
}
