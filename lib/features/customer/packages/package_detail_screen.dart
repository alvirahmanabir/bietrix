import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/features/common/queries.dart';
import 'package:jamcon/features/customer/booking/booking_draft.dart';
import 'package:jamcon/features/customer/packages/package_card.dart';
import 'package:jamcon/features/customer/packages/recently_viewed.dart';

class PackageDetailScreen extends ConsumerStatefulWidget {
  const PackageDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<PackageDetailScreen> createState() => _PackageDetailScreenState();
}

class _PackageDetailScreenState extends ConsumerState<PackageDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recentlyViewedProvider.notifier).add(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(packageByIdProvider(widget.id));
    final services = ref.watch(servicesProvider).value ?? const <Service>[];
    return Scaffold(
      body: AsyncValueView<Package?>(
        value: async,
        loading: Scaffold(appBar: AppBar(), body: const ListSkeleton(count: 4, itemHeight: 90)),
        data: (p) {
          if (p == null) {
            return Scaffold(appBar: AppBar(), body: const EmptyState(icon: Icons.inventory_2_outlined, title: 'Package not found', message: 'It may have been removed.'));
          }
          final included = [for (final id in p.serviceIds) ...services.where((s) => s.id == id)];
          return Scaffold(
            body: CustomScrollView(slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(background: MockImage(imageKey: p.imageKey, iconSize: 80)),
                actions: [Padding(padding: const EdgeInsets.only(right: 12), child: WishlistButton(packageId: p.id))],
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                sliver: SliverList.list(children: [
                  Wrap(spacing: 8, children: [
                    if (p.isFeatured) const Pill('Featured', color: AppColors.warning, icon: Icons.star_rounded),
                    if (p.hasPromo) Pill('Save ${Fmt.money(p.basePrice - p.price)}', color: AppColors.success),
                    if (!p.isActive) const Pill('Unavailable', color: AppColors.danger),
                  ]),
                  const SizedBox(height: 10),
                  Text(p.name, style: context.hLg),
                  const SizedBox(height: 6),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(Fmt.money(p.price), style: context.hMd.copyWith(color: AppColors.primary)),
                    const SizedBox(width: 8),
                    if (p.hasPromo) Text(Fmt.money(p.basePrice), style: context.body.copyWith(decoration: TextDecoration.lineThrough, color: context.muted)),
                  ]),
                  const SizedBox(height: 16),
                  Text(p.description, style: context.body.copyWith(height: 1.55)),
                  const SizedBox(height: 24),
                  Text("What's included", style: context.titleLg),
                  const SizedBox(height: 10),
                  for (final s in included)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        padding: const EdgeInsets.all(12),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Icon(Icons.check_circle, color: AppColors.success, size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.name, style: context.title),
                            const SizedBox(height: 2),
                            Text(s.description, style: context.small),
                          ])),
                        ]),
                      ),
                    ),
                ]),
              ),
            ]),
            bottomNavigationBar: SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                decoration: BoxDecoration(color: context.surface, border: Border(top: BorderSide(color: context.border))),
                child: Row(children: [
                  Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Package price', style: context.small),
                    Text(Fmt.money(p.price), style: context.titleLg.copyWith(color: AppColors.primary)),
                  ]),
                  const SizedBox(width: 20),
                  Expanded(
                    child: AppButton(
                      label: p.isActive ? 'Book now' : 'Unavailable',
                      icon: Icons.event_available,
                      onPressed: p.isActive
                          ? () {
                              ref.read(bookingDraftProvider.notifier).startWithPackage(p.id);
                              context.push('/book');
                            }
                          : null,
                    ),
                  ),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
