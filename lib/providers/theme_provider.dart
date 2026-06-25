import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the active [ThemeMode] and persists the user's choice across launches.
class ThemeProvider with ChangeNotifier {
  static const _prefsKey = 'theme_mode';
  ThemeMode _mode = ThemeMode.dark;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_prefsKey);
    if (stored == 'light') {
      _mode = ThemeMode.light;
    } else if (stored == 'system') {
      _mode = ThemeMode.system;
    } else {
      _mode = ThemeMode.dark;
    }
    notifyListeners();
  }

  Future<void> toggle() async {
    _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _mode == ThemeMode.dark ? 'dark' : 'light');
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      mode == ThemeMode.dark
          ? 'dark'
          : mode == ThemeMode.light
          ? 'light'
          : 'system',
    );
  }
}
