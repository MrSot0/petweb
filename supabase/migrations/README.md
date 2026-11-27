# Migraciones de Supabase (proyecto faunazulia)

Aplicadas en el proyecto remoto, en este orden:
- 20261124204206_tasas_cambio_bcv.sql
- 20261125150657_mvp_core_schema.sql
- 20261125152839_fix_rpc_inscribir_estado_cast.sql
- v02_fotos_qr_cirugias_estadisticas (aplicada el 27/11/2026; ver `supabase_migrations.schema_migrations`
  para el SQL exacto): columnas maps_url/imagen_path/avatar_path/foto_path, tabla cirugias, buckets
  `fotos` (público, WebP) y `cirugias` (privado), RPC rpc_set_rol, rpc_retirar_inscripcion, rpc_buscar_codigo,
  rpc_participantes_jornada, rpc_marcar_presente, rpc_registrar_cirugia, rpc_estadisticas, mi_rol_equipo.

Edge Functions: `tasa-bcv` (tasa automática, pendiente de API key) y `resolver-mapa` (enlace de Google Maps → coordenadas).
