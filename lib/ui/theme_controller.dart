import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme.dart';

/// Выбор темы: системная, светлая или тёмная. Запоминается на телефоне.
class ThemeController extends ChangeNotifier with WidgetsBindingObserver {
  String _mode = 'system'; // system | light | dark
  SharedPreferences? _prefs;
  bool _observing = false;
  bool _newYear = false;

  /// Новогодняя тема (поверх светлой или тёмной).
  bool get newYear => _newYear;

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
      _newYear = _prefs!.getBool('theme_newyear') ?? false;
    } catch (_) {}
    applyPalette(isDark, newYear: _newYear);
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
  }

  void setMode(String m) {
    if (m == _mode) return;
    _mode = m;
    _prefs?.setString('theme_mode', m);
    applyPalette(isDark, newYear: _newYear);
    notifyListeners();
  }

  void setNewYear(bool v) {
    if (v == _newYear) return;
    _newYear = v;
    _prefs?.setBool('theme_newyear', v);
    applyPalette(isDark, newYear: _newYear);
    notifyListeners();
  }

  @override
  void didChangePlatformBrightness() {
    if (_mode == 'system') {
      applyPalette(isDark, newYear: _newYear);
      notifyListeners();
    }
  }
}

final themeController = ThemeController();
