import 'package:flutter/material.dart';

import 'package:jamcon/app/theme/app_colors.dart';
import 'package:jamcon/app/theme/app_radius.dart';
import 'package:jamcon/core/utils/ext.dart';
import 'package:jamcon/core/utils/formatters.dart';
import 'package:jamcon/core/widgets/widgets.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';

class DetailSection extends StatelessWidget {
  const DetailSection({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: context.title),
            const SizedBox(height: 8),
            ...children,
          ]),
        ),
      );
}

/// Shared booking summary used by confirmation, customer order detail and admin order detail.
class BookingDetailSections extends StatelessWidget {
  const BookingDetailSections({super.key, required this.booking, this.showTimeline = true});
  final Booking booking;
  final bool showTimeline;

  @override
  Widget build(BuildContext context) {
    final b = booking;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      DetailSection(title: 'Package & services', children: [
        InfoRow('Package', b.packageName),
        if (b.isCustom) const InfoRow('Type', 'Customized package'),
        const Divider(height: 16),
        for (final i in b.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, size: 16, color: AppColors.success),
              const SizedBox(width: 8),
              Expanded(child: Text('${i.name}${i.qty > 1 ? '  ×${i.qty}' : ''}', style: context.body)),
              if (b.isCustom) Text(Fmt.money(i.lineTotal), style: context.body.copyWith(fontWeight: FontWeight.w600)),
            ]),
          ),
      ]),
      DetailSection(title: 'Event', children: [
        InfoRow('Date', Fmt.dateLong(b.schedule.date)),
        InfoRow('Time', b.schedule.slot),
        InfoRow('Location', b.location.full),
      ]),
      DetailSection(title: 'Customer', children: [
        InfoRow('Name', b.contact.name),
        InfoRow('Phone', b.contact.phone),
        InfoRow('Email', b.contact.email),
        if (b.contact.altPhone.isNotEmpty) InfoRow('Alt. phone', b.contact.altPhone),
        if (b.contact.notes.isNotEmpty) InfoRow('Instructions', b.contact.notes),
      ]),
      DetailSection(title: 'Payment', children: [
        PriceSummary(pricing: b.pricing, couponCode: b.coupon?.code),
        const Divider(height: 16),
        InfoRow('Method', b.payment.method.label),
        if (b.payment.provider != null) InfoRow('Provider', b.payment.provider!.label),
        if (b.payment.reference != null) InfoRow('Reference', b.payment.reference!),
        InfoRow('Payment status', b.payment.status.label, valueColor: b.payment.status == PaymentStatus.paid ? AppColors.success : AppColors.warning),
      ]),
      if (b.cancellation != null) CancellationCard(booking: b),
      if (showTimeline)
        DetailSection(title: 'Status timeline', children: [
          for (final e in b.history.reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(margin: const EdgeInsets.only(top: 5), width: 10, height: 10, decoration: BoxDecoration(color: statusColor(e.status), shape: BoxShape.circle)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(e.status.label, style: context.titleSm),
                    Text('${Fmt.dateTime(e.at)} · ${e.by}', style: context.small),
                  ]),
                ),
              ]),
            ),
        ]),
    ]);
  }
}

class CancellationCard extends StatelessWidget {
  const CancellationCard({super.key, required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext context) {
    final c = booking.cancellation!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 20),
          const SizedBox(width: 8),
          Text('Cancellation details', style: context.title.copyWith(color: AppColors.danger)),
        ]),
        const SizedBox(height: 8),
        InfoRow('Status', booking.status.label),
        InfoRow('Cancelled by', c.cancelledBy == Actor.admin ? 'Admin' : 'Customer'),
        InfoRow('Date & time', Fmt.dateTime(c.cancelledAt)),
        InfoRow('Reason', (c.reason == null || c.reason!.isEmpty) ? 'No reason provided' : c.reason!),
      ]),
    );
  }
}
