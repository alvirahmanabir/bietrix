import 'package:jamcon/domain/models/enums.dart';

enum Permission {
  viewDashboard,
  manageOrders,
  viewCustomers,
  managePackages,
  manageServices,
  manageCoupons,
  manageSupport,
  viewRevenue,
  manageAdmins,
}

/// Role -> permission matrix. The backend must enforce the same matrix.
abstract final class Permissions {
  static const Map<AdminRole, Set<Permission>> matrix = {
    AdminRole.superAdmin: {...Permission.values},
    AdminRole.admin: {
      Permission.viewDashboard,
      Permission.manageOrders,
      Permission.viewCustomers,
      Permission.managePackages,
      Permission.manageServices,
      Permission.manageCoupons,
      Permission.manageSupport,
      Permission.viewRevenue,
    },
    AdminRole.orderManager: {Permission.viewDashboard, Permission.manageOrders, Permission.viewCustomers},
    AdminRole.customerSupport: {Permission.viewDashboard, Permission.manageSupport, Permission.viewCustomers},
  };

  static bool has(AdminRole role, Permission p) => matrix[role]?.contains(p) ?? false;

  static String describe(Permission p) => switch (p) {
        Permission.viewDashboard => 'View dashboard',
        Permission.manageOrders => 'Manage orders (confirm, cancel, complete)',
        Permission.viewCustomers => 'View customers',
        Permission.managePackages => 'Manage packages',
        Permission.manageServices => 'Manage services',
        Permission.manageCoupons => 'Manage coupons',
        Permission.manageSupport => 'Handle support requests',
        Permission.viewRevenue => 'View revenue analytics',
        Permission.manageAdmins => 'Manage admin accounts',
      };
}
