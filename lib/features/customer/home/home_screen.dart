import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/config/env.dart';
import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/app/theme/app_radius.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/models/coupon.dart';
import 'package:jamcon/features/auth/presentation/auth_screens.dart';
import 'package:jamcon/features/common/queries.dart';
import 'package:jamcon/features/customer/booking/booking_draft.dart';
import 'package:jamcon/features/customer/packages/package_card.dart';
import 'package:jamcon/features/customer/packages/recently_viewed.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});
  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider).value;
    final pkgs = ref.watch(activePackagesProvider);
    final svcs = ref.watch(activeServicesProvider).value ?? const <Service>[];
    final coupons = ref.watch(availableCouponsProvider).value ?? const <Coupon>[];
    final draft = ref.watch(bookingDraftProvider);
    final recent = ref.watch(recentlyViewedProvider);
    final favIds = ref.watch(wishlistIdsProvider).value ?? const <String>[];
    final all = pkgs.value ?? const <Package>[];
    final featured = all.where((p) => p.isFeatured).toList();
    final recentPkgs = [for (final id in recent) ...all.where((p) => p.id == id)];
    final favPkgs = [for (final id in favIds) ...all.where((p) => p.id == id)];
    final firstName = (user?.name ?? 'there').split(' ').first;

    return Scaffold(
      body: SafeArea(
        child: pkgs.isLoading && all.isEmpty
            ? const ListSkeleton(count: 4, itemHeight: 120)
            : ListView(padding: const EdgeInsets.only(bottom: 24), children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 12, 4),
                  child: Row(children: [
                    const BrandMark(size: 44),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Hello, $firstName 👋', style: context.titleLg),
                        Text('Welcome to ${Env.appName}', style: context.small),
                      ]),
                    ),
                    IconButton(tooltip: 'Wishlist', onPressed: () => context.push('/wishlist'), icon: const Icon(Icons.favorite_border)),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (v) => context.go('/packages?q=${Uri.encodeQueryComponent(v.trim())}'),
                    decoration: InputDecoration(
                      hintText: 'Search packages (e.g. wedding, portrait)',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(icon: const Icon(Icons.arrow_forward), onPressed: () => context.go('/packages?q=${Uri.encodeQueryComponent(_search.text.trim())}')),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _Banners(packages: all, coupons: coupons),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: _QuickBooking(resume: draft.hasSelection && ref.watch(draftSummaryProvider) != null),
                ),
                const SizedBox(height: 24),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHeader('Featured packages', action: 'See all', onAction: () => context.go('/packages'))),
                const SizedBox(height: 8),
                if (featured.isEmpty)
                  const Padding(padding: EdgeInsets.all(20), child: Text('No featured packages right now.'))
                else
                  SizedBox(
                    height: 262,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      itemCount: featured.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(width: 220, child: PackageCard(pkg: featured[i])),
                    ),
                  ),
                if (svcs.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHeader('Popular services', action: 'Build package', onAction: () => context.push('/builder'))),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 108,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: svcs.length > 8 ? 8 : svcs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => _ServiceChip(service: svcs[i]),
                    ),
                  ),
                ],
                if (coupons.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: SectionHeader('Available coupons')),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 150,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: coupons.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (_, i) => SizedBox(width: 250, child: CouponTile(coupon: coupons[i])),
                    ),
                  ),
                ],
                if (recentPkgs.isNotEmpty) ..._miniSection(context, 'Recently viewed', recentPkgs)
                else if (favPkgs.isNotEmpty) ..._miniSection(context, 'Your favorites', favPkgs),
              ]),
      ),
    );
  }

  List<Widget> _miniSection(BuildContext context, String title, List<Package> list) => [
        const SizedBox(height: 20),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: SectionHeader(title)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [for (final p in list.take(3)) Padding(padding: const EdgeInsets.only(bottom: 8), child: PackageTileSmall(pkg: p))]),
        ),
      ];
}

class _QuickBooking extends StatelessWidget {
  const _QuickBooking({required this.resume});
  final bool resume;
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => context.push('/book'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryDark]),
          ),
          child: Row(children: [
            const Icon(Icons.bolt_rounded, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(resume ? 'Resume your booking' : 'Quick booking', style: context.title.copyWith(color: Colors.white)),
                Text(resume ? 'Pick up where you left off' : 'Choose a date and book in minutes', style: context.small.copyWith(color: Colors.white70)),
              ]),
            ),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white),
          ]),
        ),
      );
}

class _ServiceChip extends StatelessWidget {
  const _ServiceChip({required this.service});
  final Service service;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 96,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: () => context.push('/builder'),
          child: Column(children: [
            MockImage(imageKey: service.imageKey, height: 64, width: 64, radius: AppRadius.lg, iconSize: 28),
            const SizedBox(height: 6),
            Text(service.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: context.small.copyWith(fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}


class CouponTile extends StatelessWidget {
  const CouponTile({
    super.key,
    required this.coupon,
    this.onApply,
  });

  final Coupon coupon;
  final VoidCallback? onApply;

  @override
  Widget build(BuildContext context) => AppCard(
        onTap: onApply ??
            () => copyToClipboard(
                  context,
                  coupon.code,
                  'Code ${coupon.code} copied',
                ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(
                Icons.local_offer_outlined,
                color: AppColors.secondary,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${coupon.code} · ${coupon.valueLabel}',
                    style: context.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    coupon.description,
                    style: context.small,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    onApply != null
                        ? 'Tap to apply'
                        : 'Tap to copy · valid till ${Fmt.date(coupon.expiresAt)}',
                    style: context.small.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _Banners extends StatefulWidget {
  const _Banners({required this.packages, required this.coupons});
  final List<Package> packages;
  final List<Coupon> coupons;
  @override
  State<_Banners> createState() => _BannersState();
}

class _BannersState extends State<_Banners> {
  final _c = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final banners = <({String title, String sub, List<Color> colors, VoidCallback onTap})>[];
    if (widget.coupons.isNotEmpty) {
      final c = widget.coupons.first;
      banners.add((title: 'Use code ${c.code}', sub: c.description, colors: const [AppColors.secondary, Color(0xFF9D174D)], onTap: () => copyToClipboard(context, c.code, 'Code ${c.code} copied')));
    }
    for (final p in widget.packages.where((p) => p.hasPromo).take(2)) {
      banners.add((title: 'Save ${Fmt.money(p.basePrice - p.price)} on ${p.name}', sub: 'Limited-time offer', colors: const [AppColors.primary, Color(0xFF4C1D95)], onTap: () => context.push('/packages/${p.id}')));
    }
    banners.add((title: 'Build your own package', sub: 'Pick only the services you need', colors: const [Color(0xFF0EA5E9), Color(0xFF4F46E5)], onTap: () => context.push('/builder')));

    return Column(children: [
      SizedBox(
        height: 136,
        child: PageView.builder(
          controller: _c,
          itemCount: banners.length,
          onPageChanged: (i) => setState(() => _page = i),
          itemBuilder: (_, i) {
            final b = banners[i];
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.xl),
                onTap: b.onTap,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.xl), gradient: LinearGradient(colors: b.colors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(b.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.titleLg.copyWith(color: Colors.white)),
                    const SizedBox(height: 4),
                    Text(b.sub, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.body.copyWith(color: Colors.white70)),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
      const SizedBox(height: 8),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 0; i < banners.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == _page ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(color: i == _page ? AppColors.primary : context.border, borderRadius: BorderRadius.circular(3)),
          ),
      ]),
    ]);
  }
}
