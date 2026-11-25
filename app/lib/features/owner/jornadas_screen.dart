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
      appBar: AppBar(title: const Text('Jornadas próximas')),
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
          return RefreshIndicator(
            onRefresh: _refresh,
            child: list.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: const [
                      SizedBox(height: 60),
                      EmptyState(
                        icon: Icons.event_busy_rounded,
                        title: 'No hay jornadas por ahora',
                        message: 'Estamos preparando las próximas fechas. Desliza hacia abajo para actualizar.',
                      ),
                    ],
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: list.length + 1,
                    separatorBuilder: (_, _) => const SizedBox(height: 14),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return const PopCard(
                          shadow: false,
                          color: Fz.azulPastel,
                          padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          child: Row(children: [
                            Icon(Icons.medical_services_rounded, size: 20),
                            SizedBox(width: 8),
                            Expanded(child: Text('Kit post-operatorio recomendado: +\$5 gato / +\$7 perro')),
                          ]),
                        );
                      }
                      return JornadaCard(jornada: list[i - 1]);
                    },
                  ),
          );
        },
      ),
    );
  }
}

class JornadaCard extends StatelessWidget {
  const JornadaCard({super.key, required this.jornada});
  final Jornada jornada;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final j = jornada;
    final libres = j.cuposLibres ?? j.cuposTotal;
    final agotada = libres <= 0;
    final frac = j.cuposTotal == 0 ? 0.0 : (libres / j.cuposTotal).clamp(0.0, 1.0);
    final dia = DateFormat('EEE', 'es').format(j.fecha).replaceAll('.', '');
    final mes = DateFormat('MMM', 'es').format(j.fecha).replaceAll('.', '');
    return PopCard(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => JornadaDetailScreen(jornada: j))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 72,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: agotada ? Fz.cremaClaro : Fz.rosa,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Fz.tinta, width: 2),
            ),
            child: Column(children: [
              Text(dia, style: t.titleSmall),
              Text('${j.fecha.day}', style: Fz.display(32)),
              Text(mes, style: t.titleSmall),
            ]),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(j.titulo, style: t.titleLarge),
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.location_on_rounded, size: 18, color: Fz.variante),
                const SizedBox(width: 4),
                Expanded(child: Text('${j.sede} · ${j.ciudad}', style: t.bodyMedium)),
              ]),
              Row(children: [
                const Icon(Icons.schedule_rounded, size: 18, color: Fz.variante),
                const SizedBox(width: 4),
                Text(DateFormat('h:mm a', 'es').format(j.fecha), style: t.bodyMedium),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        if (agotada)
          const StatusPill('Agotada · sin cupos', icon: Icons.block_rounded, color: Fz.frambuesaSuave)
        else ...[
          Row(children: [
            const Icon(Icons.check_circle_rounded, size: 18),
            const SizedBox(width: 6),
            Text('Quedan $libres de ${j.cuposTotal} cupos', style: t.titleSmall),
          ]),
          const SizedBox(height: 6),
          Container(
            height: 14,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Fz.tinta, width: 2),
              color: Fz.cremaClaro,
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
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text('desde \$10 gatos · desde \$25 perros', style: t.titleSmall)),
          if (j.limpiezaDental) const StatusPill('Limpieza dental', icon: Icons.add_circle_rounded),
        ]),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Ver jornada', style: Fz.display(16, w: FontWeight.w700, color: Fz.azul)),
            const Icon(Icons.chevron_right_rounded, color: Fz.azul),
          ]),
        ),
      ]),
    );
  }
}
