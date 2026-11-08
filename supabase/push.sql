-- Запускать ОДИН РАЗ, после того как в Supabase создана функция «push»
-- (см. docs/PUSH.md). После любого изменения записи вызывает функцию,
-- которая отправляет партнёру уведомление.
-- Если ошибка «schema supabase_functions does not exist»: включите
-- Database -> Webhooks -> Enable webhooks и запустите ещё раз.

drop trigger if exists push_on_records on public.records;
create trigger push_on_records
  after insert or update on public.records
  for each row
  execute function supabase_functions.http_request(
    'https://vudeuntdodzktyzmbjqy.supabase.co/functions/v1/push',
    'POST',
    '{"Content-Type":"application/json"}',
    '{}',
    '5000'
  );
