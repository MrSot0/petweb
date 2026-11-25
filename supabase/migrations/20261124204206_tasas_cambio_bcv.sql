create table if not exists public.tasas_cambio (
  id bigint generated always as identity primary key,
  moneda text not null check (moneda in ('EUR','USD')),
  tipo text not null default 'buy' check (tipo in ('buy','sell')),
  valor numeric(20,8) not null check (valor > 0),
  fecha_valor date not null,
  fuente text not null default 'BCV',
  proveedor text not null default 'allratestoday',
  manual boolean not null default false,
  creado_por uuid references auth.users(id),
  motivo text,
  obtenida_at timestamptz not null default now(),
  unique (moneda, tipo, fecha_valor, manual)
);
comment on table public.tasas_cambio is 'Tasas oficiales BCV (Bs por unidad de moneda). Escritura solo por la Edge Function tasa-bcv (service role) o carga manual del admin.';

create table if not exists public.tasa_consultas (
  id bigint generated always as identity primary key,
  consultada_at timestamptz not null default now(),
  ok boolean not null,
  http_status int,
  detalle text
);
comment on table public.tasa_consultas is 'Bitacora de llamadas a la API de tasas; sirve para limitar consultas y diagnosticar fallos.';

alter table public.tasas_cambio enable row level security;
alter table public.tasa_consultas enable row level security;

-- La tasa oficial es informacion publica: cualquiera puede leerla.
create policy "tasas: lectura publica" on public.tasas_cambio
  for select to anon, authenticated using (true);
-- tasa_consultas: sin politicas => solo service role.

create or replace view public.tasa_vigente with (security_invoker = true) as
select distinct on (moneda, tipo)
  moneda, tipo, valor, fecha_valor, fuente, manual, obtenida_at
from public.tasas_cambio
order by moneda, tipo, fecha_valor desc, manual asc, obtenida_at desc;

grant select on public.tasa_vigente to anon, authenticated;
