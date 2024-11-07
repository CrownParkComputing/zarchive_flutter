import 'package:flutter/material.dart';
import '../services/settings_service.dart';

class ThemeProvider extends ChangeNotifier {
  final SettingsService _settings;
  late bool _isDarkMode;

  ThemeProvider(this._settings) {
    _isDarkMode = _settings.isDarkMode();
  }

  bool get isDarkMode => _isDarkMode;

  ThemeData get theme => _isDarkMode ? _darkTheme : _lightTheme;

  Future<void> toggleTheme() async {
    _isDarkMode = !_isDarkMode;
    await _settings.setDarkMode(_isDarkMode);
    notifyListeners();
  }

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
  );

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
  );
}
