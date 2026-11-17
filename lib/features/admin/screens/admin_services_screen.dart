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

class AdminServicesScreen extends ConsumerStatefulWidget {
  const AdminServicesScreen({super.key});
  @override
  ConsumerState<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends ConsumerState<AdminServicesScreen> {
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(servicesProvider);
    return AdminPage(
      title: 'Services',
      subtitle: 'Individual services used by packages and the custom package builder.',
      actions: [AppButton(label: 'New service', icon: Icons.add, expand: false, onPressed: () => showDialog<bool>(context: context, builder: (_) => const ServiceFormDialog()))],
      child: AsyncValueView<List<Service>>(
        value: async,
        data: (all) {
          final list = _category == 'All' ? all : all.where((s) => s.category == _category).toList();
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in ['All', ...ServiceCategories.all]) ChoiceChip(label: Text(c), selected: _category == c, onSelected: (_) => setState(() => _category = c)),
            ]),
            const SizedBox(height: 14),
            if (list.isEmpty)
              const EmptyState(icon: Icons.camera_alt_outlined, title: 'No services in this category')
            else
              AdminTable(
                columns: const ['Service', 'Category', 'Price', 'Max qty', 'Active', 'Actions'],
                rows: [
                  for (final s in list)
                    DataRow(cells: [
                      DataCell(thumbName(context, s.imageKey, s.name, sub: s.description)),
                      DataCell(Text(s.category)),
                      DataCell(Text('${Fmt.money(s.unitPrice)} / ${s.unitLabel}')),
                      DataCell(Text('${s.maxQty}')),
                      DataCell(Switch(
                        value: s.isActive,
                        onChanged: (v) async {
                          try {
                            await ref.read(serviceManagementProvider).save(s.copyWith(isActive: v), ref.read(sessionProvider)!);
                          } catch (e) {
                            if (context.mounted) ErrorHandler.show(context, e);
                          }
                        },
                      )),
                      DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: () => showDialog<bool>(context: context, builder: (_) => ServiceFormDialog(existing: s))),
                        IconButton(
                          tooltip: 'Delete',
                          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
                          onPressed: () async {
                            final ok = await confirmDialog(context, title: 'Delete "${s.name}"?', message: 'It will disappear from the custom package builder.', confirmLabel: 'Delete', destructive: true);
                            if (!ok) return;
                            try {
                              await ref.read(serviceManagementProvider).delete(s.id, ref.read(sessionProvider)!);
                              if (context.mounted) ErrorHandler.success(context, 'Service deleted');
                            } catch (e) {
                              if (context.mounted) ErrorHandler.show(context, e);
                            }
                          },
                        ),
                      ])),
                    ]),
                ],
              ),
          ]);
        },
      ),
    );
  }
}

class ServiceFormDialog extends ConsumerStatefulWidget {
  const ServiceFormDialog({super.key, this.existing});
  final Service? existing;
  @override
  ConsumerState<ServiceFormDialog> createState() => _ServiceFormDialogState();
}

class _ServiceFormDialogState extends ConsumerState<ServiceFormDialog> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final _price = TextEditingController(text: widget.existing?.unitPrice.toString() ?? '');
  late final _unit = TextEditingController(text: widget.existing?.unitLabel ?? 'item');
  late final _max = TextEditingController(text: (widget.existing?.maxQty ?? 1).toString());
  late String _category = widget.existing?.category ?? ServiceCategories.all.first;
  late String _image = widget.existing?.imageKey ?? 'camera';
  late bool _active = widget.existing?.isActive ?? true;

  @override
  void dispose() {
    for (final c in [_name, _desc, _price, _unit, _max]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_key.currentState!.validate()) throw const ValidationFailure('Please fix the highlighted fields');
    final e = widget.existing;
    final s = Service(
      id: e?.id ?? '',
      category: _category,
      name: _name.text,
      description: _desc.text,
      imageKey: _image,
      unitPrice: int.parse(_price.text.trim()),
      unitLabel: _unit.text.trim().isEmpty ? 'item' : _unit.text.trim(),
      maxQty: int.parse(_max.text.trim()),
      isActive: _active,
    );
    await ref.read(serviceManagementProvider).save(s, ref.read(sessionProvider)!);
    if (mounted) ErrorHandler.success(context, e == null ? 'Service created' : 'Service updated');
  }

  @override
  Widget build(BuildContext context) => AdminFormDialog(
        title: widget.existing == null ? 'New service' : 'Edit service',
        onSave: _save,
        child: Form(
          key: _key,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AppTextField(label: 'Service name', controller: _name, validator: (v) => Validators.required(v, 'Name')),
            const SizedBox(height: 16),
            Text('Category', style: context.label),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _category,
              items: [for (final c in ServiceCategories.all) DropdownMenuItem(value: c, child: Text(c))],
              onChanged: (v) => setState(() => _category = v ?? _category),
            ),
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
              Expanded(child: AppTextField(label: 'Unit label', controller: _unit, hint: 'hour, session…')),
              const SizedBox(width: 12),
              Expanded(child: AppTextField(label: 'Max qty', controller: _max, keyboardType: TextInputType.number, validator: (v) => intError(v, 'Max qty'))),
            ]),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Active (available to customers)'), value: _active, onChanged: (v) => setState(() => _active = v)),
          ]),
        ),
      );
}
