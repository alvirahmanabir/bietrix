import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/utils/validators.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/features/admin/widgets/admin_widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

class AdminPackagesScreen extends ConsumerWidget {
  const AdminPackagesScreen({super.key});

  Future<void> _save(WidgetRef ref, Package p) async {
    await ref.read(packageServiceProvider).save(p, ref.read(sessionProvider)!);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(packagesProvider);
    return AdminPage(
      title: 'Packages',
      subtitle: 'Create and manage studio packages shown to customers.',
      actions: [AppButton(label: 'New package', icon: Icons.add, expand: false, onPressed: () => showDialog<bool>(context: context, builder: (_) => const PackageFormDialog()))],
      child: AsyncValueView<List<Package>>(
        value: async,
        data: (list) {
          if (list.isEmpty) return const EmptyState(icon: Icons.inventory_2_outlined, title: 'No packages yet', message: 'Create your first package.');
          return AdminTable(
            columns: const ['Package', 'Price', 'Services', 'Active', 'Featured', 'Actions'],
            rows: [
              for (final p in list)
                DataRow(cells: [
                  DataCell(thumbName(context, p.imageKey, p.name, sub: p.id)),
                  DataCell(Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(Fmt.money(p.price), style: context.titleSm),
                    if (p.hasPromo) Text(Fmt.money(p.basePrice), style: context.small.copyWith(decoration: TextDecoration.lineThrough)),
                  ])),
                  DataCell(Text('${p.serviceIds.length}')),
                  DataCell(Switch(
                    value: p.isActive,
                    onChanged: (v) async {
                      try {
                        await _save(ref, p.copyWith(isActive: v));
                      } catch (e) {
                        if (context.mounted) ErrorHandler.show(context, e);
                      }
                    },
                  )),
                  DataCell(IconButton(
                    tooltip: p.isFeatured ? 'Remove from featured' : 'Mark as featured',
                    icon: Icon(p.isFeatured ? Icons.star_rounded : Icons.star_border_rounded, color: p.isFeatured ? AppColors.warning : null),
                    onPressed: () async {
                      try {
                        await _save(ref, p.copyWith(isFeatured: !p.isFeatured));
                      } catch (e) {
                        if (context.mounted) ErrorHandler.show(context, e);
                      }
                    },
                  )),
                  DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => showDialog<bool>(context: context, builder: (_) => PackageFormDialog(existing: p))),
                    IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                      onPressed: () async {
                        final ok = await confirmDialog(context, title: 'Delete "${p.name}"?', message: 'Customers will no longer see this package. Existing bookings keep their own snapshot.', confirmLabel: 'Delete', destructive: true);
                        if (!ok) return;
                        try {
                          await ref.read(packageServiceProvider).delete(p.id, ref.read(sessionProvider)!);
                          if (context.mounted) ErrorHandler.success(context, 'Package deleted');
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

class PackageFormDialog extends ConsumerStatefulWidget {
  const PackageFormDialog({super.key, this.existing});
  final Package? existing;
  @override
  ConsumerState<PackageFormDialog> createState() => _PackageFormDialogState();
}

class _PackageFormDialogState extends ConsumerState<PackageFormDialog> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _price = TextEditingController(text: widget.existing?.basePrice.toString() ?? '');
  late final _promo = TextEditingController(text: widget.existing?.promoPrice?.toString() ?? '');
  late String _image = widget.existing?.imageKey ?? 'studio';
  late final Set<String> _services = {...?widget.existing?.serviceIds};
  late bool _active = widget.existing?.isActive ?? true;
  late bool _featured = widget.existing?.isFeatured ?? false;

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _promo]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) throw const ValidationFailure('Please fix the highlighted fields');
    final base = int.parse(_price.text.trim());
    final promo = _promo.text.trim().isEmpty ? null : int.parse(_promo.text.trim());
    final e = widget.existing;
    final p = Package(
      id: e?.id ?? '',
      name: _name.text,
      description: _desc.text,
      imageKey: _image,
      serviceIds: _services.toList(),
      basePrice: base,
      promoPrice: promo,
      isActive: _active,
      isFeatured: _featured,
    );
    await ref.read(packageServiceProvider).save(p, ref.read(sessionProvider)!);
    if (mounted) ErrorHandler.success(context, e == null ? 'Package created' : 'Package updated');
  }

  @override
  Widget build(BuildContext context) {
    final services = ref.watch(servicesProvider).value ?? const <Service>[];
    return AdminFormDialog(
      title: widget.existing == null ? 'New package' : 'Edit package',
      onSave: _save,
      child: Form(
        key: _key,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppTextField(label: 'Package name', controller: _name, validator: (v) => Validators.required(v, 'Name')),
          const SizedBox(height: 16),
          AppTextField(label: 'Description', controller: _desc, maxLines: 3, validator: (v) => Validators.required(v, 'Description')),
          const SizedBox(height: 16),
          Text('Image (mock upload)', style: context.label),
          const SizedBox(height: 8),
          ImageKeyPicker(value: _image, onChanged: (v) => setState(() => _image = v)),
          const SizedBox(height: 16),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: AppTextField(label: 'Price (৳)', controller: _price, keyboardType: TextInputType.number, validator: (v) => intError(v, 'Price'))),
            const SizedBox(width: 12),
            Expanded(child: AppTextField(label: 'Promo price (৳, optional)', controller: _promo, keyboardType: TextInputType.number, validator: (v) => intError(v, 'Promo price', optional: true))),
          ]),
          const SizedBox(height: 16),
          Text('Included services (${_services.length})', style: context.label),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in services)
              FilterChip(
                label: Text(s.isActive ? s.name : '${s.name} (inactive)'),
                selected: _services.contains(s.id),
                showCheckmark: true,
                onSelected: (v) => setState(() => v ? _services.add(s.id) : _services.remove(s.id)),
              ),
          ]),
          const SizedBox(height: 8),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active (visible to customers)'), value: _active, onChanged: (v) => setState(() => _active = v)),
          SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Featured on home screen'), value: _featured, onChanged: (v) => setState(() => _featured = v)),
        ]),
      ),
    );
  }
}
