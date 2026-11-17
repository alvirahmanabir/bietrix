import 'package:jamcon/core/errors/failure.dart';
import 'package:jamcon/domain/models/booking.dart';
import 'package:jamcon/domain/models/enums.dart';

/// Order lifecycle rules. Enforced in business logic — hiding buttons is never enough.
///
///  Pending Confirmation -> Confirmed              (admin)
///  Pending Confirmation -> Cancelled by Customer  (customer)
///  Pending Confirmation -> Cancelled by Admin     (admin)
///  Confirmed            -> Cancelled by Admin     (admin ONLY)
///  Confirmed            -> Completed              (admin)
abstract final class BookingPolicy {
  static const Map<BookingStatus, Map<BookingStatus, Actor>> _allowed = {
    BookingStatus.pendingConfirmation: {
      BookingStatus.confirmed: Actor.admin,
      BookingStatus.cancelledByCustomer: Actor.customer,
      BookingStatus.cancelledByAdmin: Actor.admin,
    },
    BookingStatus.confirmed: {
      BookingStatus.cancelledByAdmin: Actor.admin,
      BookingStatus.completed: Actor.admin,
    },
  };

  static bool canTransition(Actor actor, BookingStatus from, BookingStatus to) => _allowed[from]?[to] == actor;

  static bool canCustomerCancel(Booking b) => canTransition(Actor.customer, b.status, BookingStatus.cancelledByCustomer);
  static bool canAdminConfirm(Booking b) => canTransition(Actor.admin, b.status, BookingStatus.confirmed);
  static bool canAdminCancel(Booking b) => canTransition(Actor.admin, b.status, BookingStatus.cancelledByAdmin);
  static bool canAdminComplete(Booking b) => canTransition(Actor.admin, b.status, BookingStatus.completed);

  /// Pure transition: returns the updated booking or throws [PolicyFailure].
  static Booking apply(
    Booking b,
    BookingStatus to,
    Actor actor, {
    required DateTime now,
    required String by,
    String? reason,
  }) {
    if (!canTransition(actor, b.status, to)) {
      throw PolicyFailure(_explain(b.status, to, actor));
    }
    final cleanReason = (reason ?? '').trim();
    return b.copyWith(
      status: to,
      cancellation: to.isCancelled
          ? Cancellation(cancelledBy: actor, cancelledAt: now, reason: cleanReason.isEmpty ? null : cleanReason)
          : null,
      history: [...b.history, StatusEvent(status: to, at: now, by: by)],
    );
  }

  static String _explain(BookingStatus from, BookingStatus to, Actor actor) {
    if (actor == Actor.customer && to == BookingStatus.cancelledByCustomer) {
      if (from == BookingStatus.confirmed) {
        return 'This booking is already confirmed and can only be cancelled by the studio. Please contact support.';
      }
      return 'This booking can no longer be cancelled (${from.label}).';
    }
    if (_allowed[from]?[to] != null) return 'You are not allowed to perform this action.';
    return 'A booking that is "${from.label}" cannot be changed to "${to.label}".';
  }
}
