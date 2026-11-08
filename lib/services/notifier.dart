import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/store.dart';
import '../logic/dog.dart';
import '../util.dart';

/// Локальные уведомления: напоминания о выплатах и сообщения об изменениях партнёра.
class Notifier {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static const _payChannel = AndroidNotificationDetails(
    'pay',
    'Зарплата и аванс',
    channelDescription: 'Напоминание за день до выплаты',
    importance: Importance.high,
    priority: Priority.high,
  );
  static const _partnerChannel = AndroidNotificationDetails(
    'partner',
    'Изменения партнёра',
    channelDescription: 'Когда партнёр поменял график или списки',
    importance: Importance.high,
    priority: Priority.high,
  );

  static Future<void> init() async {
    if (_ready || kIsWeb) return;
    try {
      tzdata.initializeTimeZones();
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Часовой пояс не определён: $e');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    if (Platform.isAndroid) {
      // Каналы для уведомлений; в них же приходят мгновенные уведомления с сервера.
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'partner',
          'Изменения партнёра',
          description: 'Сообщения и изменения от партнёра',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'dog',
          'Собака',
          description: 'Прогулки, прививки, корм',
          importance: Importance.high,
        ),
      );
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          'pay',
          'Зарплата и аванс',
          description: 'Напоминание за день до выплаты',
          importance: Importance.high,
        ),
      );
    }
    _ready = true;
  }

  /// Разрешение на уведомления (Android 13+ и iPhone спросят у пользователя).
  static Future<void> requestPermission() async {
    if (!_ready) return;
    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  static const _dogChannel = AndroidNotificationDetails(
    'dog',
    'Собака',
    channelDescription: 'Прогулки, прививки, корм',
    importance: Importance.high,
    priority: Priority.high,
  );

  static String? _lastPlan;

  /// Все запланированные напоминания: выплаты, вечерняя прогулка,
  /// прививки и обработки, корм. Если ничего не поменялось — не трогаем.
  static Future<void> rescheduleAll(AppStore store) async {
    if (!_ready) return;
    try {
      final plan = planNotes(store, DateTime.now());
      final sig = plan
          .map((p) => '${p.id}|${p.when}|${p.title}|${p.body}')
          .join('\n');
      if (sig == _lastPlan) return;
      await _plugin.cancelAllPendingNotifications();
      for (final p in plan) {
        await _plugin.zonedSchedule(
          id: p.id,
          scheduledDate: tz.TZDateTime(
            tz.local,
            p.when.year,
            p.when.month,
            p.when.day,
            p.when.hour,
            p.when.minute,
          ),
          notificationDetails: NotificationDetails(
            android: p.dog ? _dogChannel : _payChannel,
            iOS: const DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: p.title,
          body: p.body,
        );
      }
      _lastPlan = sig;
    } catch (e) {
      debugPrint('Не удалось запланировать напоминания: $e');
    }
  }

  static Future<void> showKiss(String who, int count) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: 3,
        title: '$who 💋',
        body: count > 1
            ? 'Прислал(а) тебе поцелуйчики (+$count)'
            : 'Прислал(а) тебе поцелуйчик',
        notificationDetails: const NotificationDetails(
          android: _partnerChannel,
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Уведомление не показано: $e');
    }
  }

  static Future<void> showPartnerChange(
    String who,
    Set<String> cats, {
    String? lastMessage,
    String? dogLine,
  }) async {
    if (!_ready) return;
    if (cats.length == 1 && cats.contains('dog') && dogLine != null) {
      try {
        await _plugin.show(
          id: 4,
          title: '$who 🐶',
          body: dogLine,
          notificationDetails: const NotificationDetails(
            android: _dogChannel,
            iOS: DarwinNotificationDetails(),
          ),
        );
      } catch (e) {
        debugPrint('Уведомление не показано: $e');
      }
      return;
    }
    if (cats.length == 1 && cats.contains('chat') && lastMessage != null) {
      try {
        await _plugin.show(
          id: 2,
          title: who,
          body: lastMessage,
          notificationDetails: const NotificationDetails(
            android: _partnerChannel,
            iOS: DarwinNotificationDetails(),
          ),
        );
      } catch (e) {
        debugPrint('Уведомление не показано: $e');
      }
      return;
    }
    final parts = <String>[
      if (cats.contains('chat')) 'сообщения',
      if (cats.contains('schedule')) 'график',
      if (cats.contains('event')) 'события',
      if (cats.contains('shopping')) 'покупки',
      if (cats.contains('todo')) 'дела',
      if (cats.contains('feed')) 'ленту',
      if (cats.contains('docs')) 'документы',
      if (cats.contains('dog')) 'собаку',
    ];
    if (parts.isEmpty) return;
    try {
      await _plugin.show(
        id: 1,
        title: '$who внёс(ла) изменения',
        body: 'Обновлено: ${parts.join(', ')}',
        notificationDetails: const NotificationDetails(
          android: _partnerChannel,
          iOS: DarwinNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Уведомление не показано: $e');
    }
  }
}

/// Одно запланированное напоминание.
class PlannedNote {
  final int id;
  final DateTime when;
  final String title;
  final String body;
  final bool dog;
  const PlannedNote(
    this.id,
    this.when,
    this.title,
    this.body, {
    this.dog = false,
  });
}

/// Что и когда напомнить (без самих уведомлений — удобно проверять).
List<PlannedNote> planNotes(AppStore store, DateTime now) {
  final out = <PlannedNote>[];
  final today = dateOnly(now);
  // выплаты: за день, в 9:00
  if (store.getFlag('notif_pay')) {
    final items = store.schedule
        .paymentsInRange(today, addDays(today, 90))
        .where((p) => store.memberById(p.memberId) != null);
    var id = 1000;
    for (final p in items) {
      final d = addDays(p.date, -1);
      final when = DateTime(d.year, d.month, d.day, 9);
      if (!when.isAfter(now)) continue;
      final mine = p.memberId == store.session?.memberId;
      final who = mine ? '' : ' у ${store.memberById(p.memberId)!.name}';
      out.add(
        PlannedNote(
          id++,
          when,
          'Завтра ${p.label.toLowerCase()}$who',
          p.shifted
              ? 'Выплата перенесена с ${p.nominal.day}-го числа на ближайший рабочий день.'
              : 'Не забудьте: завтра выплата.',
        ),
      );
    }
  }
  if (!store.getFlag('notif_dog')) return out;
  final name = store.dogName;
  // вечерняя прогулка: в 21:30, если ещё не отмечена (на неделю вперёд)
  for (var i = 0; i < 7; i++) {
    final d = addDays(today, i);
    final when = DateTime(d.year, d.month, d.day, 21, 30);
    if (!when.isAfter(now)) continue;
    if (store.dogDoneOf(d, kDogWalkEvening.id) != null) continue;
    out.add(
      PlannedNote(
        2000 + i,
        when,
        '${store.dogEmoji} $name ждёт прогулку',
        'Вечерняя прогулка ещё не отмечена. Если уже гуляли — нажмите ✅ в приложении.',
        dog: true,
      ),
    );
  }
  // прививки и обработки: в 10:00 в день срока
  var cid = 3000;
  for (final r in store.dogCare) {
    if (cid >= 3100) break;
    final next = careNext(r.s('last'), r.i('every') ?? 0);
    if (next == null) continue;
    final when = DateTime(next.year, next.month, next.day, 10);
    if (!when.isAfter(now) || next.isAfter(addDays(today, 120))) continue;
    out.add(
      PlannedNote(
        cid++,
        when,
        '${r.s('emoji') ?? '💉'} Пора: ${r.s('title') ?? 'процедура'}',
        'Сегодня по плану для собаки ($name). Отметьте «Сделано» в «Здоровье».',
        dog: true,
      ),
    );
  }
  // запасы: в 10:00, когда останется 2 дня
  var sid = 4000;
  for (final r in store.dogSupplies) {
    if (sid >= 4100) break;
    final b = r.s('bought');
    if (b == null) continue;
    final end = addDays(parseYmd(b), (r.i('lasts') ?? 30) - 2);
    final when = DateTime(end.year, end.month, end.day, 10);
    if (!when.isAfter(now) || end.isAfter(addDays(today, 120))) continue;
    out.add(
      PlannedNote(
        sid++,
        when,
        '${r.s('emoji') ?? '🥣'} Скоро закончится: ${r.s('title') ?? 'запас'}',
        'Хватит примерно на 2 дня. Добавьте в покупки 🛒',
        dog: true,
      ),
    );
  }
  return out;
}
