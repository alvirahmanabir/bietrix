import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});
  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  bool _busy = false;

  Future<void> _delete() async {
    final first = await confirmDialog(
      context,
      title: 'Delete your account?',
      message: 'This is permanent. Your profile, wishlist and support requests will be erased and pending bookings cancelled.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!first || !mounted) return;
    final second = await showDialog<bool>(context: context, builder: (_) => const _TypeDeleteDialog());
    if (second != true || !mounted) return;
    final session = ref.read(sessionProvider);
    if (session == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(userServiceProvider).deleteAccount(session.userId);
      await ref.read(sessionProvider.notifier).endSessionAfterDeletion(); // router sends the user to the welcome screen
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Delete account')),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.danger.withValues(alpha: 0.4))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 36),
              const SizedBox(height: 10),
              Text('This action is permanent', style: context.titleLg.copyWith(color: AppColors.danger)),
              const SizedBox(height: 8),
              const Text('Deleting your account will:'),
              const SizedBox(height: 6),
              const Text('• Erase your profile and personal information\n• Remove your wishlist and support requests\n• Cancel any bookings that are still pending\n• Sign you out on this device'),
              const SizedBox(height: 10),
              Text('It cannot be undone and you cannot recover your data.', style: context.body.copyWith(fontWeight: FontWeight.w700)),
            ]),
          ),
          const SizedBox(height: 24),
          AppButton(label: 'Delete my account', icon: Icons.delete_forever_outlined, variant: AppButtonVariant.danger, loading: _busy, onPressed: _delete),
        ]),
      );
}

class _TypeDeleteDialog extends StatefulWidget {
  const _TypeDeleteDialog();
  @override
  State<_TypeDeleteDialog> createState() => _TypeDeleteDialogState();
}

class _TypeDeleteDialogState extends State<_TypeDeleteDialog> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Final confirmation'),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Type DELETE to permanently delete your account.'),
          const SizedBox(height: 12),
          TextField(controller: _c, autofocus: true, onChanged: (_) => setState(() {}), decoration: const InputDecoration(hintText: 'DELETE')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _c.text.trim() == 'DELETE' ? () => Navigator.pop(context, true) : null,
            child: const Text('Delete forever'),
          ),
        ],
      );
}
