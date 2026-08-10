-- ============================================================================
-- gdm_app — Schema consolidado para Supabase (Postgres)
-- ----------------------------------------------------------------------------
-- Script idempotente y consolidado. Se corre UNA vez sobre una DB limpia.
-- Incluye: tablas categories/expenses, constraints, función delete_category,
-- trigger on_auth_user_created (siembra 7 categorías default), RLS + policies.
-- No contiene datos viejos ni UUIDs hardcodeados.
-- ============================================================================

-- Extensión para gen_random_uuid()
create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- Tabla: categories
-- ----------------------------------------------------------------------------
create table if not exists public.categories (
  id           uuid        primary key default gen_random_uuid(),
  name         text        not null,
  color        text        not null,
  icon         text        not null default 'help',
  is_deletable boolean     not null default true,
  user_id      uuid        not null references auth.users (id) on delete cascade,
  created_at   timestamptz not null default now(),
  constraint categories_user_name_unique unique (user_id, name)
);

-- ----------------------------------------------------------------------------
-- Tabla: expenses
-- ----------------------------------------------------------------------------
create table if not exists public.expenses (
  id          uuid           primary key default gen_random_uuid(),
  description text           not null,
  amount      numeric(12, 2) not null check (amount > 0),
  date        date           not null,
  category_id uuid           not null references public.categories (id) on delete restrict,
  user_id     uuid           not null references auth.users (id) on delete cascade,
  created_at  timestamptz    not null default now()
);

create index if not exists expenses_user_date_idx on public.expenses (user_id, date);
create index if not exists expenses_category_idx on public.expenses (category_id);

-- ----------------------------------------------------------------------------
-- Función: delete_category
-- Reasigna los gastos de la categoría a "Otros" del mismo usuario y borra
-- la categoría. security definer + search_path para invocación vía RPC.
-- ----------------------------------------------------------------------------
create or replace function public.delete_category(
  p_category_id uuid,
  p_otros_id    uuid
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  -- Reasignar gastos a "Otros"
  update public.expenses
     set category_id = p_otros_id
   where category_id = p_category_id
     and user_id = auth.uid();

  -- Borrar la categoría (solo si es del usuario y es borrable)
  delete from public.categories
   where id = p_category_id
     and user_id = auth.uid()
     and is_deletable = true;
end;
$$;

-- ----------------------------------------------------------------------------
-- Función + Trigger: siembra de categorías default al crear un usuario
-- ----------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.categories (name, color, icon, is_deletable, user_id)
  values
    ('Almacén',    '#FF6B6B', 'basket', true,  new.id),
    ('Comida',     '#FFD93D', 'fork',   true,  new.id),
    ('Transporte', '#4D96FF', 'bus',    true,  new.id),
    ('Servicios',  '#C77DFF', 'bolt',   true,  new.id),
    ('Salud',      '#6BCB77', 'heart',  true,  new.id),
    ('Ocio',       '#00C9A7', 'movie',  true,  new.id),
    ('Otros',      '#FF9A3C', 'help',   false, new.id);
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ----------------------------------------------------------------------------
-- RLS + Policies
-- ----------------------------------------------------------------------------
alter table public.categories enable row level security;
alter table public.expenses   enable row level security;

drop policy if exists categories_owner_all on public.categories;
create policy categories_owner_all
  on public.categories
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists expenses_owner_all on public.expenses;
create policy expenses_owner_all
  on public.expenses
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================================================
-- Gastos compartidos (spec 14): partnerships / partner_invites / shared_expenses
-- Vínculo 1-a-1 entre usuarios por código de invitación. No toca categories/
-- expenses ni el cálculo de totales personales.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- Tabla: partnerships (vínculo 1-a-1, orden normalizado, soft-unlink)
-- ----------------------------------------------------------------------------
create table if not exists public.partnerships (
  id             uuid        primary key default gen_random_uuid(),
  user_low       uuid        not null references auth.users (id) on delete cascade,
  user_high      uuid        not null references auth.users (id) on delete cascade,
  user_low_name  text        not null,
  user_high_name text        not null,
  created_at     timestamptz not null default now(),
  unlinked_at    timestamptz,
  constraint partnerships_order check (user_low < user_high)
);

-- Solo un vínculo ACTIVO por usuario (permite re-vincularse tras desvincular).
create unique index if not exists partnerships_one_active_low
  on public.partnerships (user_low) where unlinked_at is null;
create unique index if not exists partnerships_one_active_high
  on public.partnerships (user_high) where unlinked_at is null;

-- ----------------------------------------------------------------------------
-- Tabla: partner_invites (código efímero, uno pendiente por invitador)
-- ----------------------------------------------------------------------------
create table if not exists public.partner_invites (
  id           uuid        primary key default gen_random_uuid(),
  code         text        not null unique,
  inviter_id   uuid        not null references auth.users (id) on delete cascade,
  inviter_name text        not null,
  created_at   timestamptz not null default now(),
  expires_at   timestamptz not null default (now() + interval '7 days'),
  consumed_at  timestamptz
);

create unique index if not exists partner_invites_one_pending_per_inviter
  on public.partner_invites (inviter_id) where consumed_at is null;

-- ----------------------------------------------------------------------------
-- Tabla: shared_expenses
-- ----------------------------------------------------------------------------
create table if not exists public.shared_expenses (
  id             uuid           primary key default gen_random_uuid(),
  partnership_id uuid           not null references public.partnerships (id) on delete cascade,
  description    text           not null,
  amount         numeric(12, 2) not null check (amount > 0),
  date           date           not null,
  paid_by        uuid           not null references auth.users (id),
  created_by     uuid           not null references auth.users (id),
  created_at     timestamptz    not null default now()
);

create index if not exists shared_expenses_partnership_date_idx
  on public.shared_expenses (partnership_id, date);

-- ----------------------------------------------------------------------------
-- Helper de pertenencia (para RLS). NO filtra unlinked_at: ambos miembros
-- conservan lectura del histórico archivado.
-- ----------------------------------------------------------------------------
create or replace function public.is_partner_member(p_partnership_id uuid)
returns boolean
language sql
security definer
set search_path = public
stable
as $$
  select exists (
    select 1 from public.partnerships p
    where p.id = p_partnership_id
      and auth.uid() in (p.user_low, p.user_high)
  );
$$;

-- ----------------------------------------------------------------------------
-- RPC: create_partner_invite — genera (o reusa) el código pendiente del user
-- Alfabeto no ambiguo (A–Z sin I/O + 2–9), 8 chars, unicidad garantizada.
-- ----------------------------------------------------------------------------
create or replace function public.create_partner_invite()
returns public.partner_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid     uuid := auth.uid();
  v_name    text;
  v_alpha   text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  v_code    text;
  v_invite  public.partner_invites;
  v_i       int;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  if exists (
    select 1 from public.partnerships p
    where p.unlinked_at is null and v_uid in (p.user_low, p.user_high)
  ) then
    raise exception 'already_linked';
  end if;

  v_name := coalesce(
    (select raw_user_meta_data ->> 'full_name' from auth.users where id = v_uid),
    'Usuario'
  );

  select * into v_invite from public.partner_invites
   where inviter_id = v_uid and consumed_at is null and expires_at > now()
   limit 1;
  if found then
    return v_invite;
  end if;

  delete from public.partner_invites
   where inviter_id = v_uid and consumed_at is null;

  loop
    v_code := '';
    for v_i in 1..8 loop
      v_code := v_code || substr(v_alpha, 1 + floor(random() * length(v_alpha))::int, 1);
    end loop;
    begin
      insert into public.partner_invites (code, inviter_id, inviter_name)
      values (v_code, v_uid, v_name)
      returning * into v_invite;
      return v_invite;
    exception when unique_violation then
      -- colisión de code: reintentar
    end;
  end loop;
end;
$$;

-- ----------------------------------------------------------------------------
-- RPC: accept_partner_invite — consume el invite y crea el partnership
-- ----------------------------------------------------------------------------
create or replace function public.accept_partner_invite(p_code text)
returns public.partnerships
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid        uuid := auth.uid();
  v_name       text;
  v_invite     public.partner_invites;
  v_low        uuid;
  v_high       uuid;
  v_low_name   text;
  v_high_name  text;
  v_partnership public.partnerships;
begin
  if v_uid is null then
    raise exception 'not_authenticated';
  end if;

  select * into v_invite from public.partner_invites
   where code = upper(trim(p_code));
  if not found then
    raise exception 'invite_invalid';
  end if;
  if v_invite.consumed_at is not null then
    raise exception 'invite_used';
  end if;
  if v_invite.expires_at <= now() then
    raise exception 'invite_expired';
  end if;
  if v_invite.inviter_id = v_uid then
    raise exception 'invite_self';
  end if;

  if exists (
    select 1 from public.partnerships p
    where p.unlinked_at is null
      and (v_uid in (p.user_low, p.user_high)
           or v_invite.inviter_id in (p.user_low, p.user_high))
  ) then
    raise exception 'already_linked';
  end if;

  v_name := coalesce(
    (select raw_user_meta_data ->> 'full_name' from auth.users where id = v_uid),
    'Usuario'
  );

  if v_invite.inviter_id < v_uid then
    v_low := v_invite.inviter_id; v_low_name := v_invite.inviter_name;
    v_high := v_uid;              v_high_name := v_name;
  else
    v_low := v_uid;               v_low_name := v_name;
    v_high := v_invite.inviter_id; v_high_name := v_invite.inviter_name;
  end if;

  insert into public.partnerships (user_low, user_high, user_low_name, user_high_name)
  values (v_low, v_high, v_low_name, v_high_name)
  returning * into v_partnership;

  update public.partner_invites set consumed_at = now() where id = v_invite.id;

  return v_partnership;
end;
$$;

-- ----------------------------------------------------------------------------
-- RLS + Policies (gastos compartidos)
-- ----------------------------------------------------------------------------
alter table public.partnerships    enable row level security;
alter table public.partner_invites enable row level security;
alter table public.shared_expenses enable row level security;

drop policy if exists partnerships_member_select on public.partnerships;
create policy partnerships_member_select
  on public.partnerships
  for select
  using (auth.uid() in (user_low, user_high));

drop policy if exists partnerships_member_update on public.partnerships;
create policy partnerships_member_update
  on public.partnerships
  for update
  using (auth.uid() in (user_low, user_high))
  with check (auth.uid() in (user_low, user_high));

drop policy if exists partner_invites_owner_select on public.partner_invites;
create policy partner_invites_owner_select
  on public.partner_invites
  for select
  using (auth.uid() = inviter_id);

drop policy if exists partner_invites_owner_delete on public.partner_invites;
create policy partner_invites_owner_delete
  on public.partner_invites
  for delete
  using (auth.uid() = inviter_id);

drop policy if exists shared_expenses_member_select on public.shared_expenses;
create policy shared_expenses_member_select
  on public.shared_expenses
  for select
  using (public.is_partner_member(partnership_id));

drop policy if exists shared_expenses_member_insert on public.shared_expenses;
create policy shared_expenses_member_insert
  on public.shared_expenses
  for insert
  with check (
    public.is_partner_member(partnership_id)
    and created_by = auth.uid()
    and exists (
      select 1 from public.partnerships p
      where p.id = partnership_id
        and p.unlinked_at is null
        and paid_by in (p.user_low, p.user_high)
    )
  );

drop policy if exists shared_expenses_member_update on public.shared_expenses;
create policy shared_expenses_member_update
  on public.shared_expenses
  for update
  using (public.is_partner_member(partnership_id))
  with check (
    public.is_partner_member(partnership_id)
    and exists (
      select 1 from public.partnerships p
      where p.id = partnership_id
        and p.unlinked_at is null
        and paid_by in (p.user_low, p.user_high)
    )
  );

drop policy if exists shared_expenses_member_delete on public.shared_expenses;
create policy shared_expenses_member_delete
  on public.shared_expenses
  for delete
  using (public.is_partner_member(partnership_id));

-- ----------------------------------------------------------------------------
-- Tabla: bill_reminders (recordatorios de facturas — spec 16)
-- Fuente de verdad de las notificaciones locales (reflejo device-local). El
-- botón PAGO crea un expense normal por la capa existente. RLS por user_id.
-- ----------------------------------------------------------------------------
create table if not exists public.bill_reminders (
  id             uuid           primary key default gen_random_uuid(),
  user_id        uuid           not null references auth.users (id) on delete cascade,
  name           text           not null,
  kind           text           not null check (kind in ('service', 'card', 'debt')),
  amount         numeric(12, 2) not null check (amount > 0),
  category_id    uuid           not null references public.categories (id),
  start_day      int            not null check (start_day between 1 and 31),
  due_day        int            not null check (due_day between 1 and 31),
  notify_hour    int            not null check (notify_hour between 0 and 23),
  notify_minute  int            not null check (notify_minute between 0 and 59),
  persistent     boolean        not null default false,
  repeat_monthly boolean        not null default true,
  paid_cycle     text,
  active         boolean        not null default true,
  created_at     timestamptz    not null default now(),
  updated_at     timestamptz    not null default now()
);

create index if not exists bill_reminders_user_idx on public.bill_reminders (user_id);

alter table public.bill_reminders enable row level security;

drop policy if exists bill_reminders_owner_select on public.bill_reminders;
create policy bill_reminders_owner_select
  on public.bill_reminders
  for select
  using (auth.uid() = user_id);

drop policy if exists bill_reminders_owner_insert on public.bill_reminders;
create policy bill_reminders_owner_insert
  on public.bill_reminders
  for insert
  with check (auth.uid() = user_id);

drop policy if exists bill_reminders_owner_update on public.bill_reminders;
create policy bill_reminders_owner_update
  on public.bill_reminders
  for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists bill_reminders_owner_delete on public.bill_reminders;
create policy bill_reminders_owner_delete
  on public.bill_reminders
  for delete
  using (auth.uid() = user_id);
