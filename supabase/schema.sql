-- Схема базы для приложения «Мы вдвоём».
-- Вставьте ВЕСЬ этот текст в Supabase: SQL Editor -> New query -> Run.
-- Можно запускать повторно, ничего не сломается.

create extension if not exists pgcrypto;

create table if not exists public.pairs (
  id uuid primary key default gen_random_uuid(),
  code text unique not null,
  created_at timestamptz not null default now()
);

create table if not exists public.members (
  id uuid primary key default gen_random_uuid(),
  pair_id uuid not null references public.pairs(id) on delete cascade,
  user_id uuid not null,
  name text not null,
  color bigint not null,
  created_at timestamptz not null default now()
);
create index if not exists members_pair_idx on public.members(pair_id);
create index if not exists members_user_idx on public.members(user_id);

-- Все данные пары (смены, дела, покупки...) лежат в одной таблице.
create table if not exists public.records (
  id uuid primary key,
  pair_id uuid not null references public.pairs(id) on delete cascade,
  kind text not null,
  data jsonb not null default '{}'::jsonb,
  updated_by uuid,
  updated_at timestamptz not null default now()
);
create index if not exists records_pair_idx on public.records(pair_id);
alter table public.records replica identity full;
alter table public.members replica identity full;

create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

drop trigger if exists records_touch on public.records;
create trigger records_touch before insert or update on public.records
for each row execute function public.touch_updated_at();

-- Проверка: «этот пользователь состоит в этой паре»
create or replace function public.is_my_pair(p uuid) returns boolean
language sql security definer stable set search_path = public as $$
  select exists (select 1 from public.members m where m.pair_id = p and m.user_id = auth.uid())
$$;

alter table public.pairs enable row level security;
alter table public.members enable row level security;
alter table public.records enable row level security;

drop policy if exists pairs_select on public.pairs;
create policy pairs_select on public.pairs for select to authenticated
  using (public.is_my_pair(id));

drop policy if exists members_select on public.members;
create policy members_select on public.members for select to authenticated
  using (public.is_my_pair(pair_id));

drop policy if exists members_update on public.members;
create policy members_update on public.members for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists records_all on public.records;
create policy records_all on public.records for all to authenticated
  using (public.is_my_pair(pair_id)) with check (public.is_my_pair(pair_id));

-- Код пары: 6 символов без похожих (нет 0/O, 1/I)
create or replace function public.gen_pair_code() returns text
language plpgsql as $$
declare
  chars text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  result text := '';
  i int;
begin
  for i in 1..6 loop
    result := result || substr(chars, 1 + floor(random() * length(chars))::int, 1);
  end loop;
  return result;
end $$;

create or replace function public.create_pair(p_name text, p_color bigint) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_code text;
  v_pair uuid;
  v_member uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  loop
    v_code := public.gen_pair_code();
    exit when not exists (select 1 from public.pairs where code = v_code);
  end loop;
  insert into public.pairs(code) values (v_code) returning id into v_pair;
  insert into public.members(pair_id, user_id, name, color)
    values (v_pair, auth.uid(), p_name, p_color) returning id into v_member;
  return json_build_object('pair_id', v_pair, 'code', v_code, 'member_id', v_member);
end $$;

create or replace function public.find_pair(p_code text) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_pair public.pairs;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_pair from public.pairs where code = upper(trim(p_code));
  if not found then return null; end if;
  return json_build_object(
    'pair_id', v_pair.id,
    'code', v_pair.code,
    'members', coalesce((select json_agg(json_build_object('id', m.id, 'name', m.name, 'color', m.color) order by m.created_at)
                         from public.members m where m.pair_id = v_pair.id), '[]'::json)
  );
end $$;

create or replace function public.join_pair(p_code text, p_name text, p_color bigint) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_pair public.pairs;
  v_member uuid;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_pair from public.pairs where code = upper(trim(p_code));
  if not found then raise exception 'pair_not_found'; end if;
  if (select count(*) from public.members where pair_id = v_pair.id) >= 2 then
    raise exception 'pair_full';
  end if;
  insert into public.members(pair_id, user_id, name, color)
    values (v_pair.id, auth.uid(), p_name, p_color) returning id into v_member;
  return json_build_object('pair_id', v_pair.id, 'code', v_pair.code, 'member_id', v_member);
end $$;

-- Вход после переустановки: «я — это уже существующий участник пары»
create or replace function public.claim_member(p_code text, p_member_id uuid) returns json
language plpgsql security definer set search_path = public as $$
declare
  v_pair public.pairs;
begin
  if auth.uid() is null then raise exception 'not_authenticated'; end if;
  select * into v_pair from public.pairs where code = upper(trim(p_code));
  if not found then raise exception 'pair_not_found'; end if;
  update public.members set user_id = auth.uid()
    where id = p_member_id and pair_id = v_pair.id;
  if not found then raise exception 'member_not_found'; end if;
  return json_build_object('pair_id', v_pair.id, 'code', v_pair.code, 'member_id', p_member_id);
end $$;

grant execute on function public.create_pair(text, bigint) to authenticated;
grant execute on function public.find_pair(text) to authenticated;
grant execute on function public.join_pair(text, text, bigint) to authenticated;
grant execute on function public.claim_member(text, uuid) to authenticated;

-- Мгновенные обновления у второго телефона
do $$
begin
  begin alter publication supabase_realtime add table public.records; exception when duplicate_object then null; end;
  begin alter publication supabase_realtime add table public.members; exception when duplicate_object then null; end;
end $$;

-- ===== Виджет для iPhone через Scriptable (бесплатно) =====
-- Приложение кладёт сюда готовые тексты, а виджет их забирает по коду пары.
create table if not exists public.widget_cache (
  member_id uuid primary key references public.members(id) on delete cascade,
  pair_id uuid not null references public.pairs(id) on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);
alter table public.widget_cache enable row level security;

drop policy if exists widget_cache_all on public.widget_cache;
create policy widget_cache_all on public.widget_cache for all to authenticated
  using (public.is_my_pair(pair_id)) with check (public.is_my_pair(pair_id));

create or replace function public.get_widget(p_code text, p_member uuid) returns jsonb
language sql security definer stable set search_path = public as $$
  select w.data
  from public.widget_cache w
  join public.pairs p on p.id = w.pair_id
  where p.code = upper(trim(p_code)) and w.member_id = p_member
$$;

grant execute on function public.get_widget(text, uuid) to anon, authenticated;
