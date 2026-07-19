-- ============================================================
-- MegaCelulares · Esquema de base de datos para Supabase
-- Pegar y ejecutar este archivo completo en:
-- Supabase → SQL Editor → New query → Run
-- ============================================================

-- Necesario para generar IDs únicos
create extension if not exists "pgcrypto";

-- ---------- Tabla de clientes ----------
create table if not exists clients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  dni text,
  phone text,
  whatsapp text,
  created_at timestamptz not null default now()
);

-- Para que la búsqueda/autocompletado por DNI y nombre sea rápida
create index if not exists clients_dni_idx on clients (dni);
create index if not exists clients_name_idx on clients (lower(name));

-- Evita clientes duplicados con el mismo DNI (cuando el DNI está cargado)
create unique index if not exists clients_dni_unique
  on clients (dni) where dni is not null and dni <> '';

-- ---------- Secuencia + función para el código de orden (REP-2607-0001) ----------
create sequence if not exists repair_code_seq start 1;

create or replace function next_repair_code()
returns text
language plpgsql
as $$
declare
  n bigint;
begin
  n := nextval('repair_code_seq');
  return 'REP-' || to_char(now(), 'YYMM') || '-' || lpad(n::text, 4, '0');
end;
$$;

-- ---------- Tabla de reparaciones / órdenes ----------
create table if not exists repairs (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  client_id uuid not null references clients(id) on delete cascade,
  order_date date not null default current_date,
  brand text,
  model text,
  work_requested text,
  equipment_state text,
  imei text,
  serial text,
  pin text,
  type_presupuesto boolean not null default false,
  type_reparacion boolean not null default false,
  type_diagnostico boolean not null default false,
  monto text,
  senia text,
  garantia text not null default '30 días',
  due_date date,
  status text not null default 'Recibido',
  shop_name text not null default 'MegaCelulares',
  created_at timestamptz not null default now()
);

create index if not exists repairs_client_idx on repairs (client_id);
create index if not exists repairs_created_idx on repairs (created_at desc);

-- Si ya habías ejecutado una versión anterior de este schema (sin la columna
-- "serial"), corré esta línea aparte para agregarla sin perder datos:
-- alter table repairs add column if not exists serial text;


-- ============================================================
-- Seguridad: solo usuarios logueados (empleados de MegaCelulares)
-- pueden leer y escribir. Nadie anónimo puede tocar los datos.
-- ============================================================
alter table clients enable row level security;
alter table repairs enable row level security;

create policy "Usuarios logueados pueden ver clientes"
  on clients for select using (auth.role() = 'authenticated');
create policy "Usuarios logueados pueden crear clientes"
  on clients for insert with check (auth.role() = 'authenticated');
create policy "Usuarios logueados pueden editar clientes"
  on clients for update using (auth.role() = 'authenticated');

create policy "Usuarios logueados pueden ver ordenes"
  on repairs for select using (auth.role() = 'authenticated');
create policy "Usuarios logueados pueden crear ordenes"
  on repairs for insert with check (auth.role() = 'authenticated');
create policy "Usuarios logueados pueden editar ordenes"
  on repairs for update using (auth.role() = 'authenticated');
