import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'jornada_detail_screen.dart';

/// Lista de jornadas publicadas próximas.
class JornadasScreen extends StatefulWidget {
  const JornadasScreen({super.key});

  @override
  State<JornadasScreen> createState() => _JornadasScreenState();
}

class _JornadasScreenState extends State<JornadasScreen> {
  late Future<List<Jornada>> _f = Data.jornadas();

  Future<void> _refresh() async {
    final f = Data.jornadas();
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jornadas')),
      body: FutureBuilder<List<Jornada>>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar las jornadas',
              message: friendlyError(snap.error!),
              action: PopButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: _refresh, expand: false),
            );
          }
          final list = snap.data!;
          final hero = FzHero(
            title: 'Jornadas próximas',
            subtitle: list.isEmpty
                ? 'Estamos preparando las próximas fechas'
                : '${list.length} ${list.length == 1 ? 'fecha disponible' : 'fechas disponibles'} · perros y gatos',
            leading: const Icon(Icons.event_available_rounded, size: 34, color: Fz.tarjeta),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Fz.azul700,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Fz.tarjeta, width: 1.5),
              ),
              child: Text(
                'Kit post-operatorio recomendado: +\$5 gato / +\$7 perro',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Fz.tarjeta),
              ),
            ),
          );
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                FadeSlideIn(child: hero),
                const SizedBox(height: 16),
                if (list.isEmpty)
                  const EmptyState(
                    icon: Icons.event_busy_rounded,
                    title: 'No hay jornadas por ahora',
                    message: 'Desliza hacia abajo para actualizar.',
                  ),
                for (var i = 0; i < list.length; i++) ...[
                  FadeSlideIn(
                    index: i + 1,
                    child: JornadaCard(jornada: list[i], alterna: i.isOdd),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Portada de una jornada: la imagen cargada por el admin o, si no hay, una cabecera azul
/// con patrón de huellas y la fecha grande.
class JornadaPortada extends StatelessWidget {
  const JornadaPortada({super.key, required this.jornada, this.height = 140, this.radius = 18});
  final Jornada jornada;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = jornada.imagenUrl;
    final fallback = _FechaPortada(jornada: jornada, height: height);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: url == null
            ? fallback
            : Stack(fit: StackFit.expand, children: [
                Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => fallback,
                  loadingBuilder: (c, child, p) => p == null ? child : Container(color: Fz.azul100),
                ),
                Positioned(left: 10, top: 10, child: _FechaChip(fecha: jornada.fecha)),
              ]),
      ),
    );
  }
}

class _FechaChip extends StatelessWidget {
  const _FechaChip({required this.fecha});
  final DateTime fecha;

  @override
  Widget build(BuildContext context) {
    final mes = DateFormat('MMM', 'es').format(fecha).replaceAll('.', '').toUpperCase();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Fz.tarjeta,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Fz.tinta, width: Fz.borde),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${fecha.day}', style: Fz.display(22)),
        Text(mes, style: Theme.of(context).textTheme.labelSmall),
      ]),
    );
  }
}

class _FechaPortada extends StatelessWidget {
  const _FechaPortada({required this.jornada, required this.height});
  final Jornada jornada;
  final double height;

  @override
  Widget build(BuildContext context) {
    final f = jornada.fecha;
    final dia = DateFormat('EEEE', 'es').format(f);
    final mes = DateFormat('MMMM yyyy', 'es').format(f);
    final t = Theme.of(context).textTheme;
    return Container(
      color: Fz.azul,
      child: CustomPaint(
        painter: PawPatternPainter(),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(dia[0].toUpperCase() + dia.substring(1), style: t.labelLarge?.copyWith(color: Fz.azul50)),
            Text('${f.day}', style: Fz.display(height * .36, color: Fz.tarjeta)),
            Text(mes, style: t.labelLarge?.copyWith(color: Fz.azul50)),
          ]),
        ),
      ),
    );
  }
}

class JornadaCard extends StatelessWidget {
  const JornadaCard({super.key, required this.jornada, this.alterna = false});
  final Jornada jornada;
  final bool alterna;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final j = jornada;
    final libres = j.cuposLibres ?? j.cuposTotal;
    final agotada = libres <= 0;
    final frac = j.cuposTotal == 0 ? 0.0 : (libres / j.cuposTotal).clamp(0.0, 1.0);
    final fecha = DateFormat("EEE d 'de' MMM · h:mm a", 'es').format(j.fecha);
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      padding: const EdgeInsets.all(10),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JornadaDetailScreen(jornada: j))),
      child: Column(children: [
        JornadaPortada(jornada: j),
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
          child: Column(children: [
            Text(j.titulo, textAlign: TextAlign.center, style: t.titleLarge),
            const SizedBox(height: 4),
            Text(fecha[0].toUpperCase() + fecha.substring(1), textAlign: TextAlign.center, style: t.bodyMedium),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Fz.azul),
              const SizedBox(width: 4),
              Flexible(
                child: Text('${j.sede} · ${j.ciudad}',
                    textAlign: TextAlign.center, style: t.bodySmall, overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 12),
            if (agotada)
              const StatusPill('Agotada · sin cupos', icon: Icons.block_rounded, color: Fz.frambuesaSuave)
            else ...[
              Text('Quedan $libres de ${j.cuposTotal} cupos', style: t.titleSmall),
              const SizedBox(height: 6),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Fz.tinta, width: 2),
                  color: Fz.tarjeta,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: frac,
                      child: Container(color: frac < .2 ? Fz.frambuesa : Fz.azul),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
              const StatusPill('Gatos desde \$10 · perros desde \$25', icon: Icons.sell_rounded, color: Fz.azul100),
              if (j.limpiezaDental) const StatusPill('Limpieza dental', icon: Icons.add_circle_rounded, color: Fz.tarjeta),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('Ver jornada', style: t.labelLarge?.copyWith(color: Fz.azul)),
              const Icon(Icons.chevron_right_rounded, color: Fz.azul),
            ]),
          ]),
        ),
      ]),
    );
  }
}
