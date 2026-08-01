-- ============================================================================
-- Migración 12 — Ícono por categoría
-- ----------------------------------------------------------------------------
-- Para DBs EXISTENTES con datos. (Para una DB limpia, usar schema.sql.)
-- Agrega la columna `icon` y asigna un ícono coherente por nombre a las
-- categorías ya creadas; el resto queda con el default 'help'.
-- ============================================================================

-- 1) Columna nueva (no nula, con default de fallback).
alter table public.categories
  add column if not exists icon text not null default 'help';

-- 2) Asignación por match de nombre para las categorías existentes.
update public.categories set icon = 'bus'    where name = 'Transporte';
update public.categories set icon = 'fork'   where name = 'Comida';
update public.categories set icon = 'basket' where name = 'Almacén';
update public.categories set icon = 'bolt'   where name = 'Servicios';
update public.categories set icon = 'heart'  where name = 'Salud';
update public.categories set icon = 'movie'  where name = 'Ocio';
update public.categories set icon = 'help'   where name = 'Otros';
