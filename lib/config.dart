// Настройки сервера синхронизации (Supabase).
// URL и "anon key" — публичные значения, их безопасно хранить в коде.
// Пока пусто — приложение работает только на этом телефоне, без пары.
const String _defaultUrl = 'https://vudeuntdodzktyzmbjqy.supabase.co';
const String _defaultAnonKey = 'sb_publishable_uDBVh1eKO5IhVkZFzGPueQ_yVMPpIZl';

const String kSupabaseUrl = String.fromEnvironment(
  'SUPABASE_URL',
  defaultValue: _defaultUrl,
);
const String kSupabaseAnonKey = String.fromEnvironment(
  'SUPABASE_ANON_KEY',
  defaultValue: _defaultAnonKey,
);

// Запасной путь к серверу (посредник на Cloudflare). Нужен там, где обычный
// адрес Supabase блокируется провайдером. Приложение само выберет, какой работает.
const String kSupabaseProxyUrl =
    'https://vv-proxy.hummelsverhgiels.workers.dev';

// Номер сборки (подставляется при сборке в облаке), чтобы видеть, какая версия запущена.
const String kBuild = String.fromEnvironment('APP_BUILD', defaultValue: 'dev');
