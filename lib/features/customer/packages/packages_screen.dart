import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/app/theme/app_radius.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/features/common/queries.dart';
import 'package:jamcon/features/customer/packages/package_card.dart';

enum _PkgFilter { all, featured, offers }

class PackagesScreen extends ConsumerStatefulWidget {
  const PackagesScreen({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  ConsumerState<PackagesScreen> createState() => _PackagesScreenState();
}

class _PackagesScreenState extends ConsumerState<PackagesScreen> {
  late final TextEditingController _search = TextEditingController(text: widget.initialQuery);
  _PkgFilter _filter = _PkgFilter.all;

  @override
  void didUpdateWidget(covariant PackagesScreen old) {
    super.didUpdateWidget(old);
    if (old.initialQuery != widget.initialQuery) _search.text = widget.initialQuery;
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Package> _apply(List<Package> all) {
    final q = _search.text.trim().toLowerCase();
    return all.where((p) {
      if (_filter == _PkgFilter.featured && !p.isFeatured) return false;
      if (_filter == _PkgFilter.offers && !p.hasPromo) return false;
      return q.isEmpty || p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final pkgs = ref.watch(activePackagesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Studio Packages')),
      body: AsyncValueView<List<Package>>(
        value: pkgs,
        data: (all) {
          final list = _apply(all);
          return CustomScrollView(slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search packages',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty ? null : IconButton(icon: const Icon(Icons.close), onPressed: () => setState(_search.clear)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, children: [
                    for (final f in _PkgFilter.values)
                      ChoiceChip(
                        label: Text(switch (f) { _PkgFilter.all => 'All', _PkgFilter.featured => 'Featured', _PkgFilter.offers => 'On offer' }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ]),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    onTap: () => context.push('/builder'),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(AppRadius.lg)),
                      child: Row(children: [
                        const Icon(Icons.tune, color: AppColors.primaryDark),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Need something different? Build your own package.', style: context.titleSm.copyWith(color: AppColors.primaryDark))),
                        const Icon(Icons.chevron_right, color: AppColors.primaryDark),
                      ]),
                    ),
                  ),
                ]),
              ),
            ),
            if (list.isEmpty)
              const SliverFillRemaining(hasScrollBody: false, child: EmptyState(icon: Icons.search_off, title: 'No packages found', message: 'Try a different search or filter.'))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 246, crossAxisSpacing: 12, mainAxisSpacing: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => PackageCard(pkg: list[i]),
                ),
              ),
          ]);
        },
        loading: const _GridSkeleton(),
      ),
    );
  }
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) => GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 260, mainAxisExtent: 246, crossAxisSpacing: 12, mainAxisSpacing: 12),
        itemCount: 6,
        itemBuilder: (_, __) => const Skeleton(height: 246, radius: AppRadius.lg),
      );
}
