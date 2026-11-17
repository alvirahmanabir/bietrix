/// Form validators. Domain services re-run the important ones — never trust UI validation alone.
abstract final class Validators {
  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Email is required';
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s) ? null : 'Enter a valid email address';
  }

  static bool isPhone(String s) => RegExp(r'^(\+?88)?01[3-9]\d{8}$').hasMatch(s.replaceAll(RegExp(r'[\s-]'), ''));

  static String? phone(String? v, {bool optional = false}) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return optional ? null : 'Phone number is required';
    return isPhone(s) ? null : 'Enter a valid BD mobile number (01XXXXXXXXX)';
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    return v.length < 6 ? 'Use at least 6 characters' : null;
  }

  static String? confirm(String? v, String other) => v != other ? 'Passwords do not match' : null;

  static String? minLength(String? v, int n, String field) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return '$field is required';
    return s.length < n ? '$field must be at least $n characters' : null;
  }

  static String? positiveInt(String? v, String field) {
    final n = int.tryParse((v ?? '').trim());
    return (n == null || n <= 0) ? '$field must be a positive number' : null;
  }
}
