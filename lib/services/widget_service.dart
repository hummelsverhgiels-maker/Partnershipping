import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/backend.dart';
import '../data/store.dart';
import '../logic/schedule.dart';
import '../models.dart';
import '../util.dart';

/// Тексты для виджетов:
///  1) на главном экране Android и iPhone (через общее хранилище телефона);
///  2) облачная копия для бесплатного виджета на iPhone через приложение Scriptable.
/// Тексты заранее считаются на несколько дней вперёд, чтобы виджет оставался
/// верным и после полуночи, даже если приложение не открывали.
class WidgetService {
  static const _provider = 'com.partnershipping.partnershipping.DaysOffWidget';
  static const _iosGroup = 'group.com.partnershipping.partnershipping';
  static const _iosWidget = 'DaysOffWidget';

  static String? _lastUploaded;

  /// Три строки для зрителя [viewer] на день [day].
  static List<String> lines(
      AppStore store, Member viewer, Member? other, DateTime day) {
    final sch = store.schedule;
    final mine = nextOff(day, (d) => sch.isOff(viewer.id, d));
    final out = <String>['Я: ${offSentence(day, mine)}'];
    if (other != null) {
      final theirs = nextOff(day, (d) => sch.isOff(other.id, d));
      out.add('${other.name}: ${offSentence(day, theirs)}');
      final both = nextOff(
          day, (d) => sch.isOff(viewer.id, d) && sch.isOff(other.id, d));
      out.add('Вместе: ${offSentence(day, both)}');
    } else {
      out.add('Партнёр ещё не подключён');
      out.add('');
    }
    return out;
  }

  static Future<void> update(AppStore store) async {
    final me = store.me;
    if (me == null) return;
    final partner = store.partner;
    final today = dateOnly(DateTime.now());

    // --- виджет на главном экране телефона
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        if (Platform.isIOS) await HomeWidget.setAppGroupId(_iosGroup);
        for (var i = 0; i < 14; i++) {
          final day = addDays(today, i);
          final key = ymd(day);
          final l = lines(store, me, partner, day);
          await HomeWidget.saveWidgetData<String>('wm_$key', l[0]);
          await HomeWidget.saveWidgetData<String>('wp_$key', l[1]);
          await HomeWidget.saveWidgetData<String>('wb_$key', l[2]);
        }
        await HomeWidget.updateWidget(
            qualifiedAndroidName: _provider, iOSName: _iosWidget);
      } catch (e) {
        debugPrint('Виджет не обновлён: $e');
      }
    }

    // --- облачная копия (для виджета через Scriptable на iPhone)
    if (!store.isLocal && Backend.configured && store.online) {
      try {
        final s = store.session!;
        final people = [
          (me, partner),
          if (partner != null) (partner, me),
        ];
        final payloads = <String, Map<String, dynamic>>{};
        for (final (viewer, other) in people) {
          final data = <String, dynamic>{};
          for (var i = 0; i < 30; i++) {
            final day = addDays(today, i);
            data[ymd(day)] = lines(store, viewer, other, day);
          }
          payloads[viewer.id] = data;
        }
        final signature = jsonEncode(payloads);
        if (signature != _lastUploaded) {
          for (final e in payloads.entries) {
            await Backend.upsertWidget(s.pairId, e.key, e.value);
          }
          _lastUploaded = signature;
        }
      } catch (e) {
        debugPrint('Облачная копия виджета не обновлена: $e');
      }
    }
  }
}
