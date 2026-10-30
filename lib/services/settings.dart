import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  SharedPreferences? _prefs;
  ThemeMode themeMode = ThemeMode.system;
  String? rootPath;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode = switch (_prefs!.getString('theme')) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    rootPath = _prefs!.getString('root');
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await _prefs?.setString('theme', mode.name);
  }

  Future<void> setRoot(String path) async {
    rootPath = path;
    notifyListeners();
    await _prefs?.setString('root', path);
  }
}
