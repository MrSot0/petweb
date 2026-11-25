-- ============ Tipos ============
create type public.rol_app as enum ('propietario','cirujano','contador','admin');
create type public.especie as enum ('perro','gato');
create type public.sexo as enum ('macho','hembra');
create type public.servicio as enum ('esterilizacion','limpieza_dental');
create type public.estado_jornada as enum ('borrador','publicada','cerrada','finalizada','cancelada');
create type public.estado_inscripcion as enum ('precio_por_confirmar','pendiente_pago','pago_en_revision','confirmada','atendida','cancelada');
create type public.metodo_pago as enum ('pago_movil','efectivo_divisa');
create type public.estado_pago as enum ('pendiente','verificado','rechazado','anulado');

-- ============ Perfiles y roles ============
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  nombre text not null default '',
  cedula text,
  telefono text,
  email text,
  created_at timestamptz not null default now()
);
create table public.user_roles (
  user_id uuid not null references public.profiles(id) on delete cascade,
  rol public.rol_app not null,
  asignado_por uuid references public.profiles(id),
  asignado_at timestamptz not null default now(),
  primary key (user_id, rol)
);

create or replace function public.has_role(r public.rol_app)
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and rol = r);
$$;
create or replace function public.is_staff()
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.user_roles where user_id = auth.uid() and rol in ('admin','contador'));
$$;

create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.profiles (id, nombre, cedula, telefono, email)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'nombre',''),
          new.raw_user_meta_data->>'cedula',
          new.raw_user_meta_data->>'telefono',
          new.email);
  insert into public.user_roles (user_id, rol) values (new.id, 'propietario');
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============ Mascotas ============
create table public.pets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null default auth.uid() references public.profiles(id) on delete cascade,
  nombre text not null check (length(nombre) between 1 and 40),
  especie public.especie not null,
  sexo public.sexo not null,
  edad_meses int check (edad_meses between 0 and 360),
  peso_kg numeric(4,1) check (peso_kg > 0 and peso_kg < 120),
  braquiocefalico boolean not null default false,
  esterilizada boolean not null default false,
  notas text,
  created_at timestamptz not null default now(),
  constraint perro_con_peso check (especie = 'gato' or peso_kg is not null)
);
create index on public.pets(owner_id);

-- ============ Precios (lista oficial, editable por admin) ============
create table public.precios (
  id bigint generated always as identity primary key,
  servicio public.servicio not null,
  especie public.especie not null,
  sexo public.sexo,                 -- null = aplica a ambos
  peso_hasta numeric(4,1),          -- null = sin limite de peso
  precio_usd numeric(8,2) not null check (precio_usd >= 0)
);
create table public.precios_extras (
  extra text not null check (extra in ('kit','cono')),
  especie public.especie not null,
  precio_usd numeric(8,2) not null check (precio_usd >= 0),
  primary key (extra, especie)
);

insert into public.precios (servicio, especie, sexo, peso_hasta, precio_usd) values
 ('esterilizacion','gato','macho',null,10),('esterilizacion','gato','hembra',null,15),
 ('esterilizacion','perro','macho',5,25),('esterilizacion','perro','macho',10,30),('esterilizacion','perro','macho',15,35),
 ('esterilizacion','perro','macho',20,40),('esterilizacion','perro','macho',25,45),('esterilizacion','perro','macho',30,50),
 ('esterilizacion','perro','hembra',5,30),('esterilizacion','perro','hembra',10,35),('esterilizacion','perro','hembra',15,40),
 ('esterilizacion','perro','hembra',20,45),('esterilizacion','perro','hembra',25,50),('esterilizacion','perro','hembra',30,55),
 ('limpieza_dental','gato',null,null,20),
 ('limpieza_dental','perro',null,5,30),('limpieza_dental','perro',null,10,40),('limpieza_dental','perro',null,15,50),
 ('limpieza_dental','perro',null,20,60),('limpieza_dental','perro',null,25,70),('limpieza_dental','perro',null,30,80);
insert into public.precios_extras values ('kit','gato',5),('cono','gato',5),('kit','perro',7),('cono','perro',7);

-- Precio base; null = "precio a convenir" (perro > 30 kg, braquiocefalico)
create or replace function public.precio_base(p_servicio public.servicio, p_especie public.especie,
  p_sexo public.sexo, p_peso numeric, p_braqui boolean)
returns numeric language sql stable set search_path = '' as $$
  select case when p_braqui then null else (
    select precio_usd from public.precios
    where servicio = p_servicio and especie = p_especie
      and (sexo is null or sexo = p_sexo)
      and (peso_hasta is null or coalesce(p_peso, 0) <= peso_hasta)
    order by peso_hasta asc nulls last limit 1) end;
$$;

-- ============ Jornadas ============
create table public.jornadas (
  id uuid primary key default gen_random_uuid(),
  titulo text not null,
  descripcion text,
  fecha_inicio timestamptz not null,
  sede_nombre text not null,
  direccion text,
  ciudad text not null default 'Maracaibo',
  lat numeric(9,6) check (lat between -90 and 90),
  lng numeric(9,6) check (lng between -180 and 180),
  whatsapp_url text check (whatsapp_url is null or whatsapp_url ~ '^https://(chat\.whatsapp\.com|wa\.me)/'),
  cupos_total int not null check (cupos_total > 0),
  incluye_limpieza_dental boolean not null default false,
  estado public.estado_jornada not null default 'publicada',
  created_by uuid default auth.uid() references public.profiles(id),
  created_at timestamptz not null default now()
);

-- ============ Inscripciones y pagos ============
create sequence public.codigo_inscripcion_seq;
create table public.pagos (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references public.profiles(id),
  jornada_id uuid not null references public.jornadas(id),
  metodo public.metodo_pago not null,
  monto_usd numeric(10,2) not null check (monto_usd > 0),
  tasa_eur_bcv numeric(20,8),
  tasa_fecha date,
  monto_bs numeric(14,2),
  referencia text check (referencia is null or referencia ~ '^[0-9]{4,12}$'),
  telefono_emisor text check (telefono_emisor is null or telefono_emisor ~ '^0(412|414|416|422|424|426)[0-9]{7}$'),
  banco_emisor text,
  fecha_pago date not null default current_date,
  comprobante_path text,
  estado public.estado_pago not null default 'pendiente',
  motivo_rechazo text,
  verificado_por uuid references public.profiles(id),
  verificado_por_rol public.rol_app,
  verificado_at timestamptz,
  created_at timestamptz not null default now(),
  constraint pm_requiere_datos check (metodo <> 'pago_movil' or (referencia is not null and comprobante_path is not null))
);
create index on public.pagos(estado, created_at);
create index on public.pagos(owner_id);

create table public.inscripciones (
  id uuid primary key default gen_random_uuid(),
  jornada_id uuid not null references public.jornadas(id),
  pet_id uuid not null references public.pets(id),
  owner_id uuid not null references public.profiles(id),
  servicio public.servicio not null default 'esterilizacion',
  incluye_kit boolean not null default true,
  incluye_cono boolean not null default false,
  precio_base_usd numeric(8,2),
  precio_total_usd numeric(8,2),
  estado public.estado_inscripcion not null,
  pago_id uuid references public.pagos(id),
  codigo text not null unique,
  created_at timestamptz not null default now()
);
create unique index inscripcion_unica on public.inscripciones(jornada_id, pet_id, servicio) where estado <> 'cancelada';
create index on public.inscripciones(owner_id);
create index on public.inscripciones(jornada_id, estado);

create table public.pago_eventos (
  id bigint generated always as identity primary key,
  pago_id uuid not null references public.pagos(id) on delete cascade,
  de_estado public.estado_pago,
  a_estado public.estado_pago not null,
  actor_id uuid references public.profiles(id),
  actor_rol public.rol_app,
  nota text,
  created_at timestamptz not null default now()
);

-- Datos de cobro de la organizacion (los carga el admin)
create table public.datos_pago (
  id bigint generated always as identity primary key,
  tipo public.metodo_pago not null,
  banco text,
  telefono text,
  cedula_rif text,
  titular text,
  instrucciones text,
  activo boolean not null default true,
  orden int not null default 0
);

-- Vista de cupos (solo jornadas visibles)
create view public.jornadas_cupos with (security_invoker = true) as
select j.id as jornada_id,
       j.cupos_total - (select count(*) from public.inscripciones i
                        where i.jornada_id = j.id and i.estado <> 'cancelada') as cupos_libres
from public.jornadas j;

-- ============ RLS ============
alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.pets enable row level security;
alter table public.precios enable row level security;
alter table public.precios_extras enable row level security;
alter table public.jornadas enable row level security;
alter table public.inscripciones enable row level security;
alter table public.pagos enable row level security;
alter table public.pago_eventos enable row level security;
alter table public.datos_pago enable row level security;

create policy "perfil: leer propio o staff" on public.profiles for select to authenticated
  using (id = (select auth.uid()) or public.is_staff());
create policy "perfil: editar propio" on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

create policy "roles: leer propios o admin" on public.user_roles for select to authenticated
  using (user_id = (select auth.uid()) or public.has_role('admin'));

create policy "mascotas: dueno" on public.pets for all to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
create policy "mascotas: staff lee" on public.pets for select to authenticated
  using (public.is_staff() or public.has_role('cirujano'));

create policy "precios: lectura publica" on public.precios for select to anon, authenticated using (true);
create policy "precios: admin escribe" on public.precios for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));
create policy "extras: lectura publica" on public.precios_extras for select to anon, authenticated using (true);
create policy "extras: admin escribe" on public.precios_extras for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

create policy "jornadas: publicas visibles" on public.jornadas for select to anon, authenticated
  using (estado in ('publicada','cerrada','finalizada') or public.is_staff() or public.has_role('cirujano'));
create policy "jornadas: admin escribe" on public.jornadas for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));
-- El enlace de WhatsApp no se expone por columna: solo via rpc_whatsapp_jornada
revoke select on public.jornadas from anon, authenticated;
grant select (id, titulo, descripcion, fecha_inicio, sede_nombre, direccion, ciudad, lat, lng, cupos_total,
              incluye_limpieza_dental, estado, created_at) on public.jornadas to anon, authenticated;
grant select on public.jornadas_cupos to anon, authenticated;

create policy "inscripciones: dueno lee" on public.inscripciones for select to authenticated
  using (owner_id = (select auth.uid()) or public.is_staff() or public.has_role('cirujano'));
create policy "pagos: dueno o staff lee" on public.pagos for select to authenticated
  using (owner_id = (select auth.uid()) or public.is_staff());
create policy "eventos: dueno o staff lee" on public.pago_eventos for select to authenticated
  using (public.is_staff() or exists (select 1 from public.pagos p where p.id = pago_id and p.owner_id = (select auth.uid())));
create policy "datos_pago: usuarios leen activos" on public.datos_pago for select to authenticated
  using (activo or public.has_role('admin'));
create policy "datos_pago: admin escribe" on public.datos_pago for all to authenticated
  using (public.has_role('admin')) with check (public.has_role('admin'));

-- ============ RPC ============
-- rpc_inscribir: ver la version corregida en 20261125152839_fix_rpc_inscribir_estado_cast.sql

create or replace function public.rpc_cancelar_inscripcion(p_id uuid)
returns void language plpgsql security definer set search_path = '' as $$
begin
  update public.inscripciones set estado = 'cancelada'
   where id = p_id and owner_id = auth.uid() and estado in ('precio_por_confirmar','pendiente_pago');
  if not found then raise exception 'No se puede cancelar esta inscripción'; end if;
end $$;

-- El admin fija el precio de los casos "a convenir"
create or replace function public.rpc_fijar_precio(p_id uuid, p_total numeric)
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not public.has_role('admin') then raise exception 'Solo administración'; end if;
  update public.inscripciones set precio_total_usd = p_total, precio_base_usd = coalesce(precio_base_usd, p_total),
         estado = 'pendiente_pago'
   where id = p_id and estado = 'precio_por_confirmar';
  if not found then raise exception 'La inscripción no está esperando precio'; end if;
end $$;

-- Registrar pago de varias inscripciones; tasa congelada
create or replace function public.rpc_registrar_pago(p_inscripciones uuid[], p_metodo public.metodo_pago,
  p_referencia text default null, p_telefono text default null, p_banco text default null,
  p_fecha date default current_date, p_comprobante text default null)
returns public.pagos language plpgsql security definer set search_path = '' as $$
declare v_total numeric; v_jornada uuid; v_cnt int; t record; pg public.pagos;
begin
  if auth.uid() is null then raise exception 'Inicia sesión'; end if;
  select sum(precio_total_usd), min(jornada_id::text)::uuid, count(*) into v_total, v_jornada, v_cnt
    from public.inscripciones
   where id = any(p_inscripciones) and owner_id = auth.uid() and estado = 'pendiente_pago'
     and precio_total_usd is not null;
  if v_cnt is distinct from cardinality(p_inscripciones) then
    raise exception 'Alguna inscripción no está lista para pagar';
  end if;
  if (select count(distinct jornada_id) from public.inscripciones where id = any(p_inscripciones)) > 1 then
    raise exception 'Paga las inscripciones de una jornada a la vez';
  end if;
  if p_comprobante is not null and p_comprobante not like auth.uid()::text || '/%' then
    raise exception 'Comprobante inválido';
  end if;
  select valor, fecha_valor into t from public.tasa_vigente where moneda = 'EUR' and tipo = 'buy';
  insert into public.pagos (owner_id, jornada_id, metodo, monto_usd, tasa_eur_bcv, tasa_fecha, monto_bs,
                            referencia, telefono_emisor, banco_emisor, fecha_pago, comprobante_path)
  values (auth.uid(), v_jornada, p_metodo, v_total, t.valor, t.fecha_valor,
          case when t.valor is null then null else round(v_total * t.valor, 2) end,
          nullif(p_referencia,''), nullif(p_telefono,''), nullif(p_banco,''), coalesce(p_fecha, current_date),
          p_comprobante)
  returning * into pg;
  update public.inscripciones set pago_id = pg.id, estado = 'pago_en_revision' where id = any(p_inscripciones);
  insert into public.pago_eventos (pago_id, a_estado, actor_id, actor_rol) values (pg.id, 'pendiente', auth.uid(), 'propietario');
  return pg;
end $$;

-- Verificar / rechazar (contador o admin) y anular (solo admin)
create or replace function public.rpc_resolver_pago(p_pago uuid, p_accion text, p_motivo text default null)
returns public.pagos language plpgsql security definer set search_path = '' as $$
declare pg public.pagos; v_rol public.rol_app; nuevo public.estado_pago;
begin
  v_rol := case when public.has_role('admin') then 'admin'::public.rol_app
                when public.has_role('contador') then 'contador'::public.rol_app end;
  if v_rol is null then raise exception 'Solo contador o administración'; end if;
  select * into pg from public.pagos where id = p_pago for update;
  if not found then raise exception 'Pago no encontrado'; end if;
  if p_accion = 'verificar' and pg.estado = 'pendiente' then nuevo := 'verificado';
  elsif p_accion = 'rechazar' and pg.estado = 'pendiente' then
    if coalesce(trim(p_motivo),'') = '' then raise exception 'Indica el motivo del rechazo'; end if;
    nuevo := 'rechazado';
  elsif p_accion = 'anular' and pg.estado = 'verificado' then
    if v_rol <> 'admin' then raise exception 'Solo administración puede anular una verificación'; end if;
    if coalesce(trim(p_motivo),'') = '' then raise exception 'Indica el motivo'; end if;
    nuevo := 'anulado';
  else raise exception 'Este pago ya fue resuelto (estado: %)', pg.estado;
  end if;
  update public.pagos set estado = nuevo, motivo_rechazo = case when nuevo <> 'verificado' then p_motivo end,
         verificado_por = auth.uid(), verificado_por_rol = v_rol, verificado_at = now()
   where id = p_pago returning * into pg;
  update public.inscripciones set
     estado = case when nuevo = 'verificado' then 'confirmada'::public.estado_inscripcion else 'pendiente_pago'::public.estado_inscripcion end,
     pago_id = case when nuevo = 'verificado' then pago_id end
   where pago_id = p_pago;
  insert into public.pago_eventos (pago_id, de_estado, a_estado, actor_id, actor_rol, nota)
  values (p_pago, case when nuevo = 'anulado' then 'verificado' else 'pendiente' end::public.estado_pago, nuevo, auth.uid(), v_rol, p_motivo);
  return pg;
end $$;

-- Tasa manual (contador o admin) mientras no hay API
create or replace function public.rpc_set_tasa_manual(p_valor numeric, p_fecha_valor date, p_motivo text default null,
  p_moneda text default 'EUR')
returns void language plpgsql security definer set search_path = '' as $$
begin
  if not (public.has_role('admin') or public.has_role('contador')) then raise exception 'Solo contador o administración'; end if;
  if p_valor is null or p_valor <= 0 then raise exception 'Escribe una tasa válida'; end if;
  if p_fecha_valor > current_date + 7 or p_fecha_valor < current_date - 30 then raise exception 'Revisa la fecha valor'; end if;
  insert into public.tasas_cambio (moneda, tipo, valor, fecha_valor, fuente, proveedor, manual, creado_por, motivo)
  values (p_moneda, 'buy', p_valor, p_fecha_valor, 'BCV', 'manual', true, auth.uid(), p_motivo)
  on conflict (moneda, tipo, fecha_valor, manual) do update
    set valor = excluded.valor, creado_por = excluded.creado_por, motivo = excluded.motivo, obtenida_at = now();
end $$;

create or replace function public.rpc_whatsapp_jornada(p_jornada uuid)
returns text language sql stable security definer set search_path = '' as $$
  select j.whatsapp_url from public.jornadas j
   where j.id = p_jornada and (public.is_staff() or exists (
     select 1 from public.inscripciones i where i.jornada_id = j.id and i.owner_id = auth.uid() and i.estado <> 'cancelada'));
$$;

create or replace function public.rpc_asignar_rol(p_email text, p_rol public.rol_app, p_quitar boolean default false)
returns void language plpgsql security definer set search_path = '' as $$
declare uid uuid;
begin
  if not public.has_role('admin') then raise exception 'Solo administración'; end if;
  select id into uid from public.profiles where lower(email) = lower(trim(p_email));
  if uid is null then raise exception 'No hay una cuenta con ese correo'; end if;
  if p_quitar then
    if p_rol = 'admin' and uid = auth.uid() then raise exception 'No puedes quitarte el rol de administrador'; end if;
    delete from public.user_roles where user_id = uid and rol = p_rol;
  else
    insert into public.user_roles (user_id, rol, asignado_por) values (uid, p_rol, auth.uid()) on conflict do nothing;
  end if;
end $$;

-- La tasa vigente prefiere la mas reciente; a igual fecha, la de la API sobre la manual
create or replace view public.tasa_vigente with (security_invoker = true) as
select distinct on (moneda, tipo) moneda, tipo, valor, fecha_valor, fuente, manual, obtenida_at
from public.tasas_cambio
order by moneda, tipo, fecha_valor desc, manual asc, obtenida_at desc;

revoke execute on function public.rpc_cancelar_inscripcion, public.rpc_fijar_precio,
  public.rpc_registrar_pago, public.rpc_resolver_pago, public.rpc_set_tasa_manual, public.rpc_whatsapp_jornada,
  public.rpc_asignar_rol from anon, public;
grant execute on function public.rpc_cancelar_inscripcion, public.rpc_fijar_precio,
  public.rpc_registrar_pago, public.rpc_resolver_pago, public.rpc_set_tasa_manual, public.rpc_whatsapp_jornada,
  public.rpc_asignar_rol to authenticated;
revoke execute on function public.handle_new_user from anon, authenticated, public;

-- ============ Storage: comprobantes WebP privados ============
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('comprobantes', 'comprobantes', false, 512000, array['image/webp'])
on conflict (id) do nothing;
create policy "comprobantes: dueno sube en su carpeta" on storage.objects for insert to authenticated
  with check (bucket_id = 'comprobantes' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "comprobantes: dueno o staff lee" on storage.objects for select to authenticated
  using (bucket_id = 'comprobantes' and ((storage.foldername(name))[1] = (select auth.uid())::text or public.is_staff()));
