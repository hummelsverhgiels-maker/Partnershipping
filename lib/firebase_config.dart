// Настройки Firebase для мгновенных уведомлений.
// Пока пусто, уведомления выключены. Все эти значения публичные.
//
// Для Android настройки берутся из файла android/app/google-services.json.
// Ниже настройки для веб-версии (iPhone):
const String kFbApiKey = '';
const String kFbAppId = '';
const String kFbMessagingSenderId = '';
const String kFbProjectId = '';
const String kFbAuthDomain = '';
const String kFbStorageBucket = '';
// Публичный ключ веб-уведомлений (Cloud Messaging → Web Push certificates)
const String kFbVapidKey = '';

bool get webPushConfigured =>
    kFbApiKey.isNotEmpty &&
    kFbAppId.isNotEmpty &&
    kFbMessagingSenderId.isNotEmpty &&
    kFbProjectId.isNotEmpty &&
    kFbVapidKey.isNotEmpty;
