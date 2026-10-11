import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColorsLight.primary,
      scaffoldBackgroundColor: AppColorsLight.background,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.light(
        primary: AppColorsLight.primary,
        error: AppColorsLight.error,
        surface: AppColorsLight.surface,
        onSurface: AppColorsLight.textPrimary,
        onSurfaceVariant: AppColorsLight.textSecondary,
        outline: AppColorsLight.border,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppColorsExtension(success: AppColorsLight.success),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsLight.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColorsLight.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColorsLight.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
      ),
      iconTheme: const IconThemeData(color: AppColorsLight.iconColor),
      cardTheme: const CardThemeData(
        color: AppColorsLight.surface,
        shadowColor: Colors.black12,
        elevation: 2,
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsLight.surface,
        modalBackgroundColor: AppColorsLight.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsLight.border,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColorsDark.primary,
      scaffoldBackgroundColor: AppColorsDark.background,
      fontFamily: 'Roboto',
      colorScheme: const ColorScheme.dark(
        primary: AppColorsDark.primary,
        error: AppColorsDark.error,
        surface: AppColorsDark.surface,
        onSurface: AppColorsDark.textPrimary,
        onSurfaceVariant: AppColorsDark.textSecondary,
        outline: AppColorsDark.border,
      ),
      extensions: const <ThemeExtension<dynamic>>[
        AppColorsExtension(success: AppColorsDark.success),
      ],
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColorsDark.surface,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColorsDark.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColorsDark.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: 'Roboto',
        ),
      ),
      iconTheme: const IconThemeData(color: AppColorsDark.iconColor),
      cardTheme: const CardThemeData(
        color: AppColorsDark.surface,
        shadowColor: Colors.black45,
        elevation: 2,
        margin: EdgeInsets.zero,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColorsDark.surface,
        modalBackgroundColor: AppColorsDark.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColorsDark.border,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
