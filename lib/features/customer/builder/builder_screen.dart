import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/app/theme/app_radius.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/rules/pricing_engine.dart';
import 'package:jamcon/features/common/queries.dart';
import 'package:jamcon/features/customer/booking/booking_draft.dart';

/// Selected services for the custom package (serviceId -> qty).
class BuilderSelection extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() {
    final d = ref.read(bookingDraftProvider);
    return d.packageId == null ? Map.of(d.items) : {};
  }

  void setQty(String id, int qty) {
    final next = Map.of(state);
    if (qty <= 0) {
      next.remove(id);
    } else {
      next[id] = qty;
    }
    state = next;
  }

  void clear() => state = {};
}

final builderSelectionProvider = NotifierProvider<BuilderSelection, Map<String, int>>(BuilderSelection.new);

/// Price + items derived through the shared PricingEngine (no math in widgets).
final builderSummaryProvider = Provider<({List<BookingItem> items, int subtotal})>((ref) {
  final sel = ref.watch(builderSelectionProvider);
  final svcs = ref.watch(servicesProvider).value ?? const <Service>[];
  final items = PricingEngine.snapshot(sel, svcs);
  return (items: items, subtotal: PricingEngine.subtotalOf(items));
});

class CustomBuilderScreen extends ConsumerStatefulWidget {
  const CustomBuilderScreen({super.key});
  @override
  ConsumerState<CustomBuilderScreen> createState() => _CustomBuilderScreenState();
}

class _CustomBuilderScreenState extends ConsumerState<CustomBuilderScreen> {
  String _category = 'All';

  void _continue() {
    final sel = ref.read(builderSelectionProvider);
    ref.read(bookingDraftProvider.notifier).startCustom(sel);
    context.push('/book');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeServicesProvider);
    final sel = ref.watch(builderSelectionProvider);
    final summary = ref.watch(builderSummaryProvider);
    final count = summary.items.length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Build your package'),
        actions: [if (sel.isNotEmpty) TextButton(onPressed: () => ref.read(builderSelectionProvider.notifier).clear(), child: const Text('Clear'))],
      ),
      body: AsyncValueView<List<Service>>(
        value: async,
        data: (all) {
          final cats = ['All', ...{for (final s in all) s.category}];
          final list = _category == 'All' ? all : all.where((s) => s.category == _category).toList();
          return Column(children: [
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: cats.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => ChoiceChip(label: Text(cats[i]), selected: _category == cats[i], onSelected: (_) => setState(() => _category = cats[i])),
              ),
            ),
            Expanded(
              child: list.isEmpty
                  ? const EmptyState(icon: Icons.tune, title: 'No services here', message: 'Try another category.')
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) => _ServiceTile(service: list[i], qty: sel[list[i].id] ?? 0),
                    ),
            ),
          ]);
        },
      ),
      bottomNavigationBar: count == 0
          ? null
          : SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                decoration: BoxDecoration(color: context.surface, border: Border(top: BorderSide(color: context.border))),
                child: Row(children: [
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (_) => _SummarySheet(onContinue: _continue)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [Text('$count service${count == 1 ? '' : 's'} selected', style: context.small), const Icon(Icons.keyboard_arrow_up, size: 16)]),
                          Text(Fmt.money(summary.subtotal), style: context.titleLg.copyWith(color: AppColors.primary)),
                        ]),
                      ),
                    ),
                  ),
                  AppButton(label: 'Continue', icon: Icons.arrow_forward, expand: false, onPressed: _continue),
                ]),
              ),
            ),
    );
  }
}

class _ServiceTile extends ConsumerWidget {
  const _ServiceTile({required this.service, required this.qty});
  final Service service;
  final int qty;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = ref.read(builderSelectionProvider.notifier);
    final selected = qty > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: selected ? AppColors.primary : context.border, width: selected ? 1.6 : 1),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MockImage(imageKey: service.imageKey, height: 56, width: 56, radius: AppRadius.md, iconSize: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(service.name, style: context.title),
            const SizedBox(height: 2),
            Text(service.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.small),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Text('${Fmt.money(service.unitPrice)} / ${service.unitLabel}', style: context.titleSm.copyWith(color: AppColors.primary))),
              if (service.hasQuantity && selected)
                QtyStepper(value: qty, max: service.maxQty, onChanged: (v) => n.setQty(service.id, v))
              else
                selected
                    ? OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 12)),
                        onPressed: () => n.setQty(service.id, 0),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Added'),
                      )
                    : FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 36), padding: const EdgeInsets.symmetric(horizontal: 14)),
                        onPressed: () => n.setQty(service.id, 1),
                        child: const Text('Add'),
                      ),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _SummarySheet extends ConsumerWidget {
  const _SummarySheet({required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(builderSummaryProvider);
    final n = ref.read(builderSelectionProvider.notifier);
    final items = summary.items;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Your custom package', style: context.titleLg),
          const SizedBox(height: 12),
          if (items.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('No services selected'))),
          Flexible(
            child: ListView(shrinkWrap: true, children: [
              for (final i in items)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${i.name}${i.qty > 1 ? '  x${i.qty}' : ''}', style: context.title),
                  subtitle: Text('${Fmt.money(i.unitPrice)} / ${i.unitLabel}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(Fmt.money(i.lineTotal), style: context.title),
                    IconButton(tooltip: 'Remove', icon: const Icon(Icons.close, size: 20), onPressed: () => n.setQty(i.serviceId, 0)),
                  ]),
                ),
            ]),
          ),
          const Divider(),
          InfoRow('Total', Fmt.money(summary.subtotal), bold: true, valueColor: AppColors.primary),
          const SizedBox(height: 12),
          AppButton(
            label: 'Continue to booking',
            onPressed: items.isEmpty
                ? null
                : () {
                    Navigator.pop(context);
                    onContinue();
                  },
          ),
        ]),
      ),
    );
  }
}
