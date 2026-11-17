import 'package:jamcon/domain/models/enums.dart';

class SupportRequest {
  const SupportRequest({
    required this.id,
    required this.userId,
    required this.name,
    required this.email,
    required this.phone,
    required this.category,
    required this.subject,
    required this.message,
    this.status = SupportStatus.pending,
    this.notes = const [],
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String name;
  final String email;
  final String phone;
  final SupportCategory category;
  final String subject;
  final String message;
  final SupportStatus status;
  final List<String> notes; // internal admin notes
  final DateTime createdAt;

  SupportRequest copyWith({SupportStatus? status, List<String>? notes}) => SupportRequest(
        id: id,
        userId: userId,
        name: name,
        email: email,
        phone: phone,
        category: category,
        subject: subject,
        message: message,
        status: status ?? this.status,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'name': name,
        'email': email,
        'phone': phone,
        'category': category.name,
        'subject': subject,
        'message': message,
        'status': status.name,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SupportRequest.fromJson(Map<String, dynamic> j) => SupportRequest(
        id: j['id'] as String,
        userId: j['userId'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        phone: j['phone'] as String,
        category: enumByName(SupportCategory.values, j['category'], SupportCategory.other),
        subject: j['subject'] as String,
        message: j['message'] as String,
        status: enumByName(SupportStatus.values, j['status'], SupportStatus.pending),
        notes: ((j['notes'] as List?) ?? const []).cast<String>(),
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
