import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/app/theme/app_radius.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

Future<void> toggleWishlist(WidgetRef ref, String packageId) async {
  final s = ref.read(sessionProvider);
  if (s == null || s.isAdmin) return;
  await ref.read(wishlistServiceProvider).toggle(s.userId, packageId);
}

class WishlistButton extends ConsumerWidget {
  const WishlistButton({super.key, required this.packageId, this.onSurface = true});
  final String packageId;
  final bool onSurface;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(wishlistIdsProvider.select((a) => a.value?.contains(packageId) ?? false));
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => toggleWishlist(ref, packageId),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(fav ? Icons.favorite : Icons.favorite_border, size: 20, color: fav ? AppColors.danger : Colors.black54),
        ),
      ),
    );
  }
}

class PackageCard extends StatelessWidget {
  const PackageCard({super.key, required this.pkg});
  final Package pkg;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/packages/${pkg.id}'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Stack(children: [
            MockImage(imageKey: pkg.imageKey, height: 128, width: double.infinity, iconSize: 44),
            if (pkg.isFeatured) const Positioned(top: 10, left: 10, child: Pill('Featured', color: AppColors.warning, icon: Icons.star_rounded)),
            Positioned(top: 8, right: 8, child: WishlistButton(packageId: pkg.id)),
          ]),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pkg.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.title),
              const SizedBox(height: 2),
              Text('${pkg.serviceIds.length} services included', style: context.small),
              const SizedBox(height: 8),
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                Text(Fmt.money(pkg.price), style: context.title.copyWith(color: AppColors.primary)),
                if (pkg.hasPromo) Text(Fmt.money(pkg.basePrice), style: context.small.copyWith(decoration: TextDecoration.lineThrough)),
              ]),
            ]),
          ),
        ]),
      ),
    );
  }
}

class PackageTileSmall extends StatelessWidget {
  const PackageTileSmall({super.key, required this.pkg, this.trailing});
  final Package pkg;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => AppCard(
        padding: const EdgeInsets.all(10),
        onTap: () => context.push('/packages/${pkg.id}'),
        child: Row(children: [
          MockImage(imageKey: pkg.imageKey, height: 64, width: 64, radius: AppRadius.md, iconSize: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(pkg.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.title),
              Text('${pkg.serviceIds.length} services', style: context.small),
              Text(Fmt.money(pkg.price), style: context.titleSm.copyWith(color: AppColors.primary)),
            ]),
          ),
          if (trailing != null) trailing!,
        ]),
      );
}
