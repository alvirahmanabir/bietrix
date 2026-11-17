import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/geo.dart';
import 'package:jamcon/domain/services/services.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';
import 'package:jamcon/features/customer/booking/booking_draft.dart';
import 'package:jamcon/features/customer/builder/builder_screen.dart';
import 'package:jamcon/features/customer/home/home_screen.dart' show CouponTile;

const _titles = ['Package', 'Schedule', 'Location', 'Your details', 'Coupon', 'Payment'];

final _blockedDatesProvider = FutureProvider.autoDispose<Set<DateTime>>((ref) => ref.watch(bookingServiceProvider).fullyBookedDates());
final _freeSlotsProvider = FutureProvider.autoDispose.family<List<String>, DateTime>((ref, d) => ref.watch(bookingServiceProvider).freeSlots(d));

class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({super.key});
  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  final _locKey = GlobalKey<FormState>();
  final _contactKey = GlobalKey<FormState>();
  bool _busy = false;
  PaymentProvider _provider = PaymentProvider.bkash;

  int get _step {
    final s = ref.read(bookingDraftProvider).step;
    return s < 0 ? 0 : (s > 5 ? 5 : s);
  }

  void _toast(String m) => ErrorHandler.show(context, ValidationFailure(m));

  void _next() {
    final d = ref.read(bookingDraftProvider);
    final n = ref.read(bookingDraftProvider.notifier);
    switch (_step) {
      case 0:
        if (ref.read(draftSummaryProvider) == null) return _toast('Select a package or build a custom one to continue');
      case 1:
        if (d.date == null || d.slot == null) return _toast('Choose a date and a time slot');
      case 2:
        if (!(_locKey.currentState?.validate() ?? false)) return;
      case 3:
        if (!(_contactKey.currentState?.validate() ?? false)) return;
      case 5:
        _place();
        return;
    }
    n.setStep(_step + 1);
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      ref.read(bookingDraftProvider.notifier).setStep(_step - 1);
    }
  }

  Future<void> _place() async {
    final d = ref.read(bookingDraftProvider);
    final session = ref.read(sessionProvider);
    final summary = ref.read(draftSummaryProvider);
    final user = ref.read(currentUserProvider).value;
    final pricing = ref.read(draftPricingProvider);
    if (session == null || summary == null || pricing == null || user == null || d.date == null || d.slot == null) return;
    setState(() => _busy = true);
    try {
      String? paymentRef;
      var paid = false;
      var method = d.method;
      if (method == PaymentMethod.online) {
        final out = await showModalBottomSheet<({PaymentResult? result, bool cash})>(
          context: context,
          isScrollControlled: true,
          isDismissible: false,
          builder: (_) => _GatewaySheet(provider: _provider, amount: pricing.total),
        );
        if (out == null) return;
        if (out.cash) {
          ref.read(bookingDraftProvider.notifier).setMethod(PaymentMethod.cashOnSite);
          method = PaymentMethod.cashOnSite;
        } else if (out.result?.success ?? false) {
          paid = true;
          paymentRef = out.result!.reference;
        } else {
          return;
        }
      }
      final booking = await ref.read(bookingServiceProvider).create(BookingRequest(
            customerId: session.userId,
            packageId: summary.isCustom ? null : d.packageId,
            items: summary.isCustom ? d.items : const {},
            schedule: EventSchedule(date: d.date!, slot: d.slot!),
            location: EventLocation(division: d.division, district: d.district, area: d.area, detail: d.detail),
            contact: ContactInfo(name: d.name, phone: d.phone, email: user.email, altPhone: d.altPhone, notes: d.notes),
            couponCode: d.couponCode,
            paymentMethod: method,
            paymentProvider: method == PaymentMethod.online ? _provider : null,
            paymentReference: paymentRef,
            paymentConfirmed: paid,
          ));
      ref.read(bookingDraftProvider.notifier).clear();
      ref.read(builderSelectionProvider.notifier).clear();
      if (mounted) context.go('/book/confirmed/${booking.id}');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(bookingDraftProvider);
    final pricing = ref.watch(draftPricingProvider);
    final step = _step;
    final last = step == 5;
    final online = d.method == PaymentMethod.online;

    return PopScope(
      canPop: step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titles[step]),
          actions: [
            PopupMenuButton<String>(
              onSelected: (_) async {
                final ok = await confirmDialog(context, title: 'Start over?', message: 'Your current booking details will be cleared.', confirmLabel: 'Start over', destructive: true);
                if (ok) ref.read(bookingDraftProvider.notifier).clear();
              },
              itemBuilder: (_) => const [PopupMenuItem(value: 'reset', child: Text('Start over'))],
            ),
          ],
        ),
        body: Column(children: [
          _StepBar(step: step),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: switch (step) {
                    0 => const _PackageStep(),
                    1 => const _ScheduleStep(),
                    2 => _LocationStep(formKey: _locKey),
                    3 => _ContactStep(formKey: _contactKey),
                    4 => const _CouponStep(),
                    _ => _PaymentStep(provider: _provider, onProvider: (p) => setState(() => _provider = p)),
                  },
                ),
              ),
            ),
          ),
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              decoration: BoxDecoration(color: context.surface, border: Border(top: BorderSide(color: context.border))),
              child: Row(children: [
                if (step > 0) ...[SizedBox(width: 96, child: AppButton(label: 'Back', variant: AppButtonVariant.secondary, onPressed: _busy ? null : _back)), const SizedBox(width: 12)],
                Expanded(
                  child: AppButton(
                    loading: _busy,
                    label: last ? (online ? 'Pay ${Fmt.money(pricing?.total ?? 0)} & book' : 'Place booking') : 'Continue',
                    icon: last ? Icons.check_circle_outline : Icons.arrow_forward,
                    onPressed: _next,
                  ),
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _StepBar extends StatelessWidget {
  const _StepBar({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            for (var i = 0; i < _titles.length; i++)
              Expanded(
                child: Container(
                  height: 5,
                  margin: EdgeInsets.only(right: i == _titles.length - 1 ? 0 : 4),
                  decoration: BoxDecoration(color: i <= step ? AppColors.primary : context.border, borderRadius: BorderRadius.circular(3)),
                ),
              ),
          ]),
          const SizedBox(height: 6),
          Text('Step ${step + 1} of ${_titles.length}', style: context.small),
        ]),
      );
}

// ───────── Step 1: package ─────────
class _PackageStep extends ConsumerWidget {
  const _PackageStep();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(bookingDraftProvider);
    final summary = ref.watch(draftSummaryProvider);
    if (summary == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (d.hasSelection) ...[
          const AppCard(child: Row(children: [Icon(Icons.warning_amber_rounded, color: AppColors.warning), SizedBox(width: 12), Expanded(child: Text('Your previous selection is no longer available. Please choose again.'))])),
          const SizedBox(height: 16),
        ],
        Text('What would you like to book?', style: context.titleLg),
        const SizedBox(height: 12),
        SelectableTile(selected: false, onTap: () => context.go('/packages'), icon: Icons.inventory_2_outlined, title: 'Choose a package', subtitle: 'Ready-made bundles at a great price'),
        const SizedBox(height: 10),
        SelectableTile(selected: false, onTap: () => context.push('/builder'), icon: Icons.tune, title: 'Build a custom package', subtitle: 'Pick individual services'),
      ]);
    }
    final pricing = ref.watch(draftPricingProvider)!;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(summary.title, style: context.titleLg)),
            Pill(summary.isCustom ? 'Custom' : 'Package', color: AppColors.primary),
          ]),
          const SizedBox(height: 10),
          for (final i in summary.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                const Icon(Icons.check_circle, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(child: Text('${i.name}${i.qty > 1 ? '  ×${i.qty}' : ''}')),
                if (summary.isCustom) Text(Fmt.money(i.lineTotal), style: context.body.copyWith(fontWeight: FontWeight.w600)),
              ]),
            ),
          const Divider(height: 24),
          PriceSummary(pricing: pricing, couponCode: d.couponCode),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(
          child: AppButton(
            label: summary.isCustom ? 'Edit services' : 'Change package',
            icon: Icons.edit_outlined,
            variant: AppButtonVariant.secondary,
            onPressed: () => summary.isCustom ? context.push('/builder') : context.go('/packages'),
          ),
        ),
      ]),
    ]);
  }
}

// ───────── Step 2: schedule ─────────
class _ScheduleStep extends ConsumerStatefulWidget {
  const _ScheduleStep();
  @override
  ConsumerState<_ScheduleStep> createState() => _ScheduleStepState();
}

class _ScheduleStepState extends ConsumerState<_ScheduleStep> {
  DateTime _firstSelectable(Set<DateTime> blocked) {
    var d = dateOnly(DateTime.now());
    for (var i = 0; i < 365; i++) {
      if (!blocked.contains(d)) return d;
      d = d.add(const Duration(days: 1));
    }
    return d;
  }

  @override
  Widget build(BuildContext context) {
    final blockedAsync = ref.watch(_blockedDatesProvider);
    final d = ref.watch(bookingDraftProvider);
    return AsyncValueView<Set<DateTime>>(
      value: blockedAsync,
      loading: const Padding(padding: EdgeInsets.only(top: 40), child: Center(child: CircularProgressIndicator())),
      data: (blocked) {
        final today = dateOnly(DateTime.now());
        var initial = d.date != null ? dateOnly(d.date!) : _firstSelectable(blocked);
        if (initial.isBefore(today) || blocked.contains(initial)) initial = _firstSelectable(blocked);
        if (d.date == null || dateOnly(d.date!) != initial) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) ref.read(bookingDraftProvider.notifier).setSchedule(initial);
          });
        }
        final selected = d.date == null ? initial : dateOnly(d.date!);
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Select event date', style: context.titleLg),
          const SizedBox(height: 4),
          Text('Greyed-out dates are fully booked.', style: context.small),
          const SizedBox(height: 8),
          AppCard(
            padding: const EdgeInsets.all(4),
            child: CalendarDatePicker(
              initialDate: initial,
              firstDate: today,
              lastDate: today.add(const Duration(days: 365)),
              selectableDayPredicate: (day) => !blocked.contains(dateOnly(day)),
              onDateChanged: (day) => ref.read(bookingDraftProvider.notifier).setSchedule(dateOnly(day)),
            ),
          ),
          const SizedBox(height: 20),
          Text('Preferred time · ${Fmt.dateLong(selected)}', style: context.titleLg),
          const SizedBox(height: 10),
          Consumer(builder: (context, ref, _) {
            final slots = ref.watch(_freeSlotsProvider(selected));
            return slots.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => ErrorView(error: e),
              data: (free) => Wrap(spacing: 10, runSpacing: 10, children: [
                for (final s in EventSlots.all)
                  ChoiceChip(
                    avatar: Icon(Icons.schedule, size: 16, color: d.slot == s ? AppColors.primaryDark : null),
                    label: Text(free.contains(s) ? s : '$s · booked'),
                    selected: d.slot == s,
                    onSelected: free.contains(s) ? (_) => ref.read(bookingDraftProvider.notifier).setSchedule(selected, slot: s) : null,
                  ),
              ]),
            );
          }),
        ]);
      },
    );
  }
}

// ───────── Step 3: location ─────────
class _LocationStep extends ConsumerStatefulWidget {
  const _LocationStep({required this.formKey});
  final GlobalKey<FormState> formKey;
  @override
  ConsumerState<_LocationStep> createState() => _LocationStepState();
}

class _LocationStepState extends ConsumerState<_LocationStep> {
  late final _area = TextEditingController(text: ref.read(bookingDraftProvider).area);
  late final _detail = TextEditingController(text: ref.read(bookingDraftProvider).detail);

  @override
  void dispose() {
    _area.dispose();
    _detail.dispose();
    super.dispose();
  }

  Widget _labeled(String label, Widget child) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: context.label), const SizedBox(height: 6), child]);

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(bookingDraftProvider);
    final n = ref.read(bookingDraftProvider.notifier);
    final districts = BdGeo.districts[d.division] ?? const <String>[];
    return Form(
      key: widget.formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Where will the event take place?', style: context.titleLg),
        const SizedBox(height: 16),
        _labeled(
          'Division',
          DropdownButtonFormField<String>(
            key: const ValueKey('division'),
            initialValue: BdGeo.divisions.contains(d.division) ? d.division : null,
            hint: const Text('Select division'),
            items: [for (final v in BdGeo.divisions) DropdownMenuItem(value: v, child: Text(v))],
            validator: (v) => v == null ? 'Select a division' : null,
            onChanged: (v) => n.setLocation(division: v ?? '', district: ''),
          ),
        ),
        const SizedBox(height: 16),
        _labeled(
          'District',
          DropdownButtonFormField<String>(
            key: ValueKey('district-${d.division}'),
            initialValue: districts.contains(d.district) ? d.district : null,
            hint: Text(d.division.isEmpty ? 'Select a division first' : 'Select district'),
            items: [for (final v in districts) DropdownMenuItem(value: v, child: Text(v))],
            validator: (v) => v == null ? 'Select a district' : null,
            onChanged: districts.isEmpty ? null : (v) => n.setLocation(district: v ?? ''),
          ),
        ),
        const SizedBox(height: 16),
        AppTextField(label: 'Area / Thana', controller: _area, hint: 'e.g. Dhanmondi', validator: (v) => Validators.required(v, 'Area'), onChanged: (v) => n.setLocation(area: v)),
        const SizedBox(height: 16),
        AppTextField(label: 'Detailed address', controller: _detail, maxLines: 3, hint: 'House, road, landmark, venue name', validator: (v) => Validators.minLength(v, 5, 'Address'), onChanged: (v) => n.setLocation(detail: v)),
        const SizedBox(height: 16),
        AppCard(
          child: Row(children: [
            const Icon(Icons.map_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text('Map pin selection will be available once map services are connected. Your address details are saved with the booking.', style: context.small)),
          ]),
        ),
      ]),
    );
  }
}

// ───────── Step 4: customer details ─────────
class _ContactStep extends ConsumerStatefulWidget {
  const _ContactStep({required this.formKey});
  final GlobalKey<FormState> formKey;
  @override
  ConsumerState<_ContactStep> createState() => _ContactStepState();
}

class _ContactStepState extends ConsumerState<_ContactStep> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _alt;
  late final TextEditingController _notes;

  @override
  void initState() {
    super.initState();
    final d = ref.read(bookingDraftProvider);
    final u = ref.read(currentUserProvider).value;
    _name = TextEditingController(text: d.name.isNotEmpty ? d.name : (u?.name ?? ''));
    _phone = TextEditingController(text: d.phone.isNotEmpty ? d.phone : (u?.phone ?? ''));
    _alt = TextEditingController(text: d.altPhone);
    _notes = TextEditingController(text: d.notes);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(bookingDraftProvider.notifier).setContact(name: _name.text, phone: _phone.text);
    });
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _alt, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = ref.read(bookingDraftProvider.notifier);
    final email = ref.watch(currentUserProvider).value?.email ?? '';
    return Form(
      key: widget.formKey,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Who should we contact?', style: context.titleLg),
        const SizedBox(height: 16),
        AppTextField(label: 'Customer name', controller: _name, prefixIcon: Icons.person_outline, validator: (v) => Validators.required(v, 'Name'), onChanged: (v) => n.setContact(name: v)),
        const SizedBox(height: 16),
        AppTextField(label: 'Contact number', controller: _phone, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined, validator: Validators.phone, onChanged: (v) => n.setContact(phone: v)),
        const SizedBox(height: 16),
        AppTextField(label: 'Registered email', initialValue: email, readOnly: true, prefixIcon: Icons.mail_outline),
        const SizedBox(height: 16),
        AppTextField(label: 'Alternative number (optional)', controller: _alt, keyboardType: TextInputType.phone, prefixIcon: Icons.phone_android_outlined, validator: (v) => Validators.phone(v, optional: true), onChanged: (v) => n.setContact(altPhone: v)),
        const SizedBox(height: 16),
        AppTextField(label: 'Special instructions (optional)', controller: _notes, maxLines: 3, hint: 'Anything the team should know?', onChanged: (v) => n.setContact(notes: v)),
      ]),
    );
  }
}

// ───────── Step 5: coupon ─────────
class _CouponStep extends ConsumerStatefulWidget {
  const _CouponStep();
  @override
  ConsumerState<_CouponStep> createState() => _CouponStepState();
}

class _CouponStepState extends ConsumerState<_CouponStep> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply(String code) async {
    final summary = ref.read(draftSummaryProvider);
    final session = ref.read(sessionProvider);
    if (summary == null || session == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final check = await ref.read(couponServiceProvider).validate(code: code, subtotal: summary.subtotal, customerId: session.userId);
      if (!mounted) return;
      if (check.isOk) {
        ref.read(bookingDraftProvider.notifier).applyCoupon(check.coupon!.code, check.discount);
        _code.clear();
      } else {
        setState(() => _error = check.message);
      }
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(bookingDraftProvider);
    final pricing = ref.watch(draftPricingProvider);
    final coupons = ref.watch(availableCouponsProvider).value ?? const [];
    final applied = d.couponCode != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Have a coupon?', style: context.titleLg),
      const SizedBox(height: 12),
      if (applied)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.success.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.success.withValues(alpha: 0.4))),
          child: Row(children: [
            const Icon(Icons.check_circle, color: AppColors.success),
            const SizedBox(width: 12),
            Expanded(child: Text('${d.couponCode} applied - you save ${Fmt.money(d.couponDiscount)}', style: context.title)),
            TextButton(onPressed: () => ref.read(bookingDraftProvider.notifier).clearCoupon(), child: const Text('Remove')),
          ]),
        )
      else ...[
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              onSubmitted: _apply,
              decoration: InputDecoration(hintText: 'Enter coupon code', errorText: _error, prefixIcon: const Icon(Icons.local_offer_outlined)),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(height: 50, child: AppButton(label: 'Apply', expand: false, loading: _loading, onPressed: () => _apply(_code.text))),
        ]),
        if (coupons.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('Available for you', style: context.titleSm),
          const SizedBox(height: 8),
          for (final c in coupons)
            Padding(padding: const EdgeInsets.only(bottom: 8), child: CouponTile(coupon: c, onApply: _loading ? null : () => _apply(c.code))),
        ],
      ],
      if (pricing != null) ...[
        const SizedBox(height: 20),
        AppCard(child: PriceSummary(pricing: pricing, couponCode: d.couponCode)),
      ],
    ]);
  }
}

// ───────── Step 6: payment ─────────
class _PaymentStep extends ConsumerWidget {
  const _PaymentStep({required this.provider, required this.onProvider});
  final PaymentProvider provider;
  final ValueChanged<PaymentProvider> onProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(bookingDraftProvider);
    final summary = ref.watch(draftSummaryProvider);
    final pricing = ref.watch(draftPricingProvider);
    final n = ref.read(bookingDraftProvider.notifier);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Payment method', style: context.titleLg),
      const SizedBox(height: 12),
      SelectableTile(selected: d.method == PaymentMethod.cashOnSite, onTap: () => n.setMethod(PaymentMethod.cashOnSite), icon: Icons.payments_outlined, title: 'Cash on Site', subtitle: 'Pay when our team arrives at the event'),
      const SizedBox(height: 10),
      SelectableTile(selected: d.method == PaymentMethod.online, onTap: () => n.setMethod(PaymentMethod.online), icon: Icons.credit_card, title: 'Online Payment', subtitle: 'bKash, Nagad or card (simulated)'),
      if (d.method == PaymentMethod.online) ...[
        const SizedBox(height: 14),
        Wrap(spacing: 8, children: [
          for (final p in PaymentProvider.values) ChoiceChip(label: Text(p.label), selected: provider == p, onSelected: (_) => onProvider(p)),
        ]),
      ],
      const SizedBox(height: 24),
      Text('Review', style: context.titleLg),
      const SizedBox(height: 10),
      AppCard(
        child: Column(children: [
          InfoRow('Package', summary?.title ?? '-'),
          InfoRow('Date', d.date == null ? '-' : Fmt.dateLong(d.date!)),
          InfoRow('Time', d.slot ?? '-'),
          InfoRow('Location', '${d.detail}, ${d.area}, ${d.district}'),
          const Divider(height: 20),
          if (pricing != null) PriceSummary(pricing: pricing, couponCode: d.couponCode),
        ]),
      ),
    ]);
  }
}

// ───────── Simulated payment gateway ─────────
enum _GwState { idle, processing, success, failed }

class _GatewaySheet extends ConsumerStatefulWidget {
  const _GatewaySheet({required this.provider, required this.amount});
  final PaymentProvider provider;
  final int amount;
  @override
  ConsumerState<_GatewaySheet> createState() => _GatewaySheetState();
}

class _GatewaySheetState extends ConsumerState<_GatewaySheet> {
  final _cred = TextEditingController();
  _GwState _state = _GwState.idle;
  String _message = '';

  @override
  void dispose() {
    _cred.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    setState(() => _state = _GwState.processing);
    final res = await ref.read(paymentServiceProvider).charge(amount: widget.amount, provider: widget.provider, credential: _cred.text);
    if (!mounted) return;
    if (res.success) {
      setState(() => _state = _GwState.success);
      await Future<void>.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context, (result: res, cash: false));
    } else {
      setState(() {
        _state = _GwState.failed;
        _message = res.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.provider == PaymentProvider.card;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        switch (_state) {
          _GwState.idle => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Pay with ${widget.provider.label}', style: context.titleLg),
              const SizedBox(height: 4),
              Text('Amount: ${Fmt.money(widget.amount)}', style: context.body.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              AppTextField(
                label: card ? 'Card number' : '${widget.provider.label} PIN',
                controller: _cred,
                obscure: !card,
                keyboardType: TextInputType.number,
                helper: 'Demo only - any 4+ digits succeed; ending in 0000 simulates a failure.',
              ),
              const SizedBox(height: 18),
              AppButton(label: 'Pay ${Fmt.money(widget.amount)}', onPressed: _pay),
              AppButton(label: 'Cancel', variant: AppButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
            ]),
          _GwState.processing => const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: Column(children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Processing payment…')])),
            ),
          _GwState.success => const Padding(
              padding: EdgeInsets.symmetric(vertical: 36),
              child: Center(child: Column(children: [Icon(Icons.check_circle, color: AppColors.success, size: 64), SizedBox(height: 12), Text('Payment successful')])),
            ),
          _GwState.failed => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Center(child: Icon(Icons.error_rounded, color: AppColors.danger, size: 56)),
              const SizedBox(height: 10),
              Center(child: Text('Payment failed', style: context.titleLg)),
              const SizedBox(height: 6),
              Center(child: Text(_message, textAlign: TextAlign.center, style: context.body.copyWith(color: context.muted))),
              const SizedBox(height: 18),
              AppButton(label: 'Try again', onPressed: () => setState(() => _state = _GwState.idle)),
              const SizedBox(height: 8),
              AppButton(label: 'Pay with cash on site instead', variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(context, (result: null, cash: true))),
              AppButton(label: 'Cancel', variant: AppButtonVariant.ghost, onPressed: () => Navigator.pop(context)),
            ]),
        },
      ]),
    );
  }
}
