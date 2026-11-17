import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/models/support.dart';
import 'package:jamcon/features/admin/widgets/admin_widgets.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/queries.dart';

class AdminSupportScreen extends ConsumerStatefulWidget {
  const AdminSupportScreen({super.key});
  @override
  ConsumerState<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends ConsumerState<AdminSupportScreen> {
  SupportCategory? _category;
  SupportStatus? _status;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(supportRequestsProvider((category: _category, status: _status)));
    return AdminPage(
      title: 'Support requests',
      subtitle: 'Inquiries submitted from the customer app.',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<SupportCategory?>(
              initialValue: _category,
              isExpanded: true,
              items: [const DropdownMenuItem<SupportCategory?>(value: null, child: Text('All categories')), for (final c in SupportCategory.values) DropdownMenuItem<SupportCategory?>(value: c, child: Text(c.label))],
              onChanged: (v) => setState(() => _category = v),
            ),
          ),
          for (final s in [null, ...SupportStatus.values]) ChoiceChip(label: Text(s?.label ?? 'All'), selected: _status == s, onSelected: (_) => setState(() => _status = s)),
        ]),
        const SizedBox(height: 16),
        AsyncValueView<List<SupportRequest>>(
          value: async,
          loading: const SizedBox(height: 300, child: ListSkeleton(count: 4, itemHeight: 56)),
          data: (list) {
            if (list.isEmpty) return const EmptyState(icon: Icons.inbox_outlined, title: 'No requests found');
            return AdminTable(
              columns: const ['Subject', 'Customer', 'Category', 'Received', 'Status', ''],
              rows: [
                for (final r in list)
                  DataRow(onSelectChanged: (_) => showDialog<void>(context: context, builder: (_) => SupportDetailDialog(id: r.id)), cells: [
                    DataCell(ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Text(r.subject, style: context.titleSm, overflow: TextOverflow.ellipsis))),
                    DataCell(Text(r.name)),
                    DataCell(Text(r.category.label)),
                    DataCell(Text(Fmt.dateTime(r.createdAt))),
                    DataCell(Pill(r.status.label, color: r.status.color)),
                    DataCell(TextButton(onPressed: () => showDialog<void>(context: context, builder: (_) => SupportDetailDialog(id: r.id)), child: const Text('Open'))),
                  ]),
              ],
            );
          },
        ),
      ]),
    );
  }
}

class SupportDetailDialog extends ConsumerStatefulWidget {
  const SupportDetailDialog({super.key, required this.id});
  final String id;
  @override
  ConsumerState<SupportDetailDialog> createState() => _SupportDetailDialogState();
}

class _SupportDetailDialogState extends ConsumerState<SupportDetailDialog> {
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _run(Future<SupportRequest> Function() job, {String? ok}) async {
    setState(() => _busy = true);
    try {
      await job();
      if (ok != null && mounted) ErrorHandler.success(context, ok);
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(supportRequestsProvider((category: null, status: null))).value ?? const <SupportRequest>[];
    final r = all.where((x) => x.id == widget.id).firstOrNull;
    final session = ref.watch(sessionProvider)!;
    final svc = ref.read(supportServiceProvider);
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 760),
        child: r == null
            ? const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
            : Column(mainAxisSize: MainAxisSize.min, children: [
                Padding(padding: const EdgeInsets.fromLTRB(24, 16, 8, 8), child: Row(children: [Expanded(child: Text(r.subject, style: context.titleLg)), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))])),
                const Divider(),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      InfoRow('Request ID', r.id),
                      InfoRow('Category', r.category.label),
                      InfoRow('Customer', r.name),
                      InfoRow('Email', r.email),
                      InfoRow('Phone', r.phone),
                      InfoRow('Received', Fmt.dateTime(r.createdAt)),
                      const SizedBox(height: 12),
                      Text('Message', style: context.label),
                      const SizedBox(height: 6),
                      Container(width: double.infinity, padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: context.border.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(12)), child: Text(r.message)),
                      const SizedBox(height: 18),
                      Text('Status', style: context.label),
                      const SizedBox(height: 6),
                      SegmentedButton<SupportStatus>(
                        segments: [for (final s in SupportStatus.values) ButtonSegment(value: s, label: Text(s.label))],
                        selected: {r.status},
                        onSelectionChanged: _busy ? null : (s) => _run(() => svc.updateStatus(r.id, s.first, session), ok: 'Status updated'),
                      ),
                      const SizedBox(height: 18),
                      Text('Internal notes (not visible to customer)', style: context.label),
                      const SizedBox(height: 6),
                      if (r.notes.isEmpty) Text('No notes yet.', style: context.small),
                      for (final n in r.notes) Padding(padding: const EdgeInsets.only(bottom: 6), child: Text('• $n', style: context.body)),
                      const SizedBox(height: 8),
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: TextField(controller: _note, minLines: 1, maxLines: 3, decoration: const InputDecoration(hintText: 'Add an internal note'))),
                        const SizedBox(width: 10),
                        AppButton(
                          label: 'Add',
                          expand: false,
                          loading: _busy,
                          onPressed: () async {
                            final text = _note.text;
                            await _run(() => svc.addNote(r.id, text, session));
                            if (mounted && text.trim().isNotEmpty) _note.clear();
                          },
                        ),
                      ]),
                    ]),
                  ),
                ),
              ]),
      ),
    );
  }
}
