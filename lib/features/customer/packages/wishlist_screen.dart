import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/features/common/queries.dart';
import 'package:jamcon/features/customer/booking/booking_draft.dart';
import 'package:jamcon/features/customer/packages/package_card.dart';

class WishlistScreen extends ConsumerWidget {
  const WishlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ids = ref.watch(wishlistIdsProvider);
    final pkgs = ref.watch(packagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('My Wishlist')),
      body: AsyncValueView<List<String>>(
        value: ids,
        data: (idList) => AsyncValueView<List<Package>>(
          value: pkgs,
          data: (all) {
            final saved = [for (final id in idList) ...all.where((p) => p.id == id)];
            if (saved.isEmpty) {
              return EmptyState(
                icon: Icons.favorite_border,
                title: 'No saved packages yet',
                message: 'Tap the heart on any package to save it here.',
                actionLabel: 'Browse packages',
                onAction: () => context.go('/packages'),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: saved.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final p = saved[i];
                return PackageTileSmall(
                  pkg: p,
                  trailing: Column(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Remove from wishlist',
                      icon: const Icon(Icons.favorite, color: AppColors.danger),
                      onPressed: () => toggleWishlist(ref, p.id),
                    ),
                    if (p.isActive)
                      TextButton(
                        onPressed: () {
                          ref.read(bookingDraftProvider.notifier).startWithPackage(p.id);
                          context.push('/book');
                        },
                        child: const Text('Book'),
                      )
                    else
                      const Pill('Unavailable', color: AppColors.danger),
                  ]),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
