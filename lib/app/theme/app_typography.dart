import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme textTheme(Color primary, Color muted) => TextTheme(
        headlineLarge: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: -0.5, color: primary),
        headlineMedium: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.3, color: primary),
        headlineSmall: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, color: primary),
        titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.3, color: primary),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: primary),
        titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.35, color: primary),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: primary),
        bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: primary),
        bodySmall: TextStyle(fontSize: 12, height: 1.4, color: muted),
        labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primary),
        labelMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: muted),
        labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: muted),
      );
}
