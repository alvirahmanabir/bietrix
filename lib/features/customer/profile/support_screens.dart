import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/config/env.dart';
import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/support.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

class ContactUsScreen extends ConsumerStatefulWidget {
  const ContactUsScreen({super.key});
  @override
  ConsumerState<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends ConsumerState<ContactUsScreen> {
  final _key = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  SupportCategory _category = SupportCategory.generalSupport;
  bool _busy = false;
  bool _prefilled = false;
  SupportRequest? _sent;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _subject, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_key.currentState!.validate()) return;
    final s = ref.read(sessionProvider);
    if (s == null) return;
    setState(() => _busy = true);
    try {
      final r = await ref.read(supportServiceProvider).submit(SupportRequest(
            id: '',
            userId: s.userId,
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            category: _category,
            subject: _subject.text,
            message: _message.text,
            createdAt: DateTime.now(),
          ));
      if (mounted) setState(() => _sent = r);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    if (user != null && !_prefilled) {
      _prefilled = true;
      _name.text = user.name;
      _email.text = user.email;
      _phone.text = user.phone;
    }
    if (_sent != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Contact us')),
        body: EmptyState(
          icon: Icons.mark_email_read_outlined,
          title: 'Request submitted',
          message: 'Thanks ${_sent!.name.split(' ').first}! Our team will get back to you at ${_sent!.email}. Reference: ${_sent!.id}',
          actionLabel: 'Done',
          onAction: () => context.pop(),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Contact us')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Form(
              key: _key,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                AppTextField(label: 'Name', controller: _name, validator: (v) => Validators.required(v, 'Name')),
                const SizedBox(height: 14),
                AppTextField(label: 'Email', controller: _email, keyboardType: TextInputType.emailAddress, validator: Validators.email),
                const SizedBox(height: 14),
                AppTextField(label: 'Phone number', controller: _phone, keyboardType: TextInputType.phone, validator: Validators.phone),
                const SizedBox(height: 14),
                Text('Request category', style: context.label),
                const SizedBox(height: 6),
                DropdownButtonFormField<SupportCategory>(
                  initialValue: _category,
                  items: [for (final c in SupportCategory.values) DropdownMenuItem(value: c, child: Text(c.label))],
                  onChanged: (v) => setState(() => _category = v ?? _category),
                ),
                const SizedBox(height: 14),
                AppTextField(label: 'Subject', controller: _subject, validator: (v) => Validators.required(v, 'Subject')),
                const SizedBox(height: 14),
                AppTextField(label: 'Message', controller: _message, maxLines: 5, validator: (v) => Validators.minLength(v, 10, 'Message')),
                const SizedBox(height: 24),
                AppButton(label: 'Submit request', icon: Icons.send_outlined, loading: _busy, onPressed: _submit),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  static const _faqs = [
    ('How do I book a package?', 'Open a package, tap "Book now", then follow the steps: schedule, location, your details, coupon and payment.'),
    ('Can I cancel my booking?', 'Yes - while it is Pending Confirmation you can cancel it from the order page. Once the studio confirms it, only the studio can cancel; please contact support.'),
    ('How do coupons work?', 'Enter a code (or pick an available one) in the coupon step. Coupons may have a minimum order value, an expiry date and usage limits.'),
    ('What payment options are available?', 'Cash on site, or online payment (bKash, Nagad, card). Online payments are simulated in this version.'),
    ('Can I change my registered email?', 'No. Your registered email identifies your account and cannot be changed. You can update your name, phone and address.'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Help & Support')),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          for (final f in _faqs)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ExpansionTile(
                  shape: const Border(),
                  collapsedShape: const Border(),
                  title: Text(f.$1, style: context.title),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: [Text(f.$2, style: context.body.copyWith(color: context.muted))],
                ),
              ),
            ),
          const SizedBox(height: 8),
          AppButton(label: 'Still need help? Contact us', icon: Icons.mail_outline, onPressed: () => context.push('/contact')),
        ]),
      );
}

enum PolicyKind { privacy, terms }

class PolicyScreen extends StatelessWidget {
  const PolicyScreen({super.key, required this.kind});
  final PolicyKind kind;

  @override
  Widget build(BuildContext context) {
    final privacy = kind == PolicyKind.privacy;
    final sections = privacy
        ? const [
            ('Information we collect', 'We collect your name, contact details, event details and booking history to provide our studio services.'),
            ('How we use it', 'Your information is used to process bookings, communicate with you, and improve our services. We do not sell personal data.'),
            ('Your choices', 'You can edit your profile at any time, and permanently delete your account from the Profile screen.'),
            ('Data retention', 'Booking records may be kept for accounting purposes after account deletion, in anonymised form.'),
          ]
        : const [
            ('Bookings', 'A booking is confirmed only after the studio confirms it. Pending bookings can be cancelled by you at no cost.'),
            ('Cancellations', 'Once confirmed, a booking can only be cancelled by the studio. Contact support for changes.'),
            ('Payments', 'Cash payments are collected on site. Online payments are processed by the selected provider.'),
            ('Coupons', 'Coupons are subject to expiry dates, minimum order values and usage limits.'),
          ];
    return Scaffold(
      appBar: AppBar(title: Text(privacy ? 'Privacy Policy' : 'Terms & Conditions')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Text('${Env.appName} · ${privacy ? 'Privacy Policy' : 'Terms & Conditions'}', style: context.hMd),
        const SizedBox(height: 4),
        Text('Sample text for the frontend prototype - replace with your legal copy.', style: context.small.copyWith(color: AppColors.warning)),
        const SizedBox(height: 16),
        for (final s in sections) ...[
          Text(s.$1, style: context.titleLg),
          const SizedBox(height: 6),
          Text(s.$2, style: context.body.copyWith(height: 1.6)),
          const SizedBox(height: 18),
        ],
      ]),
    );
  }
}
