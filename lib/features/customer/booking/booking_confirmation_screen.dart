import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/features/common/booking_details.dart';
import 'package:jamcon/features/common/queries.dart';

class BookingConfirmationScreen extends ConsumerWidget {
  const BookingConfirmationScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bookingByIdProvider(id));
    return Scaffold(
      appBar: AppBar(title: const Text('Booking confirmation'), automaticallyImplyLeading: false),
      body: AsyncValueView<Booking?>(
        value: async,
        data: (b) {
          if (b == null) return const EmptyState(icon: Icons.search_off, title: 'Booking not found');
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Column(children: [
                  const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 72),
                  const SizedBox(height: 10),
                  Text('Booking placed!', style: context.hLg),
                  const SizedBox(height: 6),
                  Text('The studio will review and confirm your booking shortly. You can cancel it while it is pending.', textAlign: TextAlign.center, style: context.body.copyWith(color: context.muted)),
                  const SizedBox(height: 18),
                  AppCard(
                    child: Column(children: [
                      InfoRow('Booking ID', b.code, bold: true, valueColor: AppColors.primary),
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Booking status', style: context.body.copyWith(color: context.muted)), StatusBadge(b.status)]),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: BookingDetailSections(booking: b, showTimeline: false)),
                  AppButton(label: 'View my orders', icon: Icons.receipt_long_outlined, onPressed: () => context.go('/orders/${b.id}')),
                  const SizedBox(height: 8),
                  AppButton(label: 'Back to home', variant: AppButtonVariant.secondary, onPressed: () => context.go('/home')),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
