import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../data/store.dart';
import '../firebase_config.dart';

/// Мгновенные уведомления через Firebase Cloud Messaging.
/// Android: обычные пуши. Веб-версия на iPhone: веб-пуши (нужен iOS 16.4+ и иконка на «Домой»).
class PushService {
  static bool _active = false;
  static final ValueNotifier<bool> activeNotifier = ValueNotifier(false);

  static bool get active => _active;
  static set active(bool v) {
    _active = v;
    activeNotifier.value = v;
  }

  static String? _lastKey;

  static String get platform => kIsWeb ? 'web' : 'android';

  static Future<void> init(AppStore store) async {
    try {
      if (kIsWeb) {
        if (!webPushConfigured) return;
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: kFbApiKey,
            appId: kFbAppId,
            messagingSenderId: kFbMessagingSenderId,
            projectId: kFbProjectId,
            authDomain: kFbAuthDomain,
            storageBucket: kFbStorageBucket,
          ),
        );
      } else if (Platform.isAndroid) {
        await Firebase.initializeApp();
      } else {
        return;
      }
      active = true;
      // ignore: deprecated_member_use
      FirebaseMessaging.instance.onTokenRefresh.listen((t) {
        _lastKey = null;
        sync(store);
      });
    } catch (e) {
      active = false;
      debugPrint('Мгновенные уведомления выключены: $e');
    }
  }

  /// Разрешено ли показывать уведомления (на вебе нужно нажатие пользователя).
  static Future<bool> permissionGranted() async {
    if (!active) return false;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return false;
    }
  }

  /// Спросить разрешение (на iPhone вызывать только по нажатию кнопки).
  static Future<bool> requestPermission(AppStore store) async {
    if (!active) return false;
    try {
      final s = await FirebaseMessaging.instance.requestPermission();
      final ok =
          s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
      if (ok) {
        _lastKey = null;
        await sync(store);
      }
      return ok;
    } catch (e) {
      debugPrint('Разрешение на уведомления: $e');
      return false;
    }
  }

  /// Отправить токен этого устройства на сервер (если уже есть разрешение).
  static Future<void> sync(AppStore store) async {
    if (!active || !store.hasSession || store.isLocal) return;
    if (!await permissionGranted()) return;
    try {
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey: kIsWeb ? kFbVapidKey : null,
      );
      if (token == null) return;
      final key = '$token|${store.session!.memberId}';
      if (key == _lastKey) return;
      await store.registerDevice(token, platform);
      _lastKey = key;
    } catch (e) {
      debugPrint('Токен уведомлений не получен: $e');
    }
  }
}
