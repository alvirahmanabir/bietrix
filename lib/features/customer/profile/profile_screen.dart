import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;

    Widget item(IconData icon, String title, VoidCallback onTap, {Color? color, String? subtitle}) => ListTile(
          leading: Icon(icon, color: color),
          title: Text(title, style: context.title.copyWith(color: color)),
          subtitle: subtitle == null ? null : Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const ListSkeleton(count: 3)
          : ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), children: [
              AppCard(
                child: Row(children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.primarySoft,
                    child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase(), style: context.hMd.copyWith(color: AppColors.primaryDark)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(user.name, style: context.titleLg),
                      Text(user.email, style: context.small),
                      Text(user.phone, style: context.small),
                    ]),
                  ),
                  IconButton(tooltip: 'Edit profile', icon: const Icon(Icons.edit_outlined), onPressed: () => context.push('/profile/edit')),
                ]),
              ),
              const SizedBox(height: 16),
              Card(
                child: Column(children: [
                  item(Icons.receipt_long_outlined, 'My Orders', () => context.go('/orders')),
                  const Divider(),
                  item(Icons.favorite_border, 'My Wishlist', () => context.push('/wishlist')),
                  const Divider(),
                  item(Icons.person_outline, 'Edit profile', () => context.push('/profile/edit')),
                ]),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(children: [
                  item(Icons.mail_outline, 'Contact Us', () => context.push('/contact')),
                  const Divider(),
                  item(Icons.help_outline, 'Help & Support', () => context.push('/help')),
                  const Divider(),
                  item(Icons.privacy_tip_outlined, 'Privacy Policy', () => context.push('/privacy')),
                  const Divider(),
                  item(Icons.description_outlined, 'Terms & Conditions', () => context.push('/terms')),
                ]),
              ),
              const SizedBox(height: 12),
              Card(
                child: Column(children: [
                  item(Icons.logout, 'Log out', () async {
                    final ok = await confirmDialog(context, title: 'Log out?', message: 'You will need to sign in again to manage your bookings.', confirmLabel: 'Log out');
                    if (ok) await ref.read(sessionProvider.notifier).logout();
                  }),
                  const Divider(),
                  item(Icons.delete_forever_outlined, 'Permanently delete account', () => context.push('/delete-account'), color: AppColors.danger),
                ]),
              ),
            ]),
    );
  }
}
