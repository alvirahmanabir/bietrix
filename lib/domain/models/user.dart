import 'package:jamcon/domain/models/enums.dart';
import 'package:jamcon/domain/rules/permissions.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address = '',
    this.status = AccountStatus.active,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email; // immutable after registration
  final String phone;
  final String address;
  final AccountStatus status;
  final DateTime createdAt;

  /// Note: there is intentionally no way to change [email] through copyWith.
  AppUser copyWith({String? name, String? phone, String? address, AccountStatus? status}) => AppUser(
        id: id,
        name: name ?? this.name,
        email: email,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        status: status ?? this.status,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'address': address,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String,
        address: (j['address'] as String?) ?? '',
        status: enumByName(AccountStatus.values, j['status'], AccountStatus.active),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class AdminUser {
  const AdminUser({required this.id, required this.name, required this.email, this.phone = '', required this.role});
  final String id;
  final String name;
  final String email;
  final String phone;
  final AdminRole role;

  AdminUser copyWith({String? name, String? phone}) =>
      AdminUser(id: id, name: name ?? this.name, email: email, phone: phone ?? this.phone, role: role);

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'email': email, 'phone': phone, 'role': role.name};
  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: (j['phone'] as String?) ?? '',
        role: enumByName(AdminRole.values, j['role'], AdminRole.customerSupport),
      );
}

/// Authenticated identity (customer when [role] is null). Mirrors what a JWT would carry.
class Session {
  const Session({required this.userId, required this.name, required this.email, this.role});
  final String userId;
  final String name;
  final String email;
  final AdminRole? role;

  bool get isAdmin => role != null;
  bool can(Permission p) => role != null && Permissions.has(role!, p);

  Map<String, dynamic> toJson() => {'userId': userId, 'name': name, 'email': email, 'role': role?.name};
  factory Session.fromJson(Map<String, dynamic> j) => Session(
        userId: j['userId'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        role: j['role'] == null ? null : enumByName(AdminRole.values, j['role'], AdminRole.customerSupport),
      );
}
