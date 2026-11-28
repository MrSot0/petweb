import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'pago_detalle_screen.dart';

/// Antigüedad legible: "hace 40 min", "hace 2 h", "hace 3 d".
String staffHace(String? iso) {
  final f = staffFecha(iso);
  if (f == null) return '';
  final d = DateTime.now().difference(f);
  if (d.inMinutes < 1) return 'hace un momento';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  return 'hace ${d.inDays} d';
}

double? staffNum(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');

/// Texto seguro: null si el campo no viene o está vacío (nunca falla con tipos inesperados).
String? staffStr(dynamic v) {
  final s = v?.toString().trim();
  return s == null || s.isEmpty ? null : s;
}

/// Fecha segura (local) a partir de un ISO; null si no viene o no se puede leer.
DateTime? staffFecha(dynamic v) {
  final s = staffStr(v);
  return s == null ? null : DateTime.tryParse(s)?.toLocal();
}

String staffMetodo(String? m) => m == 'efectivo_divisa' ? 'Efectivo en divisas' : 'Pago Móvil';

String staffRol(String? r) => switch (r) {
      'admin' => 'administración',
      'contador' => 'contador',
      'cirujano' => 'cirujano',
      _ => r ?? 'equipo',
    };

String staffPetsTexto(Map<String, dynamic> pago) {
  final ins = (pago['inscripciones'] as List?) ?? const [];
  final names = ins
      .whereType<Map>()
      .map((i) => staffStr((i['pets'] as Map?)?['nombre']))
      .whereType<String>()
      .toList();
  return names.isEmpty ? 'Sin mascotas' : names.join(', ');
}

/// Pagos reportados por los propietarios, para verificar contra el banco o la caja.
class VerificarScreen extends StatefulWidget {
  const VerificarScreen({super.key});

  @override
  State<VerificarScreen> createState() => _VerificarScreenState();
}

class _VerificarScreenState extends State<VerificarScreen> {
  static const _segs = [
    ('pendiente', 'Por verificar', Icons.hourglass_top_rounded),
    ('verificado', 'Verificados', Icons.check_circle_rounded),
    ('rechazado', 'Rechazados', Icons.cancel_rounded),
  ];

  String _estado = 'pendiente';
  List<Map<String, dynamic>>? _pagos;
  int? _pendientes;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final estado = _estado;
      final rows = await Data.pagos(estado: estado);
      if (!mounted || estado != _estado) return;
      setState(() {
        _pagos = rows;
        if (estado == 'pendiente') _pendientes = rows.length;
      });
      if (estado != 'pendiente') {
        final p = await Data.pagos(estado: 'pendiente');
        if (mounted) setState(() => _pendientes = p.length);
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _cambiar(String e) {
    if (e == _estado) return;
    setState(() {
      _estado = e;
      _pagos = null;
    });
    _load();
  }

  Future<void> _abrir(Map<String, dynamic> pago) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PagoDetalleScreen(pago: pago)),
    );
    // Siempre recarga al volver: el pago pudo verificarse/rechazarse (aquí o por otra persona).
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pagos')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FadeSlideIn(
            child: FzHero(
              leading: Text(_pendientes?.toString() ?? '–', style: Fz.display(40, color: Fz.tarjeta)),
              title: _pendientes == 1 ? 'pago por verificar' : 'pagos por verificar',
              subtitle: 'Compara con el banco o la caja antes de verificar.',
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final s in _segs)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: _estado == s.$1 ? null : Icon(s.$3, size: 18, color: Fz.tinta),
                  label: Text(s.$1 == 'pendiente' && _pendientes != null ? '${s.$2} · $_pendientes' : s.$2),
                  selected: _estado == s.$1,
                  onSelected: (_) => _cambiar(s.$1),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 8),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_error != null && _pagos == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los pagos',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final pagos = _pagos;
    if (pagos == null) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: _load,
      child: pagos.isEmpty
          ? ListView(children: [
              const SizedBox(height: 40),
              EmptyState(
                icon: _estado == 'pendiente' ? Icons.task_alt_rounded : Icons.inbox_rounded,
                title: switch (_estado) {
                  'pendiente' => 'Todo al día',
                  'verificado' => 'Aún no hay pagos verificados',
                  _ => 'No hay pagos rechazados',
                },
                message: _estado == 'pendiente' ? 'No hay pagos esperando verificación.' : null,
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: pagos.length + (_estado == 'pendiente' ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                if (i == pagos.length) {
                  return Text('Más antiguos primero. Toca un pago para ver el comprobante.',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall);
                }
                return FadeSlideIn(
                  key: ValueKey(pagos[i]['id']),
                  index: i,
                  child: PagoCard(pago: pagos[i], alt: i.isOdd, onTap: () => _abrir(pagos[i])),
                );
              },
            ),
    );
  }
}

class PagoCard extends StatelessWidget {
  const PagoCard({super.key, required this.pago, this.onTap, this.alt = false});
  final Map<String, dynamic> pago;
  final VoidCallback? onTap;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final prof = (pago['profiles'] as Map?) ?? const {};
    final jor = (pago['jornadas'] as Map?) ?? const {};
    final nombre = staffStr(prof['nombre']);
    final usd = staffNum(pago['monto_usd']);
    final tasa = staffNum(pago['tasa_eur_bcv']);
    final bs = staffNum(pago['monto_bs']) ?? Money.aBs(usd, tasa);
    final tasaFecha = staffFecha(pago['tasa_fecha']);
    final jorFecha = staffFecha(jor['fecha_inicio']);
    final estado = staffStr(pago['estado']);
    final pm = pago['metodo'] != 'efectivo_divisa';
    final rol = staffRol(staffStr(pago['verificado_por_rol']));

    Widget meta(IconData ic, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, size: 16, color: Fz.variante),
          const SizedBox(width: 4),
          Flexible(child: Text(s, style: t.bodySmall, overflow: TextOverflow.ellipsis)),
        ]);

    return PopCard(
      onTap: onTap,
      color: alt ? Fz.azul50 : Fz.tarjeta,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          FzAvatar(text: iniciales(nombre), size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre ?? staffStr(prof['email']) ?? 'Propietario',
                  style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              meta(Icons.pets_rounded, staffPetsTexto(pago)),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(Money.usd(usd), style: Fz.display(20)),
            Text(Money.bs(bs), style: t.bodySmall),
          ]),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 12, runSpacing: 6, children: [
          if (jor['titulo'] != null)
            meta(Icons.event_rounded, '${jor['titulo']}${jorFecha != null ? ' · ${Money.fecha(jorFecha)}' : ''}'),
          meta(pm ? Icons.account_balance_rounded : Icons.payments_rounded,
              '${staffMetodo(staffStr(pago['metodo']))}${pago['banco_emisor'] != null ? ' · ${pago['banco_emisor']}' : ''}'),
          if (pago['referencia'] != null) meta(Icons.tag_rounded, 'Ref. ${pago['referencia']}'),
          if (tasa != null)
            meta(Icons.currency_exchange_rounded,
                'Tasa ${Money.tasa(tasa)}${tasaFecha != null ? ' del ${Money.fecha(tasaFecha)}' : ''}'),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          if (estado == 'verificado')
            Flexible(
              child: StatusPill('Verificado por $rol', icon: Icons.check_circle_rounded, color: Fz.azul200),
            )
          else if (estado == 'rechazado')
            Flexible(
              child: StatusPill('Rechazado por $rol', icon: Icons.cancel_rounded, color: Fz.frambuesaSuave),
            )
          else if (estado == 'anulado')
            const StatusPill('Anulado', icon: Icons.block_rounded, color: Fz.frambuesaSuave, dashed: true)
          else
            const StatusPill('Por verificar', icon: Icons.hourglass_top_rounded, color: Fz.azul100, dashed: true),
          const Spacer(),
          meta(Icons.schedule_rounded, staffHace(staffStr(pago['created_at']))),
        ]),
        if (estado == 'rechazado' && pago['motivo_rechazo'] != null) ...[
          const SizedBox(height: 8),
          Text('Motivo: ${pago['motivo_rechazo']}', style: t.bodySmall),
        ],
      ]),
    );
  }
}
