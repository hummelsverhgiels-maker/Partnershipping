-- Запускать ОДИН РАЗ, после того как в Supabase создана функция «push»
-- (см. docs/PUSH.md). После любого изменения записи вызывает функцию,
-- которая отправляет партнёру уведомление.
-- Не требует включённых «вебхуков»: вызов делает напрямую расширение pg_net.

create extension if not exists pg_net;

create or replace function public.notify_push() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://vudeuntdodzktyzmbjqy.supabase.co/functions/v1/push',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body := jsonb_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', to_jsonb(NEW)
    ),
    timeout_milliseconds := 5000
  );
  return new;
exception when others then
  -- уведомление не должно ломать сохранение данных
  return new;
end $$;

drop trigger if exists push_on_records on public.records;
create trigger push_on_records
  after insert or update on public.records
  for each row execute function public.notify_push();
