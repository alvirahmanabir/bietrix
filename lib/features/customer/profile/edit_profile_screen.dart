import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/user.dart';
import 'package:jamcon/features/common/queries.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: user == null ? const ListSkeleton(count: 3) : _Form(user: user),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  const _Form({required this.user});
  final AppUser user;
  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user.name);
  late final _phone = TextEditingController(text: widget.user.phone);
  late final _address = TextEditingController(text: widget.user.address);
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(userServiceProvider).updateProfile(widget.user.id, name: _name.text, phone: _phone.text, address: _address.text);
      if (!mounted) return;
      ErrorHandler.success(context, 'Profile updated');
      context.pop();
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _key,
              child: Column(children: [
                AppTextField(label: 'Full name', controller: _name, prefixIcon: Icons.person_outline, validator: (v) => Validators.required(v, 'Name')),
                const SizedBox(height: 16),
                AppTextField(label: 'Phone number', controller: _phone, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined, validator: Validators.phone),
                const SizedBox(height: 16),
                AppTextField(label: 'Address', controller: _address, maxLines: 3, prefixIcon: Icons.home_outlined),
                const SizedBox(height: 16),
                AppTextField(label: 'Registered email', initialValue: widget.user.email, readOnly: true, prefixIcon: Icons.mail_outline, helper: 'Your registered email cannot be changed.'),
                const SizedBox(height: 28),
                AppButton(label: 'Save changes', loading: _busy, onPressed: _save),
              ]),
            ),
          ),
        ),
      );
}
