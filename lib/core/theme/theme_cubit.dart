import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  static const String _themeModeKey = 'theme_mode';

  ThemeCubit() : super(ThemeMode.system) {
    _loadThemeMode();
  }

  void _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMode = prefs.getString(_themeModeKey);
    if (savedMode != null) {
      if (savedMode == 'light') {
        emit(ThemeMode.light);
      } else if (savedMode == 'dark') {
        emit(ThemeMode.dark);
      } else {
        emit(ThemeMode.system);
      }
    }
  }

  void updateThemeMode(ThemeMode mode) async {
    emit(mode);
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.light) {
      await prefs.setString(_themeModeKey, 'light');
    } else if (mode == ThemeMode.dark) {
      await prefs.setString(_themeModeKey, 'dark');
    } else {
      await prefs.setString(_themeModeKey, 'system');
    }
  }
}
