import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../scan/ficha_screen.dart';
import '../staff/stats_screen.dart';
import 'cirugia_form_screen.dart';

bool _mismoDia(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Jornadas del cirujano: las de hoy primero, luego las próximas (publicadas o cerradas).
class SurgeonJornadasScreen extends StatefulWidget {
  const SurgeonJornadasScreen({super.key});

  @override
  State<SurgeonJornadasScreen> createState() => _SurgeonJornadasScreenState();
}

class _SurgeonJornadasScreenState extends State<SurgeonJornadasScreen> {
  List<Jornada>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final hoy = DateTime.now();
      final inicio = DateTime(hoy.year, hoy.month, hoy.day);
      final rows = await Data.jornadas(todas: true);
      final list = rows
          .where((j) => (j.estado == 'publicada' || j.estado == 'cerrada') && !j.fecha.isBefore(inicio))
          .toList()
        ..sort((a, b) => a.fecha.compareTo(b.fecha));
      if (mounted) setState(() => _items = list);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    Widget body;
    if (_error != null && items == null) {
      body = EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar las jornadas',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    } else if (items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final ahora = DateTime.now();
      final hoy = items.where((j) => _mismoDia(j.fecha, ahora)).toList();
      final proximas = items.where((j) => !_mismoDia(j.fecha, ahora)).toList();
      var i = 1;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          children: [
            FadeSlideIn(
              child: FzHero(
                title: 'Jornadas de hoy',
                subtitle: hoy.isEmpty
                    ? 'No tienes jornadas hoy'
                    : '${hoy.length} ${hoy.length == 1 ? 'jornada' : 'jornadas'} · ${Money.fecha(ahora)}',
                leading: const Icon(Icons.medical_services_rounded, size: 40, color: Fz.tarjeta),
              ),
            ),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: EmptyState(
                  icon: Icons.event_busy_rounded,
                  title: 'Sin jornadas próximas',
                  message: 'Cuando la administración publique una jornada aparecerá aquí.',
                ),
              ),
            for (final j in hoy)
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: FadeSlideIn(index: i++, child: _JornadaCard(j: j, hoy: true, onBack: _load)),
              ),
            if (proximas.isNotEmpty) const SectionTitle('Próximas'),
            for (final j in proximas)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: FadeSlideIn(index: i++, child: _JornadaCard(j: j, hoy: false, onBack: _load)),
              ),
          ],
        ),
      );
    }
    return Scaffold(body: SafeArea(child: body));
  }
}

class _JornadaCard extends StatelessWidget {
  const _JornadaCard({required this.j, required this.hoy, required this.onBack});
  final Jornada j;
  final bool hoy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: hoy ? Fz.tarjeta : Fz.azul50,
      padding: EdgeInsets.zero,
      onTap: () async {
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => SurgeonJornadaDetalle(jornada: j)));
        onBack();
      },
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(Fz.radioTarjeta - 2)),
          child: SizedBox(
            height: hoy ? 140 : 96,
            child: j.imagenUrl == null
                ? const _PortadaVacia()
                : Image.network(j.imagenUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const _PortadaVacia()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(children: [
            if (hoy) const StatusPill('Hoy', icon: Icons.today_rounded, color: Fz.azul200),
            if (hoy) const SizedBox(height: 6),
            Text(j.titulo, textAlign: TextAlign.center, style: t.titleLarge),
            const SizedBox(height: 4),
            Text('${Money.fechaLarga(j.fecha)} · ${j.sede}', textAlign: TextAlign.center, style: t.bodySmall),
            if (j.estado == 'cerrada') ...[
              const SizedBox(height: 6),
              const StatusPill('Inscripciones cerradas', icon: Icons.lock_rounded, color: Fz.azul100),
            ],
          ]),
        ),
      ]),
    );
  }
}

class _PortadaVacia extends StatelessWidget {
  const _PortadaVacia();

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: Fz.azul400,
        child: CustomPaint(
          painter: PawPatternPainter(),
          child: const Center(child: Icon(Icons.pets_rounded, size: 40, color: Fz.tarjeta)),
        ),
      );
}

/// Detalle de una jornada para el cirujano: progreso y participantes por operar / atendidas.
class SurgeonJornadaDetalle extends StatefulWidget {
  const SurgeonJornadaDetalle({super.key, required this.jornada});
  final Jornada jornada;

  @override
  State<SurgeonJornadaDetalle> createState() => _SurgeonJornadaDetalleState();
}

class _SurgeonJornadaDetalleState extends State<SurgeonJornadaDetalle> {
  List<Map<String, dynamic>>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.participantes(widget.jornada.id);
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _abrir(Map<String, dynamic> f, {bool cirugia = false}) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => cirugia ? CirugiaFormScreen(ficha: f) : FichaScreen(ficha: f),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.jornada;
    final t = Theme.of(context).textTheme;
    final items = _items;
    Widget body;
    if (_error != null && items == null) {
      body = EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los participantes',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    } else if (items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final activos = items.where((f) => f['estado'] != 'cancelada').toList();
      final atendidas = activos.where(fichaAtendida).toList();
      final porOperar = activos.where((f) => !fichaAtendida(f)).toList()
        // Primero las que ya llegaron.
        ..sort((a, b) => (a['presente_at'] == null ? 1 : 0).compareTo(b['presente_at'] == null ? 1 : 0));
      final total = activos.length;
      var i = 1;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            FadeSlideIn(
              child: FzHero(
                title: j.titulo,
                subtitle: '${Money.fechaLarga(j.fecha)} · ${j.sede}',
                child: Column(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : atendidas.length / total,
                      minHeight: 12,
                      color: Fz.tarjeta,
                      backgroundColor: Fz.azul700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('${atendidas.length}/$total operadas',
                      textAlign: TextAlign.center, style: t.titleMedium?.copyWith(color: Fz.tarjeta)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            FadeSlideIn(
              index: 1,
              child: PopButton.tonal(
                label: 'Ver estadísticas',
                icon: Icons.bar_chart_rounded,
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => EstadisticasScreen(jornadaId: j.id))),
              ),
            ),
            if (activos.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: EmptyState(
                  icon: Icons.pets_rounded,
                  title: 'Sin participantes',
                  message: 'Todavía no hay mascotas inscritas en esta jornada.',
                ),
              ),
            if (porOperar.isNotEmpty) SectionTitle('Por operar · ${porOperar.length}'),
            for (final f in porOperar)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeSlideIn(
                  index: i++,
                  child: _Participante(
                    f: f,
                    onTap: () => _abrir(f),
                    onCirugia: () => _abrir(f, cirugia: true),
                  ),
                ),
              ),
            if (atendidas.isNotEmpty) SectionTitle('Atendidas · ${atendidas.length}'),
            for (final f in atendidas)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeSlideIn(index: i++, child: _Participante(f: f, onTap: () => _abrir(f))),
              ),
          ],
        ),
      );
    }
    return Scaffold(appBar: AppBar(title: const Text('Participantes')), body: body);
  }
}

class _Participante extends StatelessWidget {
  const _Participante({required this.f, required this.onTap, this.onCirugia});
  final Map<String, dynamic> f;
  final VoidCallback onTap;
  final VoidCallback? onCirugia;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pet = fichaMapa(f['pet']);
    final nombre = pet['nombre'] as String? ?? 'Mascota';
    final atendida = fichaAtendida(f);
    return PopCard(
      color: atendida ? Fz.azul50 : Fz.tarjeta,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          FzAvatar(
            url: Data.fotoUrl(pet['foto_path'] as String?),
            text: iniciales(nombre),
            icon: Icons.pets_rounded,
            size: 56,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombre, style: t.titleMedium),
              Text(fichaDescripcion(pet, edad: false), style: t.bodySmall),
              Text(f['codigo'] as String? ?? '', style: t.labelSmall?.copyWith(color: Fz.azul)),
            ]),
          ),
          const SizedBox(width: 8),
          fichaEstadoPill(f),
        ]),
        if (onCirugia != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            height: 56,
            child: FilledButton.icon(
              onPressed: onCirugia,
              icon: const Icon(Icons.medical_services_rounded),
              label: const Text('Registrar cirugía'),
            ),
          ),
        ],
      ]),
    );
  }
}
