import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../citas/visita_comun.dart';
import 'registrar_pago_screen.dart';

/// Pagos del propietario: lo que falta pagar (jornadas y visitas) y el historial con su estado.
class MisPagosScreen extends StatefulWidget {
  const MisPagosScreen({super.key});

  @override
  State<MisPagosScreen> createState() => _MisPagosScreenState();
}

class _MisPagosScreenState extends State<MisPagosScreen> {
  List<Map<String, dynamic>>? _ins;
  List<Map<String, dynamic>>? _pagos;
  List<Map<String, dynamic>> _visitas = [];
  Tasa? _tasa;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final visF = Data.misVisitas().catchError((_) => <Map<String, dynamic>>[]);
      final r = await Future.wait([Data.misInscripciones(), Data.misPagos()]);
      final vis = await visF;
      Tasa? tasa;
      try {
        tasa = await Data.tasaVigente();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _ins = r[0];
        _pagos = r[1];
        _visitas = vis;
        _tasa = tasa;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pagar(List<String> ids) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegistrarPagoScreen(inscripcionIds: ids)));
    _load();
  }

  Future<void> _pagarVisita(Map<String, dynamic> v) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => RegistrarPagoScreen(visita: v)));
    _load();
  }

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Mis pagos')), body: _body(context));

  Widget _body(BuildContext context) {
    if (_error != null && _pagos == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tus pagos',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (_pagos == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final pendientes = _ins!.where((i) => i['estado'] == 'pendiente_pago').toList();
    final porConfirmar = _ins!.where((i) => i['estado'] == 'precio_por_confirmar').toList();
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final i in pendientes) {
      grupos.putIfAbsent(i['jornada_id'] as String, () => []).add(i);
    }
    final visitasPorPagar = _visitas.where(puedePagarVisita).toList();
    final codigos = {for (final i in _ins!) i['id'] as String: i['codigo'] as String?};
    final visitaPorId = {for (final v in _visitas) v['id'] as String: v};
    final vacio = grupos.isEmpty && porConfirmar.isEmpty && visitasPorPagar.isEmpty && _pagos!.isEmpty;

    final totalPend = pendientes.fold<double>(0, (s, i) => s + ((i['precio_total_usd'] as num?)?.toDouble() ?? 0)) +
        visitasPorPagar.fold<double>(0, (s, v) => s + (precioVisita(v) ?? 0));
    final hayPorPagar = grupos.isNotEmpty || visitasPorPagar.isNotEmpty;
    final verificados = _pagos!.where((p) => p['estado'] == 'verificado').length;
    var n = 0;
    Widget titulo(String x) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
          child: Text(x, textAlign: TextAlign.center, style: t.headlineSmall),
        );
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FadeSlideIn(
            child: FzHero(
              title: !hayPorPagar ? 'Tus pagos' : 'Por pagar ${Money.usd(totalPend)}',
              subtitle: !hayPorPagar
                  ? (_pagos!.isEmpty ? 'Aquí verás el estado de tus pagos' : '$verificados de ${_pagos!.length} verificados')
                  : _tasa == null
                      ? 'El monto en Bs se confirma al pagar'
                      : '${Money.bs(Money.aBs(totalPend, _tasa!.valor))} · tasa euro BCV',
              leading: const Icon(Icons.receipt_long_rounded, size: 34, color: Fz.tarjeta),
            ),
          ),
          if (vacio)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Sin pagos por ahora',
                message: 'Cuando inscribas a tu mascota en una jornada o pidas una visita, aquí podrás pagar y ver el estado de tus pagos.',
              ),
            ),
          if (hayPorPagar || porConfirmar.isNotEmpty) titulo('Por pagar'),
          for (final v in visitasPorPagar) ...[
            FadeSlideIn(
              index: ++n,
              child: _VisitaPorPagarCard(v: v, tasa: _tasa, alterna: n.isEven, onPagar: () => _pagarVisita(v)),
            ),
            const SizedBox(height: 12),
          ],
          for (final g in grupos.values) ...[
            FadeSlideIn(
              index: ++n,
              child: _PorPagarCard(
                  items: g, tasa: _tasa, alterna: n.isEven, onPagar: () => _pagar([for (final i in g) i['id'] as String])),
            ),
            const SizedBox(height: 12),
          ],
          for (final i in porConfirmar) ...[
            FadeSlideIn(
              index: ++n,
              child: PopCard(
                shadow: false,
                color: n.isEven ? Fz.azul50 : Fz.tarjeta,
                child: Column(children: [
                  Text('${(i['pets'] as Map?)?['nombre'] ?? 'Mascota'}', textAlign: TextAlign.center, style: t.titleMedium),
                  Text('${(i['jornadas'] as Map?)?['titulo'] ?? ''}', textAlign: TextAlign.center, style: t.bodySmall),
                  const SizedBox(height: 8),
                  const StatusPill('Precio por confirmar', icon: Icons.help_outline_rounded, color: Fz.azul50, dashed: true),
                  const SizedBox(height: 6),
                  Text('La administración fijará el precio y luego podrás pagar.',
                      textAlign: TextAlign.center, style: t.bodySmall),
                ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_pagos!.isNotEmpty) titulo('Mis pagos'),
          for (final p in _pagos!) ...[
            FadeSlideIn(
              index: ++n,
              child: _PagoCard(
                p: p,
                alterna: n.isEven,
                codigos: [
                  for (final i in (p['inscripciones'] as List? ?? const []))
                    if (codigos[(i as Map)['id']] != null) codigos[i['id']]!,
                  if (p['visita_id'] != null && visitaPorId[p['visita_id']]?['codigo'] != null)
                    visitaPorId[p['visita_id']]!['codigo'] as String,
                ],
                visita: p['visita_id'] == null ? null : visitaPorId[p['visita_id']],
                // Las visitas por pagar (también tras un rechazo) ya salen arriba en "Por pagar".
                onRepagar: p['visita_id'] != null
                    ? null
                    : () => _pagar([
                          for (final i in (p['inscripciones'] as List? ?? const [])) (i as Map)['id'] as String,
                        ]),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PorPagarCard extends StatelessWidget {
  const _PorPagarCard({required this.items, required this.tasa, required this.onPagar, this.alterna = false});
  final bool alterna;
  final List<Map<String, dynamic>> items;
  final Tasa? tasa;
  final VoidCallback onPagar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final j = items.first['jornadas'] as Map?;
    final total = items.fold<double>(0, (s, i) => s + ((i['precio_total_usd'] as num?)?.toDouble() ?? 0));
    final fecha = j?['fecha_inicio'] == null ? null : DateTime.tryParse(j!['fecha_inicio'] as String);
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('${j?['titulo'] ?? 'Jornada'}', textAlign: TextAlign.center, style: t.titleLarge),
        if (fecha != null) Text(Money.fechaLarga(fecha), textAlign: TextAlign.center, style: t.bodySmall),
        const SizedBox(height: 8),
        for (final i in items)
          Row(children: [
            Expanded(child: Text('${(i['pets'] as Map?)?['nombre'] ?? 'Mascota'}', style: t.bodyMedium)),
            if (i['codigo'] != null) CodigoCopiable('${i['codigo']}', prefijo: null),
            Text(Money.usd(i['precio_total_usd'] as num?), style: t.titleSmall),
          ]),
        const Divider(height: 18),
        Text('Total', textAlign: TextAlign.center, style: t.bodySmall),
        Text(Money.usd(total), textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(color: Fz.azul700)),
        Text(
                textAlign: TextAlign.center,
                tasa == null
                    ? 'Tasa no disponible; el monto en Bs se confirma al pagar.'
                    : '${Money.bs(Money.aBs(total, tasa!.valor))} · ${tasa!.vieja ? 'tasa del ${Money.fecha(tasa!.fechaValor).substring(0, 5)}, puede variar' : 'tasa del ${Money.fecha(tasa!.fechaValor)}'}',
                style: t.bodySmall,
              ),
        const SizedBox(height: 10),
        PopButton(label: 'Pagar', icon: Icons.payments_rounded, onPressed: onPagar),
      ]),
    );
  }
}

class _VisitaPorPagarCard extends StatelessWidget {
  const _VisitaPorPagarCard({required this.v, required this.tasa, required this.onPagar, this.alterna = false});
  final Map<String, dynamic> v;
  final Tasa? tasa;
  final VoidCallback onPagar;
  final bool alterna;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = precioVisita(v) ?? 0;
    final rechazado = (v['pago'] as Map?)?['estado'] == 'rechazado';
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.home_rounded, size: 28, color: Fz.azul),
        Text(nombreServicioVisita(v), textAlign: TextAlign.center, style: t.titleLarge),
        Text('Visita a domicilio · ${fechaVisitaTexto(v)}', textAlign: TextAlign.center, style: t.bodySmall),
        if (v['codigo'] != null) Center(child: CodigoCopiable('${v['codigo']}')),
        if (rechazado)
          const Center(child: StatusPill('Pago rechazado', icon: Icons.error_outline_rounded, color: Fz.frambuesaSuave)),
        const Divider(height: 18),
        Text('Total', textAlign: TextAlign.center, style: t.bodySmall),
        Text(Money.usd(total), textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(color: Fz.azul700)),
        Text(
          tasa == null
              ? 'Tasa no disponible; el monto en Bs se confirma al pagar.'
              : '${Money.bs(Money.aBs(total, tasa!.valor))} · ${tasa!.vieja ? 'tasa del ${Money.fecha(tasa!.fechaValor).substring(0, 5)}, puede variar' : 'tasa del ${Money.fecha(tasa!.fechaValor)}'}',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
        const SizedBox(height: 10),
        PopButton(label: rechazado ? 'Volver a pagar' : 'Pagar', icon: Icons.payments_rounded, onPressed: onPagar),
      ]),
    );
  }
}

class _PagoCard extends StatelessWidget {
  const _PagoCard({required this.p, required this.onRepagar, this.alterna = false, this.codigos = const [], this.visita});
  final bool alterna;
  final Map<String, dynamic> p;
  final VoidCallback? onRepagar;
  final List<String> codigos;
  final Map<String, dynamic>? visita;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final estado = p['estado'] as String;
    final metodo = p['metodo'] == 'pago_movil' ? 'Pago Móvil' : 'Efectivo en divisas';
    final mascotas = [
      for (final i in (p['inscripciones'] as List? ?? const [])) ((i as Map)['pets'] as Map?)?['nombre'] ?? 'Mascota'
    ].join(', ');
    final tasaFecha = p['tasa_fecha'] == null ? null : DateTime.tryParse(p['tasa_fecha'] as String);
    final fechaPago = p['fecha_pago'] == null ? null : DateTime.tryParse(p['fecha_pago'] as String);
    final rol = p['verificado_por_rol'] as String?;

    final (String label, IconData icon, Color color, bool dashed) = switch (estado) {
      'verificado' => ('Verificado', Icons.check_circle_rounded, Fz.azul100, false),
      'rechazado' => ('Rechazado', Icons.error_outline_rounded, Fz.frambuesaSuave, false),
      'anulado' => ('Anulado', Icons.block_rounded, Fz.tarjeta, false),
      _ => ('En revisión', Icons.schedule_rounded, Fz.azul50, true),
    };

    final card = PopCard(
      shadow: !dashed,
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      child: Column(children: [
        Text(
          visita != null
              ? '${nombreServicioVisita(visita!)} · $metodo'
              : p['visita_id'] != null
                  ? 'Visita a domicilio · $metodo'
                  : (mascotas.isEmpty ? metodo : '$mascotas · $metodo'),
          textAlign: TextAlign.center,
          style: t.titleMedium,
        ),
        Text(
          textAlign: TextAlign.center,
          [
            if (p['referencia'] != null) 'Ref. ${p['referencia']}',
            if (fechaPago != null) Money.fecha(fechaPago),
            if ((p['jornadas'] as Map?)?['titulo'] != null) '${(p['jornadas'] as Map)['titulo']}',
          ].join(' · '),
          style: t.bodySmall,
        ),
        if (codigos.isNotEmpty)
          Wrap(alignment: WrapAlignment.center, children: [for (final c in codigos) CodigoCopiable(c, prefijo: null)]),
        const SizedBox(height: 8),
        StatusPill(label, icon: icon, color: color, dashed: dashed),
        const SizedBox(height: 8),
        Text(Money.usd(p['monto_usd'] as num?), style: t.headlineMedium?.copyWith(color: Fz.azul700)),
        if (p['monto_bs'] != null)
          Text(
            textAlign: TextAlign.center,
            '${Money.bs(p['monto_bs'] as num)}'
            '${p['tasa_eur_bcv'] != null ? ' · tasa ${Money.tasa(p['tasa_eur_bcv'] as num)}' : ''}'
            '${tasaFecha != null ? ' del ${Money.fecha(tasaFecha)}' : ''}',
            style: t.bodySmall,
          )
        else if (p['metodo'] == 'efectivo_divisa')
          Text('En billetes de dólares', textAlign: TextAlign.center, style: t.bodySmall),
        if (estado == 'pendiente') ...[
          const SizedBox(height: 6),
          Text('Lo revisa el contador o la administración.', textAlign: TextAlign.center, style: t.bodySmall),
        ],
        if (estado == 'verificado') ...[
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.verified_user_rounded, size: 18, color: Fz.azul),
            const SizedBox(width: 6),
            Text(rol == 'contador' ? 'Lo verificó el contador' : 'Lo verificó la administración', style: t.bodyMedium),
          ]),
        ],
        if (estado == 'rechazado') ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Fz.frambuesaSuave,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Fz.tinta, width: 1.5),
            ),
            child: Text('Motivo: ${p['motivo_rechazo'] ?? 'sin indicar'}', style: t.bodyMedium),
          ),
          if (onRepagar != null) ...[
            const SizedBox(height: 10),
            PopButton(label: 'Volver a pagar', icon: Icons.refresh_rounded, onPressed: onRepagar),
          ],
        ],
        if (estado == 'anulado') ...[
          const SizedBox(height: 6),
          Text('Este pago fue anulado por la administración.', textAlign: TextAlign.center, style: t.bodySmall),
        ],
      ]),
    );
    if (!dashed) return card;
    return CustomPaint(foregroundPainter: _DashedBorder(), child: card);
  }
}

/// Borde punteado para pagos "En revisión".
class _DashedBorder extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rr = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(Fz.radioTarjeta));
    final path = Path()..addRRect(rr);
    // Pinta huecos crema sobre el borde sólido para que se vea punteado.
    final gap = Paint()
      ..color = Fz.fondo
      ..style = PaintingStyle.stroke
      ..strokeWidth = Fz.borde + 1.5;
    for (final m in path.computeMetrics()) {
      for (double d = 0; d < m.length; d += 14) {
        canvas.drawPath(m.extractPath(d + 8, (d + 14).clamp(0, m.length)), gap);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
