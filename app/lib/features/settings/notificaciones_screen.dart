import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/notificaciones.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Campana con contador de no leídas. Ponla en cualquier AppBar (`actions: [CampanaNotificaciones()]`)
/// o en una cabecera. Abre la bandeja de notificaciones.
class CampanaNotificaciones extends StatelessWidget {
  const CampanaNotificaciones({super.key, this.color = Fz.tinta, this.fondo});

  /// Color del icono.
  final Color color;

  /// Fondo circular opcional (por ejemplo `Fz.tarjeta` sobre una cabecera azul).
  final Color? fondo;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Notificaciones.noLeidas,
      builder: (context, n, _) {
        final etiqueta = n == 0 ? 'Notificaciones' : 'Notificaciones, $n sin leer';
        final icono = Badge(
          isLabelVisible: n > 0,
          backgroundColor: Fz.frambuesa,
          textColor: Fz.tarjeta,
          label: Text(n > 99 ? '99+' : '$n'),
          child: Icon(n > 0 ? Icons.notifications_active_rounded : Icons.notifications_rounded, color: color),
        );
        return Semantics(
          button: true,
          label: etiqueta,
          excludeSemantics: true,
          child: IconButton(
            tooltip: etiqueta,
            style: fondo == null
                ? null
                : IconButton.styleFrom(
                    backgroundColor: fondo,
                    side: const BorderSide(color: Fz.tinta, width: Fz.borde),
                  ),
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: icono,
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificacionesScreen())),
          ),
        );
      },
    );
  }
}

/// Bandeja de notificaciones del usuario (las crea el servidor).
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<Map<String, dynamic>>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load(marcar: true);
  }

  Future<void> _load({bool marcar = false}) async {
    setState(() => _error = null);
    try {
      final rows = await Data.notificaciones();
      if (!mounted) return;
      setState(() => _items = rows);
      // Se muestran resaltadas las que llegaron sin leer; luego se marcan como leídas.
      if (marcar || rows.any((r) => r['leida'] != true)) await Notificaciones.marcarLeidas();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones'), centerTitle: true),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null && _items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tus notificaciones',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    if (items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: const [
            SizedBox(height: 80),
            EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Sin notificaciones',
              message: 'Aquí verás los avisos de tus pagos, citas, jornadas y mascotas.',
            ),
          ],
        ),
      );
    }
    final sinLeer = items.where((r) => r['leida'] != true).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        itemCount: items.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                sinLeer == 0
                    ? 'Estás al día'
                    : sinLeer == 1
                    ? '1 notificación nueva'
                    : '$sinLeer notificaciones nuevas',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Fz.variante),
              ),
            );
          }
          return FadeSlideIn(
            index: i - 1,
            child: Padding(padding: const EdgeInsets.only(bottom: 12), child: _Tarjeta(items[i - 1])),
          );
        },
      ),
    );
  }
}

/// Icono por tipo: pago_nuevo, pago, inscripcion, mascota_lista, visita_nueva, visita_asignada, visita.
IconData iconoNotificacion(String? tipo) => switch (tipo) {
  'mascota_lista' => Icons.celebration_rounded,
  'pago_nuevo' => Icons.receipt_long_rounded,
  'pago' => Icons.payments_rounded,
  'inscripcion' => Icons.event_available_rounded,
  'visita_nueva' => Icons.home_work_rounded,
  'visita_asignada' => Icons.assignment_ind_rounded,
  'visita' => Icons.directions_car_rounded,
  _ => Icons.notifications_rounded,
};

String haceCuanto(DateTime? d) {
  if (d == null) return '';
  final s = DateTime.now().difference(d.toLocal());
  if (s.inMinutes < 1) return 'Hace un momento';
  if (s.inMinutes < 60) return 'Hace ${s.inMinutes} min';
  if (s.inHours < 24) return s.inHours == 1 ? 'Hace 1 hora' : 'Hace ${s.inHours} horas';
  if (s.inDays == 1) return 'Ayer';
  if (s.inDays < 7) return 'Hace ${s.inDays} días';
  if (s.inDays < 30) {
    final w = s.inDays ~/ 7;
    return w == 1 ? 'Hace 1 semana' : 'Hace $w semanas';
  }
  final l = d.toLocal();
  return '${l.day.toString().padLeft(2, '0')}/${l.month.toString().padLeft(2, '0')}/${l.year}';
}

class _Tarjeta extends StatelessWidget {
  const _Tarjeta(this.n);
  final Map<String, dynamic> n;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tipo = n['tipo'] as String?;
    final nueva = n['leida'] != true;
    final lista = tipo == 'mascota_lista';
    final fecha = DateTime.tryParse(n['created_at']?.toString() ?? '');
    final titulo = (n['titulo'] as String?)?.trim();
    final cuerpo = (n['cuerpo'] as String?)?.trim();

    // Destacadas: mascota lista (azul fuerte) y no leídas (azul suave).
    final fondo = lista ? Fz.azul : (nueva ? Fz.azul100 : Fz.tarjeta);
    final texto = lista ? Fz.tarjeta : Fz.tinta;
    final secundario = lista ? Fz.azul50 : Fz.variante;

    return Semantics(
      container: true,
      label: nueva ? 'Nueva' : null,
      child: PopCard(
        color: fondo,
        shadow: nueva || lista,
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: lista ? Fz.tarjeta : (nueva ? Fz.azul : Fz.azul50),
                shape: BoxShape.circle,
                border: Border.all(color: Fz.tinta, width: Fz.borde),
              ),
              child: Icon(iconoNotificacion(tipo), size: 24, color: lista ? Fz.azul : (nueva ? Fz.tarjeta : Fz.azul)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          titulo == null || titulo.isEmpty ? 'FAUNAZULIA' : titulo,
                          style: t.titleMedium?.copyWith(color: texto, fontWeight: nueva ? FontWeight.w800 : null),
                        ),
                      ),
                      if (nueva) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: lista ? Fz.tarjeta : Fz.azul,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: Fz.tinta, width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.fiber_new_rounded, size: 14, color: lista ? Fz.azul : Fz.tarjeta),
                              const SizedBox(width: 3),
                              Text(
                                'Nueva',
                                style: t.labelSmall?.copyWith(
                                  color: lista ? Fz.azul : Fz.tarjeta,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (cuerpo != null && cuerpo.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(cuerpo, style: t.bodyMedium?.copyWith(color: texto)),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.schedule_rounded, size: 14, color: secundario),
                      const SizedBox(width: 4),
                      Text(haceCuanto(fecha), style: t.bodySmall?.copyWith(color: secundario)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
