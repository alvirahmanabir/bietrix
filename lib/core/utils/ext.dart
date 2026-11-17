import 'package:flutter/material.dart';

import 'package:jamcon/app/theme/app_colors.dart';

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T e) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get muted => isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
  Color get border => isDark ? AppColors.borderDark : AppColors.borderLight;
  Color get surface => theme.colorScheme.surface;
  double get width => MediaQuery.sizeOf(this).width;
  bool get isWide => width >= 1024;
  bool get isTablet => width >= 600;

  TextStyle get hLg => text.headlineMedium!;
  TextStyle get hMd => text.headlineSmall!;
  TextStyle get titleLg => text.titleLarge!;
  TextStyle get title => text.titleMedium!;
  TextStyle get titleSm => text.titleSmall!;
  TextStyle get body => text.bodyMedium!;
  TextStyle get small => text.bodySmall!;
  TextStyle get label => text.labelLarge!;
}
