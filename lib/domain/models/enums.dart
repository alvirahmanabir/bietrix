T enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

enum BookingStatus {
  pendingConfirmation('Pending Confirmation'),
  confirmed('Confirmed'),
  cancelledByCustomer('Cancelled by Customer'),
  cancelledByAdmin('Cancelled by Admin'),
  completed('Completed');

  const BookingStatus(this.label);
  final String label;
  bool get isCancelled => this == cancelledByCustomer || this == cancelledByAdmin;
}

enum Actor { customer, admin }

enum PaymentMethod {
  cashOnSite('Cash on Site'),
  online('Online Payment');

  const PaymentMethod(this.label);
  final String label;
}

enum PaymentProvider {
  bkash('bKash'),
  nagad('Nagad'),
  card('Credit / Debit Card');

  const PaymentProvider(this.label);
  final String label;
}

enum PaymentStatus {
  pending('Pending'),
  paid('Paid'),
  failed('Failed');

  const PaymentStatus(this.label);
  final String label;
}

enum CouponType { percent, fixed }

enum AdminRole {
  superAdmin('Super Admin'),
  admin('Admin'),
  orderManager('Order Manager'),
  customerSupport('Customer Support');

  const AdminRole(this.label);
  final String label;
}

enum SupportStatus {
  pending('Pending'),
  inProgress('In Progress'),
  resolved('Resolved');

  const SupportStatus(this.label);
  final String label;
}

enum SupportCategory {
  packageInquiry('Package Inquiry'),
  customPackageRequest('Custom Package Request'),
  bookingAssistance('Booking Assistance'),
  paymentIssue('Payment Issue'),
  generalSupport('General Support'),
  other('Other');

  const SupportCategory(this.label);
  final String label;
}

enum AccountStatus {
  active('Active'),
  suspended('Suspended');

  const AccountStatus(this.label);
  final String label;
}

/// Fixed time slots (dummy availability uses these).
abstract final class EventSlots {
  static const all = ['09:00 AM', '12:00 PM', '03:00 PM', '06:00 PM'];
}
