import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _defaultCreatePathKey = 'default_create_path';
  static const String _defaultExtractPathKey = 'default_extract_path';
  static const String _isDarkModeKey = 'is_dark_mode';

  late final SharedPreferences _prefs;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String? getDefaultCreatePath() {
    return _prefs.getString(_defaultCreatePathKey);
  }

  Future<void> setDefaultCreatePath(String path) async {
    await _prefs.setString(_defaultCreatePathKey, path);
  }

  String? getDefaultExtractPath() {
    return _prefs.getString(_defaultExtractPathKey);
  }

  Future<void> setDefaultExtractPath(String path) async {
    await _prefs.setString(_defaultExtractPathKey, path);
  }

  bool isDarkMode() {
    return _prefs.getBool(_isDarkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_isDarkModeKey, value);
  }
}
