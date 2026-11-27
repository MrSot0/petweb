# FAUNAZULIA · App Android (prototipo 1)

Flutter 3.47.9 (Dart 3.13) + Supabase. Español de Venezuela, tuteo.

## Ejecutar herramientas
```
export PATH=/home/user/tools/flutter/bin:$PATH ANDROID_HOME=/home/user/tools/android-sdk
cd /home/user/petweb/app
flutter analyze lib/            # análisis estático
flutter build apk --release     # SOLO el integrador; no lo corras en paralelo
```

## Estructura
- `lib/core/config.dart` URL y clave pública de Supabase.
- `lib/core/theme.dart` identidad v3 (`Fz.*` colores, `Fz.display()` tipografía Baloo 2; texto Atkinson Hyperlegible Next).
- `lib/core/widgets.dart` `PopCard`, `PopButton` (+ `.tonal/.accent/.danger`), `StatusPill`, `FzLogo`, `EmptyState`,
  `SectionTitle`, `showError(context, e)`, `showInfo(context, msg)`, `friendlyError(e)`.
- `lib/core/money.dart` `Money.usd()`, `Money.bs()`, `Money.aBs(usd, tasa)`, `Money.tasa()`, `Money.fecha()`, `Money.fechaLarga()`.
- `lib/core/data.dart` TODO el acceso a datos (`Data.*`, modelos `Pet`, `Jornada`, `Tasa`, `Precios`). No llames a Supabase
  desde las pantallas si existe un método en `Data`; si falta uno, añádelo en `data.dart` (avisa en tu informe).
- `lib/core/webp.dart` `WebpPipeline.elegir(camara:)`, `WebpPipeline.convertir(xfile)` → `WebpResult(bytes, originalBytes, quality)`.
- `lib/main.dart` `AuthGate` → `RoleGate` → `AppMode.of(context)` (`roles`, `staff`, `toggle()`, `isAdmin`, `isContador`, `canStaff`).
- `lib/features/owner/owner_shell.dart` pestañas: Inicio, Jornadas, Mascotas, Pagos, Perfil; `OwnerShell.irA(context, i)`.
- `lib/features/staff/staff_shell.dart` pestañas: Por verificar, Tasa, Jornadas (solo admin), Más.

## Base de datos (Supabase, ya creada)
Tablas: `profiles`, `user_roles` (propietario|cirujano|contador|admin), `pets`, `precios`, `precios_extras`, `jornadas`
(la columna `whatsapp_url` NO es legible por SELECT: usa `Data.whatsappJornada`), vista `jornadas_cupos`, `inscripciones`
(estados: precio_por_confirmar, pendiente_pago, pago_en_revision, confirmada, atendida, cancelada), `pagos` (estados:
pendiente, verificado, rechazado, anulado; método pago_movil | efectivo_divisa), `pago_eventos`, `datos_pago`
(datos de cobro de la organización), `tasas_cambio` + vista `tasa_vigente`.
RPC: `rpc_inscribir`, `rpc_cancelar_inscripcion`, `rpc_fijar_precio` (admin), `rpc_registrar_pago`,
`rpc_resolver_pago` (contador/admin; anular solo admin), `rpc_set_tasa_manual` (contador/admin), `rpc_whatsapp_jornada`,
`rpc_asignar_rol` (admin). Bucket privado `comprobantes` (solo image/webp ≤ 500 KB, carpeta = uid).

## Reglas de negocio
- Precios en dólares; el equivalente en Bs usa la tasa del EURO BCV y siempre se muestra su fecha. Si la tasa tiene
  más de 36 h: "Tasa del dd/mm, puede variar". Si no hay tasa: "Tasa no disponible; el monto en Bs se confirma al pagar".
- Kit post-operatorio OPCIONAL, marcado por defecto como "Recomendado" (+$5 gato / +$7 perro). Cono opcional (+$5/+$7).
- Perro > 30 kg o braquiocefálico → "Precio por confirmar" (el admin lo fija antes de pagar).
- Patología reproductiva → el costo se duplica (lo decide el cirujano; solo se informa en la app por ahora).
- No existen Donar ni Voluntariado. Se dice "precio", nunca "aporte".
- Pago Móvil exige referencia (4–12 dígitos) y comprobante; el comprobante se convierte a WebP en el teléfono.
- Teléfono Pago Móvil: `^0(412|414|416|422|424|426)\d{7}$`.

## Estilo
Fondos crema, tarjetas `PopCard` con contorno y sombra dura, botones `PopButton` píldora de un solo color. Nada de
emojis. Iconos `Icons.*_rounded`. Touch ≥ 48 dp. Estados con icono + texto + forma (no solo color).
Cada pantalla maneja cargando / vacío / error (con "Reintentar") y pull-to-refresh donde liste datos.

---
# v0.2 (lee esto además de lo anterior)

## Identidad visual v0.2 (feedback del cliente)
- UN SOLO color principal: el azul `Fz.azul` y sus variaciones `Fz.azul900/700/400/200/100/50`. Texto `Fz.tinta`.
  Fondo `Fz.fondo` (azul muy claro), tarjetas `Fz.tarjeta`. NO uses rosa ni crema (los nombres viejos
  `Fz.rosa/crema/cremaClaro/azulPastel` existen solo por compatibilidad y ya apuntan a tonos azules).
  Frambuesa solo para errores/peligro.
- Opciones seleccionadas con ACENTO FUERTE: fondo `Fz.azul` y texto `Fz.tarjeta` (chips, segmentos, tarjetas
  seleccionables, pestañas). No seleccionadas: `Fz.tarjeta` con borde.
- Tamaños de letra más pequeños (ya en el tema). No fuerces tamaños grandes; usa `Theme.of(context).textTheme`.
- CENTRA títulos, encabezados de sección, estados vacíos, montos destacados y textos introductorios.
  Listas y formularios pueden ir alineados a la izquierda dentro de tarjetas.
- DINAMISMO (evitar agotamiento visual): abre las pantallas principales con `FzHero` (banda azul con patrón
  de huellas) o una cabecera con avatar; alterna tarjetas `Fz.tarjeta` y `Fz.azul50`/`Fz.azul100`;
  envuelve los elementos de listas en `FadeSlideIn(index: i, child: ...)`; usa fotos (`FzAvatar`, portadas).
  Bordes `Fz.borde` (2) y sombra dura `Fz.sombra` ya están en `PopCard`/`PopButton`.

## Nuevos componentes
- `core/widgets.dart`: `FadeSlideIn`, `FzHero`, `FzAvatar(url:, text:, icon:, size:)`, `iniciales(nombre)`.
- `core/mapa.dart`: `MapaPreview(lat:, lng:, enlace:, height:)` (OpenStreetMap, sin clave) y `abrirEnlace(url)`.
- `core/qr.dart`: `CodigoQr(codigo:, size:)`.
- `main.dart`: `AppMode.of(context)` funciona en TODAS las pantallas (también las abiertas con Navigator.push).
  `rol` ('admin'|'contador'|'cirujano'|null), `isAdmin`, `isContador`, `isCirujano`, `canStaff`, `staff`,
  `toggle()` (cambia entre modo propietario y modo equipo), `reload()` (recarga el rol).

## Datos nuevos (`Data.*`)
`fotoUrl(path)`, `subirFoto(xfile, carpeta: 'avatares'|'mascotas'|'jornadas')` (convierte a WebP),
`subirFotoCirugia(xfile, inscripcionId)`, `urlFotoCirugia(path)`, `miRolEquipo()`, `setRol(userId, rol)`
(un solo rol de equipo: 'propietario'|'cirujano'|'contador'|'admin'), `retirarInscripcion(id, motivo)`,
`buscarCodigo(codigo)` y `participantes(jornadaId)` → ficha `{id, codigo, estado, servicio, incluye_kit,
incluye_cono, precio_total_usd, ajuste_usd, presente_at, motivo_retiro, jornada{...}, pet{id,nombre,especie,
sexo,peso_kg,edad_meses,braquiocefalico,foto_path,notas,esterilizada}, propietario{nombre,telefono,cedula,email}
(cédula/correo solo para admin/contador), pago{id,metodo,estado,monto_usd,monto_bs,referencia,banco}|null,
cirugia{id,created_at,patologia_reproductiva}|null}`, `marcarPresente(id)`, `registrarCirugia(...)`,
`estadisticas([jornadaId])` → `{total, atendidas, presentes, retiradas, por_especie{perro,gato},
por_sexo{perro_macho,...}, por_estado{...}, por_servicio{...}, ingresos{verificado_usd, pendiente_usd,
verificado_bs, por_metodo{pago_movil,efectivo_divisa}, esperado_usd, ajustes_usd}|null (solo admin/contador),
por_jornada[{id,titulo,fecha,mascotas,ingresos_usd}] (solo si jornadaId es null)}`,
`resolverMapa(url)` → `{url, lat, lng}` (acepta maps.app.goo.gl), `actualizarFotoPerfil(path)`.
Modelos: `Jornada.mapsUrl`, `Jornada.imagenUrl`, `Jornada.enlaceMapa`, `Pet.fotoUrl`. Perfil: `avatar_path`.
Tabla `jornadas`: columnas nuevas `maps_url`, `imagen_path`. Tabla `pets`: `foto_path`.

## Navegación v0.2
- Propietario: Inicio · Jornadas · Mascotas · Pagos · Ajustes (`features/settings/settings_screen.dart`).
- Equipo (admin y contador): Pagos · Jornadas · Escanear · Tasa · Ajustes.
- Cirujano: Jornadas (`features/surgeon/surgeon_jornadas_screen.dart`) · Escanear · Estadísticas · Ajustes.
