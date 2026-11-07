// Настройки сервера синхронизации (Supabase).
// URL и "anon key" — публичные значения, их безопасно хранить в коде.
// Пока пусто — приложение работает только на этом телефоне, без пары.
const String _defaultUrl = '';
const String _defaultAnonKey = '';

const String kSupabaseUrl =
    String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl);
const String kSupabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultAnonKey);
