import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/auth/presentation/auth_screens.dart';

class AdminLoginScreen extends ConsumerStatefulWidget {
  const AdminLoginScreen({super.key});
  @override
  ConsumerState<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends ConsumerState<AdminLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  static const _demo = [
    ('Super Admin', 'super@jamcon.app'),
    ('Admin', 'admin@jamcon.app'),
    ('Order Manager', 'orders@jamcon.app'),
    ('Customer Support', 'support@jamcon.app'),
  ];

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(sessionProvider.notifier).login(_email.text, _password.text, asAdmin: true);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        showBack: false,
        title: 'Admin sign in',
        subtitle: 'Studio management dashboard. Authorized staff only.',
        children: [
          Form(
            key: _form,
            child: Column(children: [
              AppTextField(label: 'Admin email', controller: _email, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.mail_outline, validator: Validators.email),
              const SizedBox(height: 16),
              AppTextField(label: 'Password', controller: _password, obscure: true, prefixIcon: Icons.lock_outline, validator: (v) => Validators.required(v, 'Password'), onSubmitted: (_) => _submit()),
            ]),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Sign in', onPressed: _submit, loading: _loading),
          Center(child: TextButton(onPressed: () => context.go('/welcome'), child: const Text('Back to customer app'))),
          const SizedBox(height: 8),
          Text('Demo roles (password: admin123) - tap to fill', style: context.small),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final d in _demo)
              ActionChip(
                label: Text(d.$1),
                onPressed: () {
                  _email.text = d.$2;
                  _password.text = 'admin123';
                },
              ),
          ]),
        ],
      );
}
