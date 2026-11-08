import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../data/store.dart';
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

  /// Перепланировать все напоминания за день до выплат (на 90 дней вперёд).
  static Future<void> reschedulePay(AppStore store) async {
    if (!_ready) return;
    try {
      await _plugin.cancelAllPendingNotifications();
      if (!store.getFlag('notif_pay')) return;
      final today = dateOnly(DateTime.now());
      final items = store.schedule
          .paymentsInRange(today, addDays(today, 90))
          .where((p) => store.memberById(p.memberId) != null);
      var id = 1000;
      for (final p in items) {
        final remindDay = addDays(p.date, -1);
        final when = tz.TZDateTime(
          tz.local,
          remindDay.year,
          remindDay.month,
          remindDay.day,
          9,
        );
        if (!when.isAfter(tz.TZDateTime.now(tz.local))) continue;
        final mine = p.memberId == store.session?.memberId;
        final who = mine ? '' : ' у ${store.memberById(p.memberId)!.name}';
        final label = p.label.toLowerCase();
        await _plugin.zonedSchedule(
          id: id++,
          scheduledDate: when,
          notificationDetails: const NotificationDetails(
            android: _payChannel,
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          title: 'Завтра $label$who',
          body: p.shifted
              ? 'Выплата перенесена с ${p.nominal.day}-го числа на ближайший рабочий день.'
              : 'Не забудьте: завтра выплата.',
        );
      }
    } catch (e) {
      debugPrint('Не удалось запланировать напоминания: $e');
    }
  }

  static Future<void> showPartnerChange(
    String who,
    Set<String> cats, {
    String? lastMessage,
  }) async {
    if (!_ready) return;
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
