-- Inscribir varias mascotas: precio calculado en servidor, cupos con bloqueo.
-- Corrige el cast del estado (antes se insertaba como text y fallaba).
create or replace function public.rpc_inscribir(p_jornada uuid, p_items jsonb)
returns setof public.inscripciones language plpgsql security definer set search_path = '' as $$
declare
  j public.jornadas; it jsonb; pet public.pets; libres int; base numeric; total numeric;
  v_serv public.servicio; v_kit boolean; v_cono boolean; n int;
begin
  if auth.uid() is null then raise exception 'Inicia sesión para inscribir'; end if;
  select * into j from public.jornadas where id = p_jornada for update;
  if not found or j.estado <> 'publicada' then raise exception 'La jornada no está abierta'; end if;
  n := jsonb_array_length(p_items);
  if n < 1 or n > 5 then raise exception 'Puedes inscribir de 1 a 5 mascotas'; end if;
  select j.cupos_total - count(*) into libres from public.inscripciones
   where jornada_id = p_jornada and estado <> 'cancelada';
  if libres < n then raise exception 'Solo quedan % cupos', libres; end if;
  for it in select * from jsonb_array_elements(p_items) loop
    select * into pet from public.pets where id = (it->>'pet_id')::uuid and owner_id = auth.uid();
    if not found then raise exception 'Mascota no encontrada'; end if;
    v_serv := coalesce((it->>'servicio')::public.servicio, 'esterilizacion');
    if v_serv = 'esterilizacion' and pet.esterilizada then raise exception '% ya está esterilizada', pet.nombre; end if;
    if v_serv = 'limpieza_dental' and not j.incluye_limpieza_dental then raise exception 'Esta jornada no ofrece limpieza dental'; end if;
    v_kit := v_serv = 'esterilizacion' and coalesce((it->>'kit')::boolean, true);
    v_cono := v_serv = 'esterilizacion' and coalesce((it->>'cono')::boolean, false);
    base := public.precio_base(v_serv, pet.especie, pet.sexo, pet.peso_kg, pet.braquiocefalico);
    total := case when base is null then null else base
      + case when v_kit then (select precio_usd from public.precios_extras where extra='kit' and especie=pet.especie) else 0 end
      + case when v_cono then (select precio_usd from public.precios_extras where extra='cono' and especie=pet.especie) else 0 end end;
    return query insert into public.inscripciones
      (jornada_id, pet_id, owner_id, servicio, incluye_kit, incluye_cono, precio_base_usd, precio_total_usd, estado, codigo)
      values (p_jornada, pet.id, auth.uid(), v_serv, v_kit, v_cono, base, total,
              (case when base is null then 'precio_por_confirmar' else 'pendiente_pago' end)::public.estado_inscripcion,
              'FZ-' || to_char(now(), 'YYMM') || '-' || lpad(nextval('public.codigo_inscripcion_seq')::text, 4, '0'))
      returning *;
  end loop;
end $$;
revoke execute on function public.rpc_inscribir from anon, public;
grant execute on function public.rpc_inscribir to authenticated;
