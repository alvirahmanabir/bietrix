import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/config/env.dart';
import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/mock/mock_database.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 56, this.light = false});
  final double size;
  final bool light;
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.3),
          gradient: light ? null : const LinearGradient(colors: [AppColors.primary, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight),
          color: light ? Colors.white.withValues(alpha: 0.2) : null,
        ),
        child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: size * 0.5),
      );
}

/// Shared frame for all auth screens.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.title, required this.subtitle, required this.children, this.showBack = true});
  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: showBack ? AppBar() : null,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const BrandMark(),
                  const SizedBox(height: 20),
                  Text(title, style: context.hLg),
                  const SizedBox(height: 6),
                  Text(subtitle, style: context.body.copyWith(color: context.muted)),
                  const SizedBox(height: 28),
                  ...children,
                ]),
              ),
            ),
          ),
        ),
      );
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 900), () {
      if (mounted) context.go('/home'); // router redirect sends guests/admins to the right place
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, AppColors.secondary], begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const BrandMark(size: 84, light: true),
              const SizedBox(height: 20),
              Text(Env.appName, style: context.hLg.copyWith(color: Colors.white)),
              const SizedBox(height: 6),
              Text('Book your studio. Capture the moment.', style: context.body.copyWith(color: Colors.white70)),
              const SizedBox(height: 32),
              const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white)),
            ]),
          ),
        ),
      );
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    Widget point(IconData i, String t, String s) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)), child: Icon(i, color: Colors.white, size: 20)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: context.title.copyWith(color: Colors.white)), Text(s, style: context.small.copyWith(color: Colors.white70))])),
          ]),
        );
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [AppColors.primaryDark, Color(0xFF9D174D)], begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const BrandMark(size: 64, light: true),
                  const SizedBox(height: 24),
                  Text('Studio services,\nbooked in minutes.', style: context.hLg.copyWith(color: Colors.white, fontSize: 32)),
                  const SizedBox(height: 28),
                  point(Icons.inventory_2_outlined, 'Ready-made packages', 'Pick a package for weddings, events and portraits.'),
                  point(Icons.tune, 'Build your own', 'Choose exactly the services you need.'),
                  point(Icons.event_available_outlined, 'Easy scheduling', 'Choose a date, time and location - done.'),
                  const SizedBox(height: 18),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryDark),
                    onPressed: () => context.push('/register'),
                    child: const Text('Get started'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                    onPressed: () => context.push('/login'),
                    child: const Text('I already have an account'),
                  ),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white70),
                      onPressed: () => context.go('/admin/login'),
                      child: const Text('Studio admin portal'),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

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
      await ref.read(sessionProvider.notifier).login(_email.text, _password.text);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'Welcome back',
        subtitle: 'Sign in to manage your bookings.',
        children: [
          Form(
            key: _form,
            child: Column(children: [
              AppTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.mail_outline, validator: Validators.email, textInputAction: TextInputAction.next),
              const SizedBox(height: 16),
              AppTextField(label: 'Password', controller: _password, obscure: true, prefixIcon: Icons.lock_outline, validator: (v) => Validators.required(v, 'Password'), onSubmitted: (_) => _submit()),
            ]),
          ),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.push('/forgot-password'), child: const Text('Forgot password?'))),
          const SizedBox(height: 4),
          AppButton(label: 'Log in', onPressed: _submit, loading: _loading),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text("Don't have an account?", style: context.body.copyWith(color: context.muted)),
            TextButton(onPressed: () => context.pushReplacement('/register'), child: const Text('Sign up')),
          ]),
          const SizedBox(height: 8),
          AppCard(
            onTap: () {
              _email.text = 'demo@jamcon.app';
              _password.text = 'demo123';
            },
            child: Row(children: [
              const Icon(Icons.info_outline, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(child: Text('Demo account - tap to fill\ndemo@jamcon.app / demo123', style: context.small)),
            ]),
          ),
        ],
      );
}

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final email = await ref.read(authServiceProvider).register(name: _name.text, email: _email.text, phone: _phone.text, password: _password.text);
      if (mounted) context.push('/verify-otp?email=${Uri.encodeQueryComponent(email)}');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'Create your account',
        subtitle: 'Your registered email cannot be changed later.',
        children: [
          Form(
            key: _form,
            child: Column(children: [
              AppTextField(label: 'Full name', controller: _name, prefixIcon: Icons.person_outline, validator: (v) => Validators.required(v, 'Name'), textInputAction: TextInputAction.next),
              const SizedBox(height: 16),
              AppTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.mail_outline, validator: Validators.email, textInputAction: TextInputAction.next),
              const SizedBox(height: 16),
              AppTextField(label: 'Phone', controller: _phone, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined, hint: '01XXXXXXXXX', validator: Validators.phone, textInputAction: TextInputAction.next),
              const SizedBox(height: 16),
              AppTextField(label: 'Password', controller: _password, obscure: true, prefixIcon: Icons.lock_outline, validator: Validators.password, textInputAction: TextInputAction.next),
              const SizedBox(height: 16),
              AppTextField(label: 'Confirm password', controller: _confirm, obscure: true, prefixIcon: Icons.lock_outline, validator: (v) => Validators.confirm(v, _password.text), onSubmitted: (_) => _submit()),
            ]),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Create account', onPressed: _submit, loading: _loading),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('Already registered?', style: context.body.copyWith(color: context.muted)),
            TextButton(onPressed: () => context.pushReplacement('/login'), child: const Text('Log in')),
          ]),
        ],
      );
}

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({super.key, required this.email});
  final String email;
  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.trim().length != 6) {
      ErrorHandler.show(context, const ValidationFailure('Enter the 6-digit code'));
      return;
    }
    setState(() => _loading = true);
    try {
      await ref.read(sessionProvider.notifier).verifyOtp(widget.email, _code.text);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthScaffold(
        title: 'Verify your email',
        subtitle: 'We sent a 6-digit code to ${widget.email}.',
        children: [
          AppTextField(
            label: 'Verification code',
            controller: _code,
            keyboardType: TextInputType.number,
            maxLength: 6,
            prefixIcon: Icons.pin_outlined,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            helper: 'Demo mode: use ${MockDatabase.demoOtp}',
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 20),
          AppButton(label: 'Verify & continue', onPressed: _verify, loading: _loading),
          Center(
            child: TextButton(
              onPressed: () async {
                await ref.read(authServiceProvider).resendOtp(widget.email);
                if (context.mounted) ErrorHandler.success(context, 'A new code has been sent');
              },
              child: const Text('Resend code'),
            ),
          ),
        ],
      );
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _sent = false;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() job, {String? done, VoidCallback? then}) async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await job();
      if (!mounted) return;
      if (done != null) ErrorHandler.success(context, done);
      then?.call();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.read(authServiceProvider);
    return AuthScaffold(
      title: 'Reset password',
      subtitle: _sent ? 'Enter the code we emailed you and choose a new password.' : "Enter your account email and we'll send a verification code.",
      children: [
        Form(
          key: _form,
          child: Column(children: [
            AppTextField(label: 'Email', controller: _email, readOnly: _sent, keyboardType: TextInputType.emailAddress, prefixIcon: Icons.mail_outline, validator: Validators.email),
            if (_sent) ...[
              const SizedBox(height: 16),
              AppTextField(label: 'Verification code', controller: _code, keyboardType: TextInputType.number, maxLength: 6, helper: 'Demo mode: use ${MockDatabase.demoOtp}', validator: (v) => Validators.required(v, 'Code')),
              const SizedBox(height: 16),
              AppTextField(label: 'New password', controller: _password, obscure: true, validator: Validators.password),
            ],
          ]),
        ),
        const SizedBox(height: 24),
        if (!_sent)
          AppButton(label: 'Send code', loading: _loading, onPressed: () => _run(() => auth.requestPasswordReset(_email.text), done: 'Verification code sent', then: () => setState(() => _sent = true)))
        else
          AppButton(
            label: 'Update password',
            loading: _loading,
            onPressed: () => _run(() => auth.resetPassword(email: _email.text, code: _code.text, newPassword: _password.text), done: 'Password updated. Please log in.', then: () => context.go('/login')),
          ),
      ],
    );
  }
}
