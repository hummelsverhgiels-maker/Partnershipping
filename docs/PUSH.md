# Мгновенные уведомления (Firebase + Supabase)

Порядок действий подробно расписан в чате. Здесь коротко, что где лежит:

- `supabase/schema.sql` — таблицы `devices`, `push_log` (запустить в SQL Editor, можно повторно).
- `supabase/functions/push/index.ts` — код функции «push» (вставить в Supabase → Edge Functions).
- `supabase/push.sql` — триггер, который вызывает функцию (запустить один раз после функции).
- Секрет `FCM_SERVICE_ACCOUNT` (Edge Functions → Secrets) — содержимое JSON-файла ключа
  из Firebase (Project settings → Service accounts → Generate new private key).
  Это секрет: никому не присылать, вставлять только в Supabase.
- `android/app/google-services.json` и `lib/firebase_config.dart` — публичные настройки Firebase.
