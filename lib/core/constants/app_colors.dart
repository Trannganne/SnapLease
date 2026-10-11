import 'package:flutter/material.dart';

class AppColorsLight {
  static const Color primary = Color(0xFF1D39C4);
  static const Color success = Color(0xFF52C41A);
  static const Color error = Color(0xFFCF1322);
  static const Color background = Color(0xFFF8F9FF);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF121C2A);
  static const Color textSecondary = Color(0xFF444654);
  static const Color border = Color(0xFFD9DDE7);
  static const Color iconColor = Color(0xFF8C8C8C);
}

class AppColorsDark {
  static const Color primary = Color(
    0xFF3856E3,
  ); // slightly lighter primary for dark mode
  static const Color success = Color(0xFF63DE28);
  static const Color error = Color(0xFFE83A46);
  static const Color background = Color(0xFF0F1117);
  static const Color surface = Color(0xFF171A22);
  static const Color textPrimary = Color(0xFFF5F7FA);
  static const Color textSecondary = Color(0xFFAEB4C0);
  static const Color border = Color(0xFF343A46);
  static const Color iconColor = Color(0xFF8C8C8C);
}

class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  final Color success;

  const AppColorsExtension({required this.success});

  @override
  ThemeExtension<AppColorsExtension> copyWith({Color? success}) {
    return AppColorsExtension(success: success ?? this.success);
  }

  @override
  ThemeExtension<AppColorsExtension> lerp(
    covariant ThemeExtension<AppColorsExtension>? other,
    double t,
  ) {
    if (other is! AppColorsExtension) {
      return this;
    }
    return AppColorsExtension(success: Color.lerp(success, other.success, t)!);
  }
}

// Ensure old uses are compiled, or just leave AppColors as is if some were missed
class AppColors {
  static const Color primary = AppColorsLight.primary;
  static const Color success = AppColorsLight.success;
  static const Color error = AppColorsLight.error;
  static const Color background = AppColorsLight.background;
  static const Color textPrimary = AppColorsLight.textPrimary;
  static const Color textSecondary = AppColorsLight.textSecondary;
  static const Color border = AppColorsLight.border;
  static const Color borderFocused = primary;
  static const Color borderError = error;
  static const Color iconColor = AppColorsLight.iconColor;
}
