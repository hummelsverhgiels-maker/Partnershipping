import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../data/backend.dart';
import '../data/store.dart';
import '../config.dart';
import '../logic/mood.dart';
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
  static String? _lastLocal;
  static final Map<String, String> _localValues = {};

  /// Три строки для зрителя [viewer] на день [day].
  static List<String> lines(
    AppStore store,
    Member viewer,
    Member? other,
    DateTime day,
  ) {
    final sch = store.schedule;
    final mine = nextOff(day, (d) => sch.isOff(viewer.id, d));
    final out = <String>['Я: ${offSentence(day, mine)}'];
    if (other != null) {
      final theirs = nextOff(day, (d) => sch.isOff(other.id, d));
      out.add('${other.name}: ${offSentence(day, theirs)}');
      final both = nextOff(
        day,
        (d) => sch.isOff(viewer.id, d) && sch.isOff(other.id, d),
      );
      out.add('Вместе: ${offSentence(day, both)}');
    } else {
      out.add('Партнёр ещё не подключён');
      out.add('');
    }
    out.add(chatLine(store, viewer, other));
    out.add(moodLine(store, viewer, other));
    return out;
  }

  /// «💬 Аня: Привет! (+2)» — пока есть непрочитанные сообщения.
  static String chatLine(AppStore store, Member viewer, Member? other) {
    if (other == null) return '';
    final n = store.unreadFor(viewer.id);
    final last = store.lastUnreadFor(viewer.id);
    if (n == 0 || last == null) return '';
    var t = last.s('text') ?? '';
    if (t.isEmpty) {
      t = switch (last.s('type')) {
        'image' => '📷 Фото',
        'video' => '🎥 Видео',
        'audio' => '🎤 Голосовое',
        'file' => '📎 Файл',
        _ => 'Сообщение',
      };
    }
    if (t.length > 34) t = '${t.substring(0, 34)}…';
    return '💬 ${other.name}: $t${n > 1 ? ' (+${n - 1})' : ''}';
  }

  /// «Настроение: Я 🙂🥱 · Аня 😐🍔» (смайлик настроения и значки состояний).
  static String moodLine(AppStore store, Member viewer, Member? other) {
    String part(String id) {
      final v = store.moodOf(id);
      final tags = store
          .moodTagsOf(id)
          .map((t) => moodTagById(t)?.emoji ?? '')
          .where((e) => e.isNotEmpty)
          .join();
      return '${v == null ? '' : moodEmoji(v)}$tags';
    }

    final a = part(viewer.id);
    final b = other == null ? '' : part(other.id);
    if (a.isEmpty && b.isEmpty) return '';
    final parts = <String>[
      if (a.isNotEmpty) 'Я $a',
      if (b.isNotEmpty) '${other!.name} $b',
    ];
    return 'Настроение: ${parts.join(' · ')}';
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
        final values = <String, String>{};
        for (var i = 0; i < 14; i++) {
          final day = addDays(today, i);
          final key = ymd(day);
          final l = lines(store, me, partner, day);
          values['wm_$key'] = l[0];
          values['wp_$key'] = l[1];
          values['wb_$key'] = l[2];
        }
        final now = lines(store, me, partner, today);
        values['wchat'] = now[3];
        values['wmood'] = now[4];
        // Данные для самостоятельного обновления виджета Android (даже при закрытом приложении)
        if (!store.isLocal && store.session != null) {
          values['cfg_urls'] = [
            kSupabaseUrl,
            kSupabaseProxyUrl,
          ].where((u) => u.isNotEmpty).join(',');
          values['cfg_key'] = kSupabaseAnonKey;
          values['cfg_code'] = store.session!.code;
          values['cfg_member'] = store.session!.memberId;
        }
        // Ничего не поменялось — не трогаем виджет (экономим батарею).
        final sig = jsonEncode(values);
        if (sig == _lastLocal) {
          await _uploadCloud(store, me, partner, today);
          return;
        }
        for (final e in values.entries) {
          if (_localValues[e.key] == e.value) continue;
          await HomeWidget.saveWidgetData<String>(e.key, e.value);
        }
        _localValues
          ..clear()
          ..addAll(values);
        _lastLocal = sig;
        await HomeWidget.updateWidget(
          qualifiedAndroidName: _provider,
          iOSName: _iosWidget,
        );
      } catch (e) {
        debugPrint('Виджет не обновлён: $e');
      }
    }

    await _uploadCloud(store, me, partner, today);
  }

  /// Облачная копия (для виджета через Scriptable на iPhone).
  static Future<void> _uploadCloud(
    AppStore store,
    Member me,
    Member? partner,
    DateTime today,
  ) async {
    if (!store.isLocal && Backend.configured && store.online) {
      try {
        final s = store.session!;
        final people = [(me, partner), if (partner != null) (partner, me)];
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
