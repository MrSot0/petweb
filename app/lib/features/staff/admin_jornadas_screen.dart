import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import 'honorarios_admin_screen.dart';
import 'jornada_detalle_screen.dart';
import 'jornada_form_screen.dart';
import 'stats_screen.dart';
import 'tasa_screen.dart' show parseBs;

export 'jornada_detalle_screen.dart';
export 'jornada_form_screen.dart';

const estadosJornada = ['borrador', 'publicada', 'cerrada', 'finalizada', 'cancelada'];

String estadoJornadaTexto(String e) => switch (e) {
      'borrador' => 'Borrador',
      'publicada' => 'Publicada',
      'cerrada' => 'Inscripciones cerradas',
      'finalizada' => 'Finalizada',
      'cancelada' => 'Cancelada',
      _ => e,
    };

Widget estadoJornadaPill(String e) => switch (e) {
      'publicada' => const StatusPill('Publicada', icon: Icons.public_rounded, color: Fz.azul100),
      'borrador' => const StatusPill('Borrador', icon: Icons.edit_note_rounded, color: Fz.tarjeta, dashed: true),
      'cerrada' => const StatusPill('Cerrada', icon: Icons.lock_rounded, color: Fz.azul200),
      'finalizada' => const StatusPill('Finalizada', icon: Icons.flag_rounded, color: Fz.azul50),
      'cancelada' => const StatusPill('Cancelada', icon: Icons.cancel_rounded, color: Fz.frambuesaSuave),
      _ => StatusPill(e),
    };

String estadoInscripcionTexto(String? e) => switch (e) {
      'precio_por_confirmar' => 'Precio por confirmar',
      'pendiente_pago' => 'Pendiente de pago',
      'pago_en_revision' => 'Pago en revisión',
      'confirmada' => 'Confirmada',
      'atendida' => 'Atendida',
      'cancelada' => 'Cancelada',
      'retirada' => 'Retirada',
      _ => e ?? '—',
    };

IconData estadoInscripcionIcono(String? e) => switch (e) {
      'precio_por_confirmar' => Icons.help_rounded,
      'pendiente_pago' => Icons.hourglass_top_rounded,
      'pago_en_revision' => Icons.fact_check_rounded,
      'confirmada' => Icons.check_circle_rounded,
      'atendida' => Icons.medical_services_rounded,
      _ => Icons.cancel_rounded,
    };

/// Diálogo para fijar el precio total (USD) de una inscripción "precio por confirmar".
/// Acepta la inscripción con 'pets' (consultas directas) o 'pet' (ficha de participantes).
/// Devuelve true si se guardó.
Future<bool> mostrarFijarPrecio(BuildContext context, Map<String, dynamic> inscripcion) async {
  final pet = (inscripcion['pets'] as Map?) ?? (inscripcion['pet'] as Map?) ?? const {};
  final id = inscripcion['id']?.toString();
  if (id == null) return false;
  final ctrl = TextEditingController();
  final key = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) {
      var saving = false;
      return StatefulBuilder(builder: (c, setD) {
        Future<void> guardar() async {
          if (key.currentState?.validate() != true) return;
          final monto = parseBs(ctrl.text);
          if (monto == null) return;
          setD(() => saving = true);
          try {
            await Data.fijarPrecio(id, monto);
            if (c.mounted) Navigator.pop(c, true);
          } catch (e) {
            setD(() => saving = false);
            if (c.mounted) showError(c, e);
          }
        }

        return AlertDialog(
          title: const Text('Fijar precio', textAlign: TextAlign.center),
          content: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(
                '${pet['nombre'] ?? 'Mascota'}'
                '${pet['peso_kg'] != null ? ' · ${pet['peso_kg']} kg' : ''}'
                '${pet['braquiocefalico'] == true ? ' · braquiocefálico' : ''}',
                textAlign: TextAlign.center,
                style: Theme.of(c).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: r'Precio total en $', prefixText: r'$ '),
                validator: (v) {
                  final n = parseBs(v ?? '');
                  if (n == null || n <= 0) return 'Escribe un monto mayor que cero';
                  if (n > 2000) return 'El monto parece demasiado alto';
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Text('Incluye kit y cono si los eligió. El propietario podrá pagar después.',
                  textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodySmall),
            ]),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(onPressed: saving ? null : guardar, child: Text(saving ? 'Guardando…' : 'Guardar')),
          ],
        );
      });
    },
  );
  ctrl.dispose();
  if (ok == true && context.mounted) showInfo(context, 'Precio fijado');
  return ok == true;
}

/// Portada de jornada: foto cargada por el admin o banda azul con huellas.
class JornadaPortada extends StatelessWidget {
  const JornadaPortada({super.key, required this.jornada, this.height = 130, this.radius = 0});
  final Jornada jornada;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final url = jornada.imagenUrl;
    final fallback = Container(
      color: Fz.azul700,
      child: CustomPaint(
        painter: PawPatternPainter(),
        child: const Center(child: Icon(Icons.event_rounded, size: 42, color: Fz.azul100)),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: url == null
            ? fallback
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => fallback,
                loadingBuilder: (_, child, p) => p == null ? child : Container(color: Fz.azul100),
              ),
      ),
    );
  }
}

/// Jornadas del equipo (administración y contador). Solo administración crea o edita.
class AdminJornadasScreen extends StatefulWidget {
  const AdminJornadasScreen({super.key});

  @override
  State<AdminJornadasScreen> createState() => _AdminJornadasScreenState();
}

class _AdminJornadasScreenState extends State<AdminJornadasScreen> {
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
      final r = await Data.jornadas(todas: true);
      r.sort((a, b) => b.fecha.compareTo(a.fecha));
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _nueva() async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => const JornadaFormScreen()));
    if (r == true) _load();
  }

  Future<void> _abrir(Jornada j) async {
    await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => JornadaDetalleScreen(jornada: j)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppMode.of(context).isAdmin;
    return Scaffold(
      appBar: AppBar(title: const Text('Jornadas')),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: _nueva,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva jornada'),
            )
          : null,
      body: _body(admin),
    );
  }

  Widget _body(bool admin) {
    if (_error != null && _items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar las jornadas',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    final proximas = items.where((j) => j.fecha.isAfter(DateTime.now()) && j.estado == 'publicada').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        FadeSlideIn(
          child: FzHero(
            title: items.isEmpty ? 'Jornadas' : '${items.length} ${items.length == 1 ? 'jornada' : 'jornadas'}',
            subtitle: proximas == 0
                ? 'Toca una jornada para ver participantes y estadísticas.'
                : '$proximas ${proximas == 1 ? 'publicada y próxima' : 'publicadas y próximas'} · toca una para ver participantes',
            leading: const Icon(Icons.event_available_rounded, color: Fz.tarjeta, size: 34),
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => const HonorariosAdminScreen())),
              icon: const Icon(Icons.medical_services_rounded),
              label: const Text('Honorarios de cirujanos'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(
          index: 1,
          child: PopCard(
            color: Fz.azul100,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EstadisticasScreen())),
            child: Row(children: [
              const FzAvatar(icon: Icons.insights_rounded, size: 46, color: Fz.tarjeta),
              const SizedBox(width: 12),
              Expanded(
                child: Column(children: [
                  Text('Estadísticas generales', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                  Text('Todas las jornadas, con selector por jornada',
                      textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                ]),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right_rounded, color: Fz.azul),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          EmptyState(
            icon: Icons.event_busy_rounded,
            title: 'Aún no hay jornadas',
            message: admin ? 'Crea la primera con "Nueva jornada".' : 'Cuando administración cree una, aparecerá aquí.',
            action: admin
                ? PopButton(label: 'Nueva jornada', icon: Icons.add_rounded, onPressed: _nueva, expand: false)
                : null,
          )
        else
          for (final (i, j) in items.indexed) ...[
            FadeSlideIn(index: i + 2, child: JornadaStaffCard(jornada: j, onTap: () => _abrir(j), alt: i.isOdd)),
            const SizedBox(height: 14),
          ],
      ]),
    );
  }
}

/// Tarjeta de jornada con portada, fecha, sede y cupos.
class JornadaStaffCard extends StatelessWidget {
  const JornadaStaffCard({super.key, required this.jornada, this.onTap, this.alt = false});
  final Jornada jornada;
  final VoidCallback? onTap;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final j = jornada;
    final libres = j.cuposLibres;
    final ocupados = libres == null ? null : (j.cuposTotal - libres).clamp(0, j.cuposTotal);
    return PopCard(
      onTap: onTap,
      color: alt ? Fz.azul50 : Fz.tarjeta,
      padding: EdgeInsets.zero,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Stack(children: [
          JornadaPortada(
            jornada: j,
            height: 128,
            radius: Fz.radioTarjeta - 2,
          ),
          Positioned(top: 10, right: 10, child: estadoJornadaPill(j.estado)),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(j.titulo, textAlign: TextAlign.center, style: t.titleLarge),
            const SizedBox(height: 6),
            Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 4, children: [
              _meta(t, Icons.calendar_month_rounded, Money.fechaLarga(j.fecha)),
              _meta(t, Icons.place_rounded, '${j.sede} · ${j.ciudad}'),
              if (j.limpiezaDental) _meta(t, Icons.clean_hands_rounded, 'Con limpieza dental'),
            ]),
            const SizedBox(height: 10),
            Text(
              ocupados == null ? '${j.cuposTotal} cupos' : '$ocupados de ${j.cuposTotal} cupos ocupados · $libres libres',
              textAlign: TextAlign.center,
              style: t.titleSmall,
            ),
            if (ocupados != null && j.cuposTotal > 0) ...[
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(value: ocupados / j.cuposTotal, minHeight: 8),
              ),
            ],
          ]),
        ),
      ]),
    );
  }

  Widget _meta(TextTheme t, IconData ic, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 16, color: Fz.azul),
        const SizedBox(width: 4),
        Flexible(child: Text(s, style: t.bodySmall)),
      ]);
}
