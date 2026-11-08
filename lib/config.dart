// Настройки сервера синхронизации (Supabase).
// URL и "anon key" — публичные значения, их безопасно хранить в коде.
// Пока пусто — приложение работает только на этом телефоне, без пары.
const String _defaultUrl = 'https://vudeuntdodzktyzmbjqy.supabase.co';
const String _defaultAnonKey = 'sb_publishable_uDBVh1eKO5IhVkZFzGPueQ_yVMPpIZl';

const String kSupabaseUrl =
    String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl);
const String kSupabaseAnonKey =
    String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultAnonKey);
