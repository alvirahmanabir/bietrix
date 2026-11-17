import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static final ThemeData lightTheme = _build(Brightness.light);
  static final ThemeData darkTheme = _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final dark = b == Brightness.dark;
    final bg = dark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface = dark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final onSurface = dark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final muted = dark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final border = dark ? AppColors.borderDark : AppColors.borderLight;
    final radius = BorderRadius.circular(AppRadius.md);
    OutlineInputBorder ib(Color c, [double w = 1]) => OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: c, width: w));
    final text = AppTypography.textTheme(onSurface, muted);

    final scheme = ColorScheme.fromSeed(seedColor: AppColors.primary, brightness: b).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      surface: surface,
      onSurface: onSurface,
      error: AppColors.danger,
      outline: border,
      outlineVariant: border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      textTheme: text,
      dividerTheme: DividerThemeData(color: border, space: 1, thickness: 1),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg), side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: ib(border),
        enabledBorder: ib(border),
        focusedBorder: ib(AppColors.primary, 1.6),
        errorBorder: ib(AppColors.danger),
        focusedErrorBorder: ib(AppColors.danger, 1.6),
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          foregroundColor: onSurface,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(borderRadius: radius),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
        side: BorderSide(color: border),
        backgroundColor: surface,
        selectedColor: AppColors.primarySoft,
        labelStyle: text.labelLarge,
        secondaryLabelStyle: text.labelLarge?.copyWith(color: AppColors.primaryDark),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        elevation: 0,
        height: 64,
        indicatorColor: dark ? AppColors.primary.withValues(alpha: 0.3) : AppColors.primarySoft,
        labelTextStyle: WidgetStatePropertyAll(text.labelMedium),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.xl)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
    );
  }
}
