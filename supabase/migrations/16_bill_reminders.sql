-- ============================================================================
-- Migración 16 — Recordatorios de facturas (bill_reminders)
-- ----------------------------------------------------------------------------
-- Para DBs EXISTENTES con datos. (Para una DB limpia, usar schema.sql.)
-- Crea la tabla de recordatorios de facturas a pagar, fuente de verdad de las
-- notificaciones locales (que son un reflejo device-local). El botón PAGO crea
-- un expense normal por la capa existente; esta migración NO toca expenses ni
-- categories. RLS por user_id (auth.uid() = user_id).
-- ============================================================================

create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- Tabla: bill_reminders
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

-- ----------------------------------------------------------------------------
-- RLS + Policies (auth.uid() = user_id): cada usuario solo ve/gestiona los suyos.
-- ----------------------------------------------------------------------------
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
