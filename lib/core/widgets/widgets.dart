import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/app/theme/app_radius.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';

export 'mock_image.dart';

// ───────── Buttons ─────────
enum AppButtonVariant { primary, secondary, ghost, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = AppButtonVariant.primary,
    this.loading = false,
    this.expand = true,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final AppButtonVariant variant;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final onDark = variant == AppButtonVariant.primary || variant == AppButtonVariant.danger;
    final child = loading
        ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: onDark ? Colors.white : AppColors.primary))
        : Row(mainAxisSize: MainAxisSize.min, mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis, maxLines: 1)),
          ]);
    final tap = loading ? null : onPressed;
    final Widget b = switch (variant) {
      AppButtonVariant.primary => FilledButton(onPressed: tap, child: child),
      AppButtonVariant.secondary => OutlinedButton(onPressed: tap, child: child),
      AppButtonVariant.ghost => TextButton(onPressed: tap, child: child),
      AppButtonVariant.danger => FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.danger), onPressed: tap, child: child),
    };
    return expand ? SizedBox(width: double.infinity, child: b) : b;
  }
}

// ───────── Inputs ─────────
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.initialValue,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscure = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.prefixIcon,
    this.onChanged,
    this.textInputAction,
    this.helper,
    this.inputFormatters,
    this.onSubmitted,
    this.autofocus = false,
    this.maxLength,
  });
  final String label;
  final TextEditingController? controller;
  final String? initialValue;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool readOnly;
  final int maxLines;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final String? helper;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final int? maxLength;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.label, style: context.label),
      const SizedBox(height: 6),
      TextFormField(
        controller: widget.controller,
        initialValue: widget.controller == null ? widget.initialValue : null,
        validator: widget.validator,
        keyboardType: widget.keyboardType,
        obscureText: _hidden,
        readOnly: widget.readOnly,
        maxLines: widget.obscure ? 1 : widget.maxLines,
        onChanged: widget.onChanged,
        onFieldSubmitted: widget.onSubmitted,
        textInputAction: widget.textInputAction,
        inputFormatters: widget.inputFormatters,
        autofocus: widget.autofocus,
        maxLength: widget.maxLength,
        decoration: InputDecoration(
          hintText: widget.hint,
          helperText: widget.helper,
          counterText: '',
          filled: true,
          fillColor: widget.readOnly ? context.border.withValues(alpha: 0.4) : null,
          prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon, size: 20),
          suffixIcon: widget.obscure
              ? IconButton(
                  icon: Icon(_hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                  onPressed: () => setState(() => _hidden = !_hidden),
                )
              : (widget.readOnly ? const Icon(Icons.lock_outline, size: 18) : null),
        ),
      ),
    ]);
  }
}

// ───────── Badges ─────────
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.13), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 4)],
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

Color statusColor(BookingStatus s) => switch (s) {
      BookingStatus.pendingConfirmation => AppColors.warning,
      BookingStatus.confirmed => AppColors.info,
      BookingStatus.completed => AppColors.success,
      BookingStatus.cancelledByCustomer => const Color(0xFFEA580C),
      BookingStatus.cancelledByAdmin => AppColors.danger,
    };

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.status, {super.key});
  final BookingStatus status;
  @override
  Widget build(BuildContext context) => Pill(status.label, color: statusColor(status));
}

// ───────── Layout helpers ─────────
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: Text(title, style: context.titleLg)),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ]);
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.bold = false, this.valueColor});
  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: 2, child: Text(label, style: context.body.copyWith(color: context.muted))),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(value,
                textAlign: TextAlign.end, style: (bold ? context.title : context.body.copyWith(fontWeight: FontWeight.w600)).copyWith(color: valueColor)),
          ),
        ]),
      );
}

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap});
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class SelectableTile extends StatelessWidget {
  const SelectableTile({super.key, required this.selected, required this.onTap, required this.icon, required this.title, this.subtitle});
  final bool selected;
  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : context.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: selected ? AppColors.primary : context.border, width: selected ? 1.6 : 1),
        ),
        child: Row(children: [
          Icon(icon, color: selected ? AppColors.primary : context.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: context.title),
              if (subtitle != null) Text(subtitle!, style: context.small),
            ]),
          ),
          Icon(selected ? Icons.check_circle : Icons.circle_outlined, color: selected ? AppColors.primary : context.muted),
        ]),
      ),
    );
  }
}

class QtyStepper extends StatelessWidget {
  const QtyStepper({super.key, required this.value, required this.max, required this.onChanged, this.min = 0});
  final int value;
  final int max;
  final int min;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, VoidCallback? f) => SizedBox(
          width: 34,
          height: 34,
          child: IconButton.filledTonal(padding: EdgeInsets.zero, iconSize: 18, onPressed: f, icon: Icon(i)),
        );
    return Row(mainAxisSize: MainAxisSize.min, children: [
      btn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
      SizedBox(width: 34, child: Text('$value', textAlign: TextAlign.center, style: context.title)),
      btn(Icons.add, value < max ? () => onChanged(value + 1) : null),
    ]);
  }
}

class PriceSummary extends StatelessWidget {
  const PriceSummary({super.key, required this.pricing, this.couponCode, this.totalLabel = 'Total payable'});
  final Pricing pricing;
  final String? couponCode;
  final String totalLabel;
  @override
  Widget build(BuildContext context) => Column(children: [
        InfoRow('Original price', Fmt.money(pricing.subtotal)),
        InfoRow(couponCode == null ? 'Discount' : 'Discount ($couponCode)', pricing.discount > 0 ? '-${Fmt.money(pricing.discount)}' : Fmt.money(0),
            valueColor: pricing.discount > 0 ? AppColors.success : null),
        const Divider(height: 18),
        InfoRow(totalLabel, Fmt.money(pricing.total), bold: true, valueColor: AppColors.primary),
      ]);
}

// ───────── States ─────────
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(title, style: context.titleLg, textAlign: TextAlign.center),
            if (message != null) ...[const SizedBox(height: 6), Text(message!, style: context.body.copyWith(color: context.muted), textAlign: TextAlign.center)],
            if (actionLabel != null) ...[const SizedBox(height: 18), AppButton(label: actionLabel!, onPressed: onAction, expand: false)],
          ]),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        message: ErrorHandler.message(error),
        actionLabel: onRetry == null ? null : 'Try again',
        onAction: onRetry,
      );
}

class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.height = 16, this.width, this.radius = 8});
  final double height;
  final double? width;
  final double radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 0.9).animate(_c),
        child: Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(color: context.border, borderRadius: BorderRadius.circular(widget.radius)),
        ),
      );
}

class ListSkeleton extends StatelessWidget {
  const ListSkeleton({super.key, this.count = 5, this.itemHeight = 84});
  final int count;
  final double itemHeight;
  @override
  Widget build(BuildContext context) => ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: count,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, __) => Skeleton(height: itemHeight, radius: AppRadius.lg),
      );
}

class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({super.key, required this.value, required this.data, this.loading});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => loading ?? const ListSkeleton(),
        error: (e, _) => ErrorView(error: e),
      );
}

// ───────── Dialogs ─────────
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelLabel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

typedef ReasonResult = ({bool ok, String reason});

Future<ReasonResult> reasonDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String hint = 'Reason (optional)',
  String cancelLabel = 'Go back',
}) async {
  final r = await showDialog<ReasonResult>(
    context: context,
    builder: (_) => _ReasonDialog(title: title, message: message, confirmLabel: confirmLabel, hint: hint, cancelLabel: cancelLabel),
  );
  return r ?? (ok: false, reason: '');
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({required this.title, required this.message, required this.confirmLabel, required this.hint, required this.cancelLabel});
  final String title;
  final String message;
  final String confirmLabel;
  final String hint;
  final String cancelLabel;
  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.message),
          const SizedBox(height: 14),
          TextField(controller: _c, maxLines: 3, decoration: InputDecoration(hintText: widget.hint)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, (ok: false, reason: '')), child: Text(widget.cancelLabel)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, (ok: true, reason: _c.text.trim())),
            child: Text(widget.confirmLabel),
          ),
        ],
      );
}

Future<void> copyToClipboard(BuildContext context, String text, String message) async {
  await Clipboard.setData(ClipboardData(text: text));
  if (context.mounted) ErrorHandler.success(context, message);
}
