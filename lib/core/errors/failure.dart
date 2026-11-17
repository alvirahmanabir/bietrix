import 'package:flutter/material.dart';

import 'package:jamcon/app/theme/app_colors.dart';

/// Typed failures thrown by the domain/data layers. Real API clients should map
/// HTTP errors (400/401/403/404/409/5xx) onto these same types.
sealed class Failure implements Exception {
  const Failure(this.message);
  final String message;
  @override
  String toString() => message;
}

final class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

final class PolicyFailure extends Failure {
  const PolicyFailure(super.message);
}

final class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message);
}

final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);
}

final class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error. Check your connection and try again.']);
}

/// Single place that turns errors into user-facing feedback.
abstract final class ErrorHandler {
  static String message(Object e) => e is Failure ? e.message : 'Something went wrong. Please try again.';

  static void show(BuildContext context, Object e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message(e)), backgroundColor: AppColors.danger));
  }

  static void success(BuildContext context, String msg) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.success));
  }
}
