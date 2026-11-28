import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/qr.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../citas/visita_comun.dart';

/// Estado de inscripción → etiqueta con icono, texto y forma.
StatusPill pillEstadoInscripcion(String? e) {
  switch (e) {
    case 'precio_por_confirmar':
      return const StatusPill('Precio por confirmar', icon: Icons.hourglass_top_rounded, color: Fz.azul50, dashed: true);
    case 'pendiente_pago':
      return const StatusPill('Falta pagar', icon: Icons.payments_rounded, color: Fz.azul200);
    case 'pago_en_revision':
      return const StatusPill('Pago en revisión', icon: Icons.manage_search_rounded, color: Fz.azul100, dashed: true);
    case 'confirmada':
      return const StatusPill('Confirmada', icon: Icons.check_circle_rounded, color: Fz.azul100);
    case 'atendida':
      return const StatusPill('Atendida', icon: Icons.verified_rounded, color: Fz.tarjeta);
    case 'cancelada':
      return const StatusPill('Cancelada', icon: Icons.cancel_rounded, color: Fz.frambuesaSuave);
    default:
      return StatusPill(e ?? '—', icon: Icons.info_rounded);
  }
}

/// El QR se muestra para citas confirmadas o con el pago en revisión.
bool muestraQr(Map<String, dynamic> i) =>
    i['codigo'] != null && (i['estado'] == 'confirmada' || i['estado'] == 'pago_en_revision');

bool _cancelable(Map<String, dynamic> i) => i['estado'] == 'pendiente_pago' || i['estado'] == 'precio_por_confirmar';

String _servicio(Map<String, dynamic> i) => i['servicio'] == 'limpieza_dental' ? 'Limpieza dental' : 'Esterilización';

/// Hoja inferior con el código QR grande para mostrar al llegar a la jornada.
Future<void> mostrarCodigoQr(BuildContext context, Map<String, dynamic> i) {
  final t = Theme.of(context).textTheme;
  final pet = (i['pets'] as Map?) ?? const {};
  final j = (i['jornadas'] as Map?) ?? const {};
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Muestra este código al llegar', textAlign: TextAlign.center, style: t.headlineSmall),
          const SizedBox(height: 4),
          Text('${pet['nombre'] ?? 'Tu mascota'} · ${_servicio(i)}', textAlign: TextAlign.center, style: t.bodyMedium),
          if (j['titulo'] != null) Text('${j['titulo']}', textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 16),
          CodigoQr(codigo: '${i['codigo']}', size: 240),
          CodigoCopiable('${i['codigo']}', prefijo: 'Copiar'),
          const SizedBox(height: 6),
          Text('Sube el brillo de la pantalla para que lo lean más rápido.',
              textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 16),
          PopButton.tonal(label: 'Cerrar', onPressed: () => Navigator.pop(c)),
        ]),
      ),
    ),
  );
}

/// Inscripciones del propietario con su estado y el QR para el día de la jornada.
class MisCitasScreen extends StatelessWidget {
  const MisCitasScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Mis citas')), body: const MisCitasBody());
}

/// Lista de inscripciones a jornadas (con QR grande y código copiable).
/// [header] reemplaza la cabecera propia (lo usa la pestaña Citas para poner sus segmentos).
class MisCitasBody extends StatefulWidget {
  const MisCitasBody({super.key, this.header});
  final Widget? header;

  @override
  State<MisCitasBody> createState() => MisCitasBodyState();
}

class MisCitasBodyState extends State<MisCitasBody> {
  List<Map<String, dynamic>>? _ins;
  Map<String, String?> _fotos = {};
  Object? _error;
  final Set<String> _cancelando = {};

  @override
  void initState() {
    super.initState();
    recargar();
  }

  Future<void> recargar() async {
    setState(() => _error = null);
    try {
      final petsF = Data.misMascotas().then<List<Pet>?>((v) => v).catchError((_) => null);
      final r = await Data.misInscripciones();
      final pets = await petsF;
      if (mounted) {
        setState(() {
          _ins = r;
          if (pets != null) _fotos = {for (final p in pets) p.id: p.fotoUrl};
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _cancelar(Map<String, dynamic> i) async {
    final nombre = (i['pets'] as Map?)?['nombre'] ?? 'tu mascota';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Cancelar la cita de $nombre?'),
        content: const Text('Liberarás el cupo. Si luego quieres ir, tendrás que inscribirla de nuevo.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No, volver')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Fz.frambuesa),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final id = i['id'] as String;
    setState(() => _cancelando.add(id));
    try {
      await Data.cancelarInscripcion(id);
      if (!mounted) return;
      showInfo(context, 'Cita cancelada');
      await recargar();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cancelando.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final header = widget.header;
    if (_error != null && _ins == null) {
      return _scroll([
        ?header,
        EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'No pudimos cargar tus citas',
          message: friendlyError(_error!),
          action: PopButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: recargar, expand: false),
        ),
      ]);
    }
    if (_ins == null) {
      return _scroll([?header, const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))]);
    }
    final activas = _ins!.where((i) => i['estado'] != 'cancelada' && i['estado'] != 'atendida').toList();
    final pasadas = _ins!.where((i) => i['estado'] == 'cancelada' || i['estado'] == 'atendida').toList();
    final conQr = activas.where(muestraQr).length;
    var n = 0;
    return _scroll([
      header ??
          FadeSlideIn(
            child: FzHero(
              title: 'Tus citas',
              subtitle: activas.isEmpty
                  ? 'Aún no tienes citas activas'
                  : conQr == 0
                      ? '${activas.length} ${activas.length == 1 ? 'cita activa' : 'citas activas'}'
                      : 'Muestra tu código QR al llegar a la jornada',
              leading: const Icon(Icons.qr_code_2_rounded, size: 36, color: Fz.tarjeta),
            ),
          ),
      const SizedBox(height: 16),
      if (_ins!.isEmpty)
        const EmptyState(
          icon: Icons.event_note_rounded,
          title: 'Sin citas por ahora',
          message: 'Inscribe a tu mascota en una jornada y aquí verás su código QR.',
        ),
      if (header != null && conQr > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('Muestra tu código QR al llegar a la jornada',
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
        ),
      for (final i in activas) ...[
        FadeSlideIn(
            index: ++n,
            child: _CitaCard(
              i: i,
              foto: _fotos[i['pet_id']],
              alterna: n.isEven,
              cancelando: _cancelando.contains(i['id']),
              onCancelar: _cancelable(i) ? () => _cancelar(i) : null,
            )),
        const SizedBox(height: 14),
      ],
      if (pasadas.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
          child: Text('Anteriores', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        ),
      for (final i in pasadas) ...[
        FadeSlideIn(index: ++n, child: _CitaCard(i: i, foto: _fotos[i['pet_id']], alterna: n.isEven, compacta: true)),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _scroll(List<Widget> children) => RefreshIndicator(
        onRefresh: recargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: children,
        ),
      );
}

class _CitaCard extends StatelessWidget {
  const _CitaCard({required this.i, this.foto, this.alterna = false, this.compacta = false, this.cancelando = false, this.onCancelar});
  final Map<String, dynamic> i;
  final String? foto;
  final bool alterna;
  final bool compacta;
  final bool cancelando;
  final VoidCallback? onCancelar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pet = (i['pets'] as Map?) ?? const {};
    final j = (i['jornadas'] as Map?) ?? const {};
    final fecha = j['fecha_inicio'] == null ? null : DateTime.tryParse(j['fecha_inicio'] as String);
    final qr = !compacta && muestraQr(i);
    final esPerro = pet['especie'] == 'perro';
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      shadow: !compacta,
      child: Column(children: [
        Row(children: [
          FzAvatar(url: foto, icon: esPerro ? Icons.pets_rounded : Icons.cruelty_free_rounded, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${pet['nombre'] ?? 'Mascota'} · ${_servicio(i)}', style: t.titleMedium),
              Text('${j['titulo'] ?? 'Jornada'}', style: t.bodySmall),
              if (fecha != null) Text('${Money.fechaLarga(fecha)} · ${j['sede_nombre'] ?? ''}', style: t.bodySmall),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          pillEstadoInscripcion(i['estado'] as String?),
          if (i['precio_total_usd'] != null)
            StatusPill(Money.usd(i['precio_total_usd'] as num?), icon: Icons.sell_rounded, color: Fz.tarjeta),
        ]),
        if (qr) ...[
          const SizedBox(height: 14),
          Text('Muestra este código al llegar', textAlign: TextAlign.center, style: t.titleSmall),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => mostrarCodigoQr(context, i),
            child: CodigoQr(codigo: '${i['codigo']}', size: 200),
          ),
          CodigoCopiable('${i['codigo']}', prefijo: 'Copiar'),
          if (i['estado'] == 'pago_en_revision') ...[
            const SizedBox(height: 6),
            Text('Tu pago está en revisión; el cupo se confirma al verificarlo.',
                textAlign: TextAlign.center, style: t.bodySmall),
          ],
        ] else if (i['codigo'] != null) ...[
          const SizedBox(height: 8),
          CodigoCopiable('${i['codigo']}'),
          if (!compacta)
            Text('El QR aparece cuando registres tu pago.', textAlign: TextAlign.center, style: t.bodySmall),
        ],
        if (onCancelar != null) ...[
          const SizedBox(height: 12),
          PopButton.danger(
            label: 'Cancelar cita',
            icon: Icons.event_busy_rounded,
            loading: cancelando,
            onPressed: onCancelar,
          ),
        ],
      ]),
    );
  }
}
