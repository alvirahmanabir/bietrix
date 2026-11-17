import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/app/theme/app_radius.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/catalog.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/revenue.dart';
import 'package:jamcon/domain/rules/permissions.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';

/// Shows [child] only when the signed-in admin's role has [permission].
class Can extends ConsumerWidget {
  const Can(this.permission, {super.key, required this.child, this.fallback = const SizedBox.shrink()});
  final Permission permission;
  final Widget child;
  final Widget fallback;
  @override
  Widget build(BuildContext context, WidgetRef ref) => (ref.watch(sessionProvider)?.can(permission) ?? false) ? child : fallback;
}

class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.title, this.subtitle, this.actions = const [], required this.child});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final head = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: context.hLg),
      if (subtitle != null) Text(subtitle!, style: context.body.copyWith(color: context.muted)),
    ]);
    return SingleChildScrollView(
      padding: EdgeInsets.all(context.isTablet ? 28 : 16),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (context.isTablet)
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: head), Wrap(spacing: 10, children: actions)])
            else ...[head, if (actions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 12), child: Wrap(spacing: 10, runSpacing: 8, children: actions))],
            const SizedBox(height: 20),
            child,
          ]),
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon, required this.color, this.sub});
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? sub;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: context.small, maxLines: 1, overflow: TextOverflow.ellipsis),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: context.hMd)),
              if (sub != null) Text(sub!, style: context.small, maxLines: 1, overflow: TextOverflow.ellipsis),
            ]),
          ),
        ]),
      );
}

/// Responsive grid of fixed-column tiles without needing fixed heights.
class TileGrid extends StatelessWidget {
  const TileGrid({super.key, required this.children, this.minTileWidth = 240});
  final List<Widget> children;
  final double minTileWidth;
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final cols = max(1, min(children.length, (c.maxWidth / minTileWidth).floor()));
        final w = (c.maxWidth - (cols - 1) * 12) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [for (final ch in children) SizedBox(width: w, child: ch)]);
      });
}

class TwoCol extends StatelessWidget {
  const TwoCol({super.key, required this.left, required this.right, this.leftFlex = 3, this.rightFlex = 2});
  final Widget left;
  final Widget right;
  final int leftFlex;
  final int rightFlex;
  @override
  Widget build(BuildContext context) => context.isWide
      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: leftFlex, child: left), const SizedBox(width: 16), Expanded(flex: rightFlex, child: right)])
      : Column(children: [left, const SizedBox(height: 16), right]);
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.title, required this.child, this.trailing});
  final String title;
  final Widget child;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(title, style: context.titleLg)), if (trailing != null) trailing!]),
          const SizedBox(height: 14),
          child,
        ]),
      );
}

/// Stacked bar chart (completed + confirmed revenue) without external chart packages.
class BarChartLite extends StatelessWidget {
  const BarChartLite({super.key, required this.points, required this.label, this.height = 210});
  final List<RevenuePoint> points;
  final String Function(DateTime) label;
  final double height;

  @override
  Widget build(BuildContext context) {
    final maxV = points.fold<int>(0, (m, p) => max(m, p.realized + p.booked));
    if (maxV == 0) return SizedBox(height: 120, child: Center(child: Text('No revenue in this period', style: context.small)));
    return SizedBox(
      height: height,
      child: LayoutBuilder(builder: (context, c) {
        final plotH = c.maxHeight - 24;
        return Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final p in points)
            Expanded(
              child: Tooltip(
                message: '${label(p.date)}\nCompleted: ${Fmt.money(p.realized)}\nConfirmed: ${Fmt.money(p.booked)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                    Container(height: plotH * p.booked / maxV, color: AppColors.primary.withValues(alpha: 0.32)),
                    Container(
                      height: plotH * p.realized / maxV,
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: p.booked == 0 ? const BorderRadius.vertical(top: Radius.circular(4)) : null),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(height: 18, child: FittedBox(child: Text(label(p.date), style: context.small))),
                  ]),
                ),
              ),
            ),
        ]);
      }),
    );
  }
}

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});
  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))), const SizedBox(width: 6), Text(t, style: context.small)]);
    return Wrap(spacing: 16, children: [dot(AppColors.primary, 'Completed'), dot(AppColors.primary.withValues(alpha: 0.32), 'Confirmed (upcoming)')]);
  }
}

class HBarList extends StatelessWidget {
  const HBarList({super.key, required this.data, this.money = true, this.max = 6, this.color = AppColors.primary});
  final Map<String, int> data;
  final bool money;
  final int max;
  final Color color;
  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return Text('No data yet', style: context.small);
    final entries = data.entries.take(max).toList();
    final top = entries.fold<int>(1, (m, e) => e.value > m ? e.value : m);
    return Column(children: [
      for (final e in entries)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(children: [
            Row(children: [
              Expanded(child: Text(e.key, style: context.body.copyWith(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
              Text(money ? Fmt.money(e.value) : '${e.value}', style: context.body.copyWith(fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 6),
            ClipRRect(borderRadius: BorderRadius.circular(6), child: LinearProgressIndicator(value: e.value / top, minHeight: 8, color: color, backgroundColor: context.border)),
          ]),
        ),
    ]);
  }
}

class AdminTable extends StatelessWidget {
  const AdminTable({super.key, required this.columns, required this.rows});
  final List<String> columns;
  final List<DataRow> rows;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, c) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: DataTable(
                  headingRowHeight: 46,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 72,
                  columnSpacing: 28,
                  horizontalMargin: 18,
                  columns: [for (final c in columns) DataColumn(label: Text(c, style: context.label))],
                  rows: rows,
                ),
              ),
            )),
      );
}

class ImageKeyPicker extends StatelessWidget {
  const ImageKeyPicker({super.key, required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final k in ImageKeys.all)
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => onChanged(k),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(AppRadius.md + 2), border: Border.all(color: value == k ? AppColors.primary : Colors.transparent, width: 2)),
              child: MockImage(imageKey: k, height: 48, width: 48, radius: AppRadius.md, iconSize: 22),
            ),
          ),
      ]);
}

/// Chrome for admin create/edit dialogs. [onSave] throws on failure; success closes the dialog.
class AdminFormDialog extends StatefulWidget {
  const AdminFormDialog({super.key, required this.title, required this.child, required this.onSave, this.saveLabel = 'Save'});
  final String title;
  final Widget child;
  final Future<void> Function() onSave;
  final String saveLabel;
  @override
  State<AdminFormDialog> createState() => _AdminFormDialogState();
}

class _AdminFormDialogState extends State<AdminFormDialog> {
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.onSave();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(padding: const EdgeInsets.fromLTRB(24, 20, 12, 8), child: Row(children: [Expanded(child: Text(widget.title, style: context.titleLg)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
            const Divider(),
            Flexible(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: widget.child)),
            const Divider(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                AppButton(label: widget.saveLabel, expand: false, loading: _busy, onPressed: _save),
              ]),
            ),
          ]),
        ),
      );
}

String? intError(String? v, String field, {bool allowZero = false, bool optional = false}) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return optional ? null : '$field is required';
  final n = int.tryParse(s);
  if (n == null || n < 0 || (!allowZero && n == 0)) return 'Enter a valid number';
  return null;
}

Widget activePill(bool active) => Pill(active ? 'Active' : 'Inactive', color: active ? AppColors.success : AppColors.textSecondaryLight);

Widget thumbName(BuildContext context, String imageKey, String name, {String? sub}) => Row(mainAxisSize: MainAxisSize.min, children: [
      MockImage(imageKey: imageKey, height: 40, width: 40, radius: AppRadius.sm, iconSize: 18),
      const SizedBox(width: 10),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: context.titleSm, overflow: TextOverflow.ellipsis),
          if (sub != null) Text(sub, style: context.small, overflow: TextOverflow.ellipsis),
        ]),
      ),
    ]);

extension SupportColor on SupportStatus {
  Color get color => switch (this) { SupportStatus.pending => AppColors.warning, SupportStatus.inProgress => AppColors.info, SupportStatus.resolved => AppColors.success };
}
