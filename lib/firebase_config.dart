// Настройки Firebase для мгновенных уведомлений.
// Пока пусто, уведомления выключены. Все эти значения публичные.
//
// Для Android настройки берутся из файла android/app/google-services.json.
// Ниже настройки для веб-версии (iPhone):
const String kFbApiKey = 'AIzaSyBQooKnBM8n733FOC3Hs1kxHIpooKeF0-8';
const String kFbAppId = '1:922303308650:web:b1255ee10b893cb4fbbb13';
const String kFbMessagingSenderId = '922303308650';
const String kFbProjectId = 'project-8025729468275159558';
const String kFbAuthDomain = 'project-8025729468275159558.firebaseapp.com';
const String kFbStorageBucket =
    'project-8025729468275159558.firebasestorage.app';
// Публичный ключ веб-уведомлений (Cloud Messaging → Web Push certificates)
const String kFbVapidKey =
    'BH5UANqBRdDzJwcJqfRTCLA9T-i3ZcHQtUtnHYeFRjiZmn13fH9ukUIjab_tZOWHDiFaM3PoO2upliaoZ0fbPLA';

bool get webPushConfigured =>
    kFbApiKey.isNotEmpty &&
    kFbAppId.isNotEmpty &&
    kFbMessagingSenderId.isNotEmpty &&
    kFbProjectId.isNotEmpty &&
    kFbVapidKey.isNotEmpty;
