import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Выбор темы: системная, светлая или тёмная. Запоминается на телефоне.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  String _mode = 'system'; // system | light | dark
  SharedPreferences? _prefs;
  bool _observing = false;

  String get mode => _mode;

  bool get isDark =>
      _mode == 'dark' ||
      (_mode == 'system' &&
          PlatformDispatcher.instance.platformBrightness == Brightness.dark);

  Future<void> load() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final m = _prefs!.getString('theme_mode');
      if (m == 'light' || m == 'dark' || m == 'system') _mode = m!;
    } catch (_) {}
    applyPalette(isDark);
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  void setMode(String m) {
    if (m == _mode) return;
    _mode = m;
    _prefs?.setString('theme_mode', m);
    applyPalette(isDark);
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == 'system') {
      applyPalette(isDark);
      notifyListeners();
    }
  }
}

final themeController = ThemeController();
