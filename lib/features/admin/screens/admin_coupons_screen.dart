import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/features/admin/widgets/admin_widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

class AdminCouponsScreen extends ConsumerWidget {
  const AdminCouponsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(couponsProvider);
    final now = DateTime.now();
    return AdminPage(
      title: 'Coupons',
      subtitle: 'Discount codes used by the customer booking flow.',
      actions: [AppButton(label: 'New coupon', icon: Icons.add, expand: false, onPressed: () => showDialog<bool>(context: context, builder: (_) => const CouponFormDialog()))],
      child: AsyncValueView<List<Coupon>>(
        value: async,
        data: (list) {
          if (list.isEmpty) return const EmptyState(icon: Icons.local_offer_outlined, title: 'No coupons yet');
          return AdminTable(
            columns: const ['Code', 'Discount', 'Min order', 'Expires', 'Usage', 'Active', 'Actions'],
            rows: [
              for (final c in list)
                DataRow(cells: [
                  DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(c.code, style: context.titleSm.copyWith(color: AppColors.primary)),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 220), child: Text(c.description, style: context.small, overflow: TextOverflow.ellipsis)),
                  ])),
                  DataCell(Text(c.valueLabel + (c.type == CouponType.percent && c.maxDiscount != null ? ' (max ${Fmt.money(c.maxDiscount!)})' : ''))),
                  DataCell(Text(c.minOrder == 0 ? '-' : Fmt.money(c.minOrder))),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [Text(Fmt.date(c.expiresAt)), if (c.isExpired(now)) ...[const SizedBox(width: 6), const Pill('Expired', color: AppColors.danger)]])),
                  DataCell(Text('${c.usedCount} / ${c.usageLimit == 0 ? '∞' : c.usageLimit}')),
                  DataCell(Switch(
                    value: c.isActive,
                    onChanged: (v) async {
                      try {
                        await ref.read(couponServiceProvider).save(c.copyWith(isActive: v), ref.read(sessionProvider)!);
                      } catch (e) {
                        if (context.mounted) ErrorHandler.show(context, e);
                      }
                    },
                  )),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => showDialog<bool>(context: context, builder: (_) => CouponFormDialog(existing: c))),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      onPressed: () async {
                        final ok = await confirmDialog(context, title: 'Delete coupon ${c.code}?', message: 'Customers will no longer be able to use it. Past bookings are unaffected.', confirmLabel: 'Delete', destructive: true);
                        if (!ok) return;
                        try {
                          await ref.read(couponServiceProvider).delete(c.id, ref.read(sessionProvider)!);
                          if (context.mounted) ErrorHandler.success(context, 'Coupon deleted');
                        } catch (e) {
                          if (context.mounted) ErrorHandler.show(context, e);
                        }
                      },
                    ),
                  ])),
                ]),
            ],
          );
        },
      ),
    );
  }
}

class CouponFormDialog extends ConsumerStatefulWidget {
  const CouponFormDialog({super.key, this.existing});
  final Coupon? existing;
  @override
  ConsumerState<CouponFormDialog> createState() => _CouponFormDialogState();
}

class _CouponFormDialogState extends ConsumerState<CouponFormDialog> {
  final _key = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.existing?.code ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _value = TextEditingController(text: widget.existing?.value.toString() ?? '');
  late final _max = TextEditingController(text: widget.existing?.maxDiscount?.toString() ?? '');
  late final _min = TextEditingController(text: (widget.existing?.minOrder ?? 0).toString());
  late final _limit = TextEditingController(text: (widget.existing?.usageLimit ?? 0).toString());
  late final _perUser = TextEditingController(text: (widget.existing?.perUserLimit ?? 1).toString());
  late CouponType _type = widget.existing?.type ?? CouponType.percent;
  late DateTime _expires = widget.existing?.expiresAt ?? DateTime.now().add(const Duration(days: 30));
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    for (final c in [_code, _desc, _value, _max, _min, _limit, _perUser]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) throw const ValidationFailure('Please fix the highlighted fields');
    final e = widget.existing;
    final c = Coupon(
      id: e?.id ?? '',
      code: _code.text,
      description: _desc.text.trim(),
      type: _type,
      value: int.parse(_value.text.trim()),
      maxDiscount: _type == CouponType.percent && _max.text.trim().isNotEmpty ? int.parse(_max.text.trim()) : null,
      minOrder: int.parse(_min.text.trim()),
      expiresAt: DateTime(_expires.year, _expires.month, _expires.day, 23, 59, 59),
      usageLimit: int.parse(_limit.text.trim()),
      perUserLimit: int.parse(_perUser.text.trim()),
      usedCount: e?.usedCount ?? 0,
      isActive: _active,
    );
    await ref.read(couponServiceProvider).save(c, ref.read(sessionProvider)!);
    if (mounted) ErrorHandler.success(context, e == null ? 'Coupon created' : 'Coupon updated');
  }

  @override
  Widget build(BuildContext context) => AdminFormDialog(
        title: widget.existing == null ? 'New coupon' : 'Edit coupon',
        onSave: _save,
        child: Form(
          key: _key,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppTextField(label: 'Coupon code', controller: _code, validator: (v) => Validators.required(v, 'Code')),
            const SizedBox(height: 16),
            AppTextField(label: 'Description', controller: _desc),
            const SizedBox(height: 16),
            Text('Discount type', style: context.label),
            const SizedBox(height: 6),
            SegmentedButton<CouponType>(
              segments: const [ButtonSegment(value: CouponType.percent, label: Text('Percentage %')), ButtonSegment(value: CouponType.fixed, label: Text('Fixed ৳'))],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: AppTextField(label: _type == CouponType.percent ? 'Discount (%)' : 'Discount (৳)', controller: _value, keyboardType: TextInputType.number, validator: (v) => intError(v, 'Discount'))),
              const SizedBox(width: 12),
              if (_type == CouponType.percent) Expanded(child: AppTextField(label: 'Max discount (৳, optional)', controller: _max, keyboardType: TextInputType.number, validator: (v) => intError(v, 'Max discount', optional: true))),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: AppTextField(label: 'Minimum order (৳)', controller: _min, keyboardType: TextInputType.number, validator: (v) => intError(v, 'Minimum order', allowZero: true))),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Expires on', style: context.label),
                  const SizedBox(height: 6),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                    icon: const Icon(Icons.event),
                    label: Text(Fmt.date(_expires)),
                    onPressed: () async {
                      final d = await showDatePicker(context: context, initialDate: _expires, firstDate: DateTime(2024), lastDate: DateTime(2035));
                      if (d != null) setState(() => _expires = d);
                    },
                  ),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: AppTextField(label: 'Total usage limit', controller: _limit, keyboardType: TextInputType.number, helper: '0 = unlimited', validator: (v) => intError(v, 'Usage limit', allowZero: true))),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(label: 'Per-customer limit', controller: _perUser, keyboardType: TextInputType.number, helper: '0 = unlimited', validator: (v) => intError(v, 'Per-customer limit', allowZero: true))),
            ]),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active'), value: _active, onChanged: (v) => setState(() => _active = v)),
          ]),
        ),
      );
}
