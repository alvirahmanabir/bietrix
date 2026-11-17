import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/data/providers.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/rules/booking_policy.dart';
import 'package:jamcon/features/auth/application/session_notifier.dart';
import 'package:jamcon/features/common/booking_details.dart';
import 'package:jamcon/features/common/queries.dart';

class OrderDetailScreen extends ConsumerStatefulWidget {
  const OrderDetailScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends ConsumerState<OrderDetailScreen> {
  bool _busy = false;

  Future<void> _cancel(Booking b) async {
    final r = await reasonDialog(
      context,
      title: 'Cancel this booking?',
      message: 'This cannot be undone. You can only cancel while the booking is pending confirmation.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep booking',
    );
    if (!r.ok || !mounted) return;
    setState(() => _busy = true);
    try {
      // The service enforces the cancellation rules; the UI check is only for convenience.
      await ref.read(bookingServiceProvider).cancelByCustomer(bookingId: b.id, customerId: ref.read(sessionProvider)!.userId, reason: r.reason);
      if (mounted) ErrorHandler.success(context, 'Booking cancelled');
    } catch (e) {
      if (mounted) ErrorHandler.show(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bookingByIdProvider(widget.id));
    return Scaffold(
      appBar: AppBar(title: const Text('Order details'), leading: BackButton(onPressed: () => context.canPop() ? context.pop() : context.go('/orders'))),
      body: AsyncValueView<Booking?>(
        value: async,
        data: (b) {
          if (b == null) return const EmptyState(icon: Icons.search_off, title: 'Order not found');
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  AppCard(
                    child: Column(children: [
                      InfoRow('Booking ID', b.code, bold: true, valueColor: AppColors.primary),
                      InfoRow('Booked on', '${b.createdAt.day}/${b.createdAt.month}/${b.createdAt.year}'),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Status', style: context.body.copyWith(color: context.muted)), StatusBadge(b.status)]),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  if (b.status == BookingStatus.confirmed)
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        const Icon(Icons.verified_outlined, color: AppColors.info),
                        const SizedBox(width: 12),
                        Expanded(child: Text('Your booking is confirmed. Confirmed bookings can only be changed or cancelled by the studio.', style: context.small)),
                        TextButton(onPressed: () => context.push('/contact'), child: const Text('Contact')),
                      ]),
                    ),
                  BookingDetailSections(booking: b),
                  if (BookingPolicy.canCustomerCancel(b)) ...[
                    const SizedBox(height: 4),
                    AppButton(label: 'Cancel booking', icon: Icons.cancel_outlined, variant: AppButtonVariant.danger, loading: _busy, onPressed: () => _cancel(b)),
                  ],
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
