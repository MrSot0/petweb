import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../scan/ficha_screen.dart';

/// Honorarios del cirujano: lo que va a cobrar (pendiente), lo pagado y el detalle por jornada.
class HonorariosScreen extends StatefulWidget {
  const HonorariosScreen({super.key});

  @override
  State<HonorariosScreen> createState() => _HonorariosScreenState();
}

class _HonorariosScreenState extends State<HonorariosScreen> {
  Map<String, dynamic>? _data;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final d = await Data.misHonorarios();
      if (mounted) setState(() => _data = d);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    Widget body;
    if (_error != null && d == null) {
      body = EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tus honorarios',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    } else if (d == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      body = RefreshIndicator(onRefresh: _load, child: _contenido(context, d));
    }
    return Scaffold(body: SafeArea(child: body));
  }

  Widget _contenido(BuildContext context, Map<String, dynamic> d) {
    final t = Theme.of(context).textTheme;
    final cirugias = ((d['cirugias'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();

    // Agrupa por jornada conservando el orden (más recientes primero).
    cirugias.sort((a, b) => _fecha(b).compareTo(_fecha(a)));
    final grupos = <String, List<Map<String, dynamic>>>{};
    for (final c in cirugias) {
      final k = (c['jornada_id'] ?? c['jornada'] ?? 'sin') as String;
      grupos.putIfAbsent(k, () => []).add(c);
    }

    final cantidad = (d['cantidad'] as num?)?.toInt() ?? cirugias.length;
    final hero = FzHero(
      title: 'Mis honorarios',
      subtitle: 'Lo que vas a cobrar por tus cirugías',
      leading: const Icon(Icons.payments_rounded, size: 40, color: Fz.tarjeta),
      child: Column(
        children: [
          Text(
            'Pendiente por cobrar',
            textAlign: TextAlign.center,
            style: t.bodyMedium?.copyWith(color: Fz.azul50),
          ),
          const SizedBox(height: 2),
          Text(
            Money.usd((d['pendiente_usd'] as num?) ?? 0),
            textAlign: TextAlign.center,
            style: Fz.display(40, color: Fz.tarjeta),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Dato(label: 'Pagado', valor: Money.usd((d['pagado_usd'] as num?) ?? 0)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Dato(label: 'Total', valor: Money.usd((d['total_usd'] as num?) ?? 0)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Dato(label: cantidad == 1 ? 'Mascota' : 'Mascotas', valor: '$cantidad'),
              ),
            ],
          ),
        ],
      ),
    );

    var i = 1;
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FadeSlideIn(child: hero),
          const SizedBox(height: 12),
          FadeSlideIn(
            index: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.info_outline_rounded, size: 18, color: Fz.variante),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    'Las tarifas las fija la administración.',
                    textAlign: TextAlign.center,
                    style: t.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          if (cirugias.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 20),
              child: EmptyState(
                icon: Icons.medical_services_rounded,
                title: 'Aún no tienes cirugías',
                message: 'Cuando registres cirugías en una jornada, tus honorarios aparecerán aquí.',
              ),
            ),
          for (final g in grupos.values) ...[
            SectionTitle(_tituloJornada(g.first)),
            for (final c in g)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeSlideIn(
                  index: i++,
                  child: _CirugiaCard(c: c, alterna: i.isEven),
                ),
              ),
          ],
        ],
      ),
    );
  }

  static DateTime _fecha(Map<String, dynamic> c) =>
      DateTime.tryParse((c['fecha'] as String?) ?? '')?.toLocal() ?? DateTime(2000);

  static String _tituloJornada(Map<String, dynamic> c) {
    final j = (c['jornada'] as String?) ?? 'Jornada';
    final f = DateTime.tryParse((c['fecha'] as String?) ?? '');
    return f == null ? j : '$j · ${Money.fecha(f.toLocal())}';
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.label, required this.valor});
  final String label;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: Fz.azul700,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Fz.tinta, width: Fz.borde),
      ),
      child: Column(
        children: [
          FittedBox(
            child: Text(valor, style: t.titleLarge?.copyWith(color: Fz.tarjeta)),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: Fz.azul50),
          ),
        ],
      ),
    );
  }
}

class _CirugiaCard extends StatelessWidget {
  const _CirugiaCard({required this.c, required this.alterna});
  final Map<String, dynamic> c;
  final bool alterna;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nombre = (c['mascota'] as String?) ?? 'Mascota';
    final pagadoAt = DateTime.tryParse((c['pagado_at'] as String?) ?? '')?.toLocal();
    final fecha = DateTime.tryParse((c['fecha'] as String?) ?? '')?.toLocal();
    final desc = fichaDescripcion({'especie': c['especie'], 'sexo': c['sexo']}, edad: false);
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FzAvatar(
                text: iniciales(nombre),
                icon: c['especie'] == 'gato' ? Icons.cruelty_free_rounded : Icons.pets_rounded,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre, style: t.titleMedium),
                    Text(
                      [
                        desc,
                        if (fecha != null) Money.fecha(fecha),
                        if (c['patologia'] == true) 'Patología reproductiva',
                      ].join(' · '),
                      style: t.bodySmall,
                    ),
                    if (c['codigo'] is String) CodigoCopiable(c['codigo'] as String),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(Money.usd(c['honorario_usd'] as num?), style: t.titleLarge),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: pagadoAt == null
                ? const StatusPill(
                    'Pendiente de pago',
                    icon: Icons.hourglass_top_rounded,
                    color: Fz.tarjeta,
                    dashed: true,
                  )
                : StatusPill('Pagado el ${_ddmm(pagadoAt)}', icon: Icons.check_circle_rounded, color: Fz.azul200),
          ),
        ],
      ),
    );
  }

  static String _ddmm(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}
