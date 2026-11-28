import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Copia un código (FZ-… / VD-…) al portapapeles y avisa "Código copiado".
Future<void> copiarCodigo(BuildContext context, String codigo) async {
  await Clipboard.setData(ClipboardData(text: codigo));
  if (context.mounted) showInfo(context, 'Código copiado');
}

/// Código de inscripción o de visita con botón para copiarlo (touch ≥ 48 dp).
class CodigoCopiable extends StatelessWidget {
  const CodigoCopiable(this.codigo, {super.key, this.prefijo = 'Código', this.grande = false, this.color});
  final String codigo;
  final String? prefijo;
  final bool grande;

  /// Color del texto y del icono (por ejemplo, claro sobre FzHero).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = color ?? Fz.tinta;
    final style = grande ? Fz.display(20, color: c) : t.titleSmall?.copyWith(color: c);
    return Semantics(
      button: true,
      label: 'Copiar código $codigo',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => copiarCodigo(context, codigo),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(
                child: Text(
                  prefijo == null ? codigo : '$prefijo $codigo',
                  textAlign: TextAlign.center,
                  style: style,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: grande ? 22 : 18, color: color ?? Fz.azul),
            ]),
          ),
        ),
      ),
    );
  }
}

// ---------------- Visitas a domicilio ----------------

const estadosVisita = ['solicitada', 'confirmada', 'en_camino', 'en_atencion', 'finalizada'];

String etiquetaEstadoVisita(String? e) => switch (e) {
      'solicitada' => 'Solicitada',
      'confirmada' => 'Confirmada',
      'en_camino' => 'En camino',
      'en_atencion' => 'En atención',
      'finalizada' => 'Finalizada',
      'cancelada' => 'Cancelada',
      _ => e ?? '—',
    };

IconData iconoEstadoVisita(String? e) => switch (e) {
      'solicitada' => Icons.hourglass_top_rounded,
      'confirmada' => Icons.event_available_rounded,
      'en_camino' => Icons.directions_car_rounded,
      'en_atencion' => Icons.medical_services_rounded,
      'finalizada' => Icons.verified_rounded,
      'cancelada' => Icons.cancel_rounded,
      _ => Icons.info_rounded,
    };

/// Estado de visita → etiqueta con icono, texto y forma.
StatusPill pillEstadoVisita(String? e) => StatusPill(
      etiquetaEstadoVisita(e),
      icon: iconoEstadoVisita(e),
      color: switch (e) {
        'solicitada' => Fz.azul50,
        'confirmada' => Fz.azul100,
        'en_camino' || 'en_atencion' => Fz.azul200,
        'finalizada' => Fz.tarjeta,
        'cancelada' => Fz.frambuesaSuave,
        _ => Fz.azul50,
      },
      dashed: e == 'solicitada',
    );

/// Estado del pago de una visita → etiqueta (o null si no hay pago).
StatusPill? pillPagoVisita(Map<String, dynamic> v) {
  final p = v['pago'] as Map?;
  if (p == null) return null;
  return switch (p['estado']) {
    'verificado' => const StatusPill('Pago verificado', icon: Icons.check_circle_rounded, color: Fz.azul100),
    'rechazado' => const StatusPill('Pago rechazado', icon: Icons.error_outline_rounded, color: Fz.frambuesaSuave),
    'anulado' => const StatusPill('Pago anulado', icon: Icons.block_rounded, color: Fz.tarjeta),
    _ => const StatusPill('Pago en revisión', icon: Icons.manage_search_rounded, color: Fz.azul50, dashed: true),
  };
}

String nombreServicioVisita(Map<String, dynamic> v) =>
    ((v['servicios_domicilio'] as Map?)?['nombre'] as String?) ?? 'Visita a domicilio';

String franjaTexto(String? f) => f == 'tarde' ? 'Tarde' : 'Mañana';

DateTime? fechaHoraVisita(Map<String, dynamic> v) {
  final s = v['fecha_hora'] as String?;
  return s == null ? null : DateTime.tryParse(s)?.toLocal();
}

DateTime? fechaPreferidaVisita(Map<String, dynamic> v) {
  final s = v['fecha_preferida'] as String?;
  return s == null ? null : DateTime.tryParse(s);
}

/// "sáb 6 de diciembre · 9:30 a. m." o "Por confirmar · preferida 06/12 (mañana)".
String fechaVisitaTexto(Map<String, dynamic> v) {
  final fh = fechaHoraVisita(v);
  if (fh != null) return Money.fechaLarga(fh);
  final fp = fechaPreferidaVisita(v);
  final pref = fp == null ? '' : ' · preferida ${DateFormat('dd/MM', 'es').format(fp)} (${franjaTexto(v['franja'] as String?).toLowerCase()})';
  return 'Fecha por confirmar$pref';
}

double? precioVisita(Map<String, dynamic> v) => (v['precio_usd'] as num?)?.toDouble();

/// Se puede pagar: hay precio, no está cancelada y no hay pago pendiente ni verificado.
bool puedePagarVisita(Map<String, dynamic> v) {
  if (precioVisita(v) == null || v['estado'] == 'cancelada') return false;
  final estadoPago = (v['pago'] as Map?)?['estado'];
  return estadoPago == null || estadoPago == 'rechazado' || estadoPago == 'anulado';
}

bool puedeCancelarVisita(Map<String, dynamic> v) => v['estado'] == 'solicitada' || v['estado'] == 'confirmada';

/// Duración legible: 45 → "45 min", 90 → "1 h 30 min".
String duracionTexto(int? min) {
  if (min == null || min <= 0) return 'Duración a convenir';
  final h = min ~/ 60, m = min % 60;
  if (h == 0) return '$m min';
  return m == 0 ? '$h h' : '$h h $m min';
}
