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
