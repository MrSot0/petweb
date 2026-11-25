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
