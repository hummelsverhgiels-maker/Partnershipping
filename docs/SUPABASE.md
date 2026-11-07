# Подключение сервера синхронизации (Supabase)

Все шаги можно сделать с телефона или компьютера, в браузере.

1. Откройте https://supabase.com → **Start your project** → войдите через GitHub.
2. **New project**: имя `partnershipping`, придумайте пароль базы (сохраните), регион ближайший (Frankfurt),
   тариф Free. Подождите 1–2 минуты.
3. Слева **SQL Editor → New query**. Вставьте весь текст файла `supabase/schema.sql` → **Run**. Должно быть `Success`.
4. Слева **Authentication → Sign In / Providers** → включите **Allow anonymous sign-ins** → **Save**.
5. Слева **Project Settings → API Keys** (или Data API). Скопируйте:
   - **Project URL** (вида `https://abcd.supabase.co`);
   - **Publishable key** (`sb_publishable_...`) либо **anon public** key (длинный, начинается с `eyJ`).
   Эти два значения публичные, их можно присылать в чат.
6. Пришлите их мне, я вставлю в `lib/config.dart`, и следующая сборка уже будет с синхронизацией.
