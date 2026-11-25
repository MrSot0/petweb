import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'registrar_pago_screen.dart';

class MisPagosScreen extends StatefulWidget {
  const MisPagosScreen({super.key});

  @override
  State<MisPagosScreen> createState() => _MisPagosScreenState();
}

class _MisPagosScreenState extends State<MisPagosScreen> {
  List<Map<String, dynamic>>? _ins;
  List<Map<String, dynamic>>? _pagos;
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
      final r = await Future.wait([Data.misInscripciones(), Data.misPagos()]);
      Tasa? tasa;
      try {
        tasa = await Data.tasaVigente();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _ins = r[0];
        _pagos = r[1];
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

  @override
  Widget build(BuildContext context) =>
      Scaffold(appBar: AppBar(title: const Text('Pagos')), body: _body(context));

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
    final vacio = grupos.isEmpty && porConfirmar.isEmpty && _pagos!.isEmpty;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          if (vacio)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: EmptyState(
                icon: Icons.receipt_long_rounded,
                title: 'Sin pagos por ahora',
                message: 'Cuando inscribas a tu mascota en una jornada, aquí podrás pagar y ver el estado de tus pagos.',
              ),
            ),
          if (grupos.isNotEmpty || porConfirmar.isNotEmpty) const SectionTitle('Por pagar'),
          for (final g in grupos.values) ...[
            _PorPagarCard(items: g, tasa: _tasa, onPagar: () => _pagar([for (final i in g) i['id'] as String])),
            const SizedBox(height: 12),
          ],
          for (final i in porConfirmar) ...[
            PopCard(
              shadow: false,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${(i['pets'] as Map?)?['nombre'] ?? 'Mascota'}', style: t.titleMedium),
                Text('${(i['jornadas'] as Map?)?['titulo'] ?? ''}', style: t.bodySmall),
                const SizedBox(height: 8),
                const StatusPill('Precio por confirmar', icon: Icons.help_outline_rounded, color: Fz.rosaSuave, dashed: true),
                const SizedBox(height: 6),
                Text('La administración fijará el precio y luego podrás pagar.', style: t.bodySmall),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          if (_pagos!.isNotEmpty) const SectionTitle('Mis pagos'),
          for (final p in _pagos!) ...[
            _PagoCard(
              p: p,
              onRepagar: () => _pagar([
                for (final i in (p['inscripciones'] as List? ?? const [])) (i as Map)['id'] as String,
              ]),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _PorPagarCard extends StatelessWidget {
  const _PorPagarCard({required this.items, required this.tasa, required this.onPagar});
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
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${j?['titulo'] ?? 'Jornada'}', style: t.titleLarge),
        if (fecha != null) Text(Money.fechaLarga(fecha), style: t.bodySmall),
        const SizedBox(height: 8),
        for (final i in items)
          Row(children: [
            Expanded(child: Text('${(i['pets'] as Map?)?['nombre'] ?? 'Mascota'} · ${i['codigo'] ?? ''}', style: t.bodyMedium)),
            Text(Money.usd(i['precio_total_usd'] as num?), style: t.titleSmall),
          ]),
        const Divider(height: 18),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Total ${Money.usd(total)}', style: Fz.display(22)),
              Text(
                tasa == null
                    ? 'Tasa no disponible; el monto en Bs se confirma al pagar.'
                    : '${Money.bs(Money.aBs(total, tasa!.valor))} · ${tasa!.vieja ? 'tasa del ${Money.fecha(tasa!.fechaValor).substring(0, 5)}, puede variar' : 'tasa del ${Money.fecha(tasa!.fechaValor)}'}',
                style: t.bodySmall,
              ),
            ]),
          ),
          const SizedBox(width: 8),
          PopButton(label: 'Pagar', icon: Icons.payments_rounded, expand: false, onPressed: onPagar),
        ]),
      ]),
    );
  }
}

class _PagoCard extends StatelessWidget {
  const _PagoCard({required this.p, required this.onRepagar});
  final Map<String, dynamic> p;
  final VoidCallback onRepagar;

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
      'verificado' => ('Verificado', Icons.check_circle_rounded, Fz.azulPastel, false),
      'rechazado' => ('Rechazado', Icons.error_outline_rounded, Fz.frambuesaSuave, false),
      'anulado' => ('Anulado', Icons.block_rounded, Fz.cremaClaro, false),
      _ => ('En revisión', Icons.schedule_rounded, Fz.rosaSuave, true),
    };

    final card = PopCard(
      shadow: !dashed,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(mascotas.isEmpty ? metodo : '$mascotas · $metodo', style: t.titleMedium),
        Text(
          [
            if (p['referencia'] != null) 'Ref. ${p['referencia']}',
            if (fechaPago != null) Money.fecha(fechaPago),
            if ((p['jornadas'] as Map?)?['titulo'] != null) '${(p['jornadas'] as Map)['titulo']}',
          ].join(' · '),
          style: t.bodySmall,
        ),
        const SizedBox(height: 8),
        StatusPill(label, icon: icon, color: color, dashed: dashed),
        const SizedBox(height: 8),
        Text(Money.usd(p['monto_usd'] as num?), style: Fz.display(24)),
        if (p['monto_bs'] != null)
          Text(
            '${Money.bs(p['monto_bs'] as num)}'
            '${p['tasa_eur_bcv'] != null ? ' · tasa ${Money.tasa(p['tasa_eur_bcv'] as num)}' : ''}'
            '${tasaFecha != null ? ' del ${Money.fecha(tasaFecha)}' : ''}',
            style: t.bodySmall,
          )
        else if (p['metodo'] == 'efectivo_divisa')
          Text('En billetes de dólares', style: t.bodySmall),
        if (estado == 'pendiente') ...[
          const SizedBox(height: 6),
          Text('Lo revisa el contador o la administración.', style: t.bodySmall),
        ],
        if (estado == 'verificado') ...[
          const SizedBox(height: 6),
          Row(children: [
            const Icon(Icons.verified_user_rounded, size: 18),
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
          const SizedBox(height: 10),
          PopButton.accent(label: 'Volver a pagar', icon: Icons.refresh_rounded, onPressed: onRepagar),
        ],
        if (estado == 'anulado') ...[
          const SizedBox(height: 6),
          Text('Este pago fue anulado por la administración.', style: t.bodySmall),
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
      ..color = Fz.crema
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
