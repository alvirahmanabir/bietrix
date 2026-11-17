import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/domain/rules/permissions.dart';
import 'package:jamcon/features/admin/widgets/admin_widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

class AdminProfileScreen extends ConsumerWidget {
  const AdminProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final admin = ref.watch(currentAdminProvider).value;
    return AdminPage(
      title: 'My profile',
      subtitle: 'Your account and role privileges.',
      child: admin == null
          ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
          : TwoCol(
              left: _EditCard(admin: admin),
              right: Column(children: [
                Panel(
                  title: 'Role: ${admin.role.label}',
                  child: Column(children: [
                    for (final p in Permission.values)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Permissions.has(admin.role, p) ? Icons.check_circle : Icons.remove_circle_outline, color: Permissions.has(admin.role, p) ? AppColors.success : context.muted),
                        title: Text(Permissions.describe(p), style: TextStyle(color: Permissions.has(admin.role, p) ? null : context.muted)),
                      ),
                  ]),
                ),
                const SizedBox(height: 16),
                AppButton(
                  label: 'Log out',
                  icon: Icons.logout,
                  variant: AppButtonVariant.secondary,
                  onPressed: () async {
                    final ok = await confirmDialog(context, title: 'Log out?', message: 'You will be returned to the admin sign-in.', confirmLabel: 'Log out');
                    if (ok) await ref.read(sessionProvider.notifier).logout();
                  },
                ),
              ]),
            ),
    );
  }
}

class _EditCard extends ConsumerStatefulWidget {
  const _EditCard({required this.admin});
  final AdminUser admin;
  @override
  ConsumerState<_EditCard> createState() => _EditCardState();
}

class _EditCardState extends ConsumerState<_EditCard> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.admin.name);
  late final _phone = TextEditingController(text: widget.admin.phone);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(adminServiceProvider).updateProfile(widget.admin.id, name: _name.text, phone: _phone.text);
      if (mounted) ErrorHandler.success(context, 'Profile updated');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Panel(
        title: 'Profile information',
        child: Form(
          key: _key,
          child: Column(children: [
            AppTextField(label: 'Full name', controller: _name, validator: (v) => Validators.required(v, 'Name')),
            const SizedBox(height: 14),
            AppTextField(label: 'Phone', controller: _phone, keyboardType: TextInputType.phone, validator: (v) => Validators.phone(v, optional: true)),
            const SizedBox(height: 14),
            AppTextField(label: 'Email', initialValue: widget.admin.email, readOnly: true),
            const SizedBox(height: 14),
            AppTextField(label: 'Role', initialValue: widget.admin.role.label, readOnly: true, helper: 'Roles can only be changed by a Super Admin.'),
            const SizedBox(height: 20),
            AppButton(label: 'Save changes', loading: _busy, onPressed: _save),
          ]),
        ),
      );
}
