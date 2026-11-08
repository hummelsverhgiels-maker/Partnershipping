import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/store.dart';
import '../logic/schedule.dart';
import '../util.dart';

/// Готовит тексты для виджета на главном экране (Android и iPhone).
/// Тексты заранее считаются на 14 дней вперёд, чтобы виджет оставался верным
/// и после полуночи, даже если приложение не открывали.
class WidgetService {
  static const _provider = 'com.partnershipping.partnershipping.DaysOffWidget';
  static const _iosGroup = 'group.com.partnershipping.partnershipping';
  static const _iosWidget = 'DaysOffWidget';

  static Future<void> update(AppStore store) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      if (Platform.isIOS) await HomeWidget.setAppGroupId(_iosGroup);
      final me = store.me;
      if (me == null) return;
      final partner = store.partner;
      final sch = store.schedule;
      final today = dateOnly(DateTime.now());

      for (var i = 0; i < 14; i++) {
        final day = addDays(today, i);
        final key = ymd(day);

        final mine = nextOff(day, (d) => sch.isOff(me.id, d));
        await HomeWidget.saveWidgetData<String>(
            'wm_$key', 'Я: ${offSentence(day, mine)}');

        if (partner != null) {
          final theirs = nextOff(day, (d) => sch.isOff(partner.id, d));
          await HomeWidget.saveWidgetData<String>(
              'wp_$key', '${partner.name}: ${offSentence(day, theirs)}');
          final both = nextOff(
              day, (d) => sch.isOff(me.id, d) && sch.isOff(partner.id, d));
          await HomeWidget.saveWidgetData<String>(
              'wb_$key', 'Вместе: ${offSentence(day, both)}');
        } else {
          await HomeWidget.saveWidgetData<String>(
              'wp_$key', 'Партнёр ещё не подключён');
          await HomeWidget.saveWidgetData<String>('wb_$key', '');
        }
      }
      await HomeWidget.updateWidget(
          qualifiedAndroidName: _provider, iOSName: _iosWidget);
    } catch (e) {
      debugPrint('Виджет не обновлён: $e');
    }
  }
}
