import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'owner_shell.dart';
import 'precios_screen.dart';

/// Inicio del propietario: saludo, próxima cita, accesos y tasa euro BCV.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeData {
  _HomeData(this.perfil, this.proxima, this.tasa, this.tasaError);
  final Map<String, dynamic>? perfil;
  final Map<String, dynamic>? proxima;
  final Tasa? tasa;
  final bool tasaError;
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<_HomeData> _f = _load();

  Future<_HomeData> _load() async {
    final perfilF = Data.miPerfil();
    final inscF = Data.misInscripciones();
    Tasa? tasa;
    var tasaError = false;
    try {
      tasa = await Data.tasaVigente();
    } catch (_) {
      tasaError = true;
    }
    final perfil = await perfilF;
    final insc = await inscF;
    final hoy = DateTime.now().subtract(const Duration(hours: 12));
    final activas = insc.where((i) {
      final e = i['estado'] as String?;
      if (e == 'cancelada' || e == 'atendida') return false;
      final f = _fechaDe(i);
      return f != null && f.isAfter(hoy);
    }).toList()
      ..sort((a, b) => _fechaDe(a)!.compareTo(_fechaDe(b)!));
    return _HomeData(perfil, activas.isEmpty ? null : activas.first, tasa, tasaError);
  }

  static DateTime? _fechaDe(Map<String, dynamic> i) {
    final s = (i['jornadas'] as Map?)?['fecha_inicio'] as String?;
    return s == null ? null : DateTime.tryParse(s)?.toLocal();
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FutureBuilder<_HomeData>(
          future: _f,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'No pudimos cargar el inicio',
                message: friendlyError(snap.error!),
                action: PopButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: _refresh, expand: false),
              );
            }
            final d = snap.data!;
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _Saludo(perfil: d.perfil),
                  const SizedBox(height: 16),
                  if (d.proxima != null) _ProximaCita(i: d.proxima!) else const _SinCita(),
                  const SectionTitle('¿Qué quieres hacer?'),
                  _Acceso(
                    icon: Icons.event_rounded,
                    color: Fz.azulPastel,
                    titulo: 'Jornadas',
                    sub: 'Fechas, sedes y cupos disponibles',
                    onTap: () => OwnerShell.irA(context, 1),
                  ),
                  const SizedBox(height: 12),
                  _Acceso(
                    icon: Icons.pets_rounded,
                    color: Fz.rosa,
                    titulo: 'Mis mascotas',
                    sub: 'Registra a tus perros y gatos',
                    onTap: () => OwnerShell.irA(context, 2),
                  ),
                  const SizedBox(height: 12),
                  _Acceso(
                    icon: Icons.sell_rounded,
                    color: Fz.rosaSuave,
                    titulo: 'Precios',
                    sub: 'Desde \$10 gatos · desde \$25 perros',
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreciosScreen())),
                  ),
                  const SizedBox(height: 20),
                  _TasaCard(tasa: d.tasa, error: d.tasaError),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Saludo extends StatelessWidget {
  const _Saludo({required this.perfil});
  final Map<String, dynamic>? perfil;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nombre = ((perfil?['nombre'] as String?) ?? '').trim();
    final pila = nombre.isEmpty ? '' : nombre.split(RegExp(r'\s+')).first;
    final hoy = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(hoy[0].toUpperCase() + hoy.substring(1), style: t.bodyMedium?.copyWith(color: Fz.variante)),
          Text(pila.isEmpty ? '¡Hola!' : 'Hola, $pila', style: t.displaySmall),
        ]),
      ),
      const FzLogo(size: 48),
    ]);
  }
}

/// Estado de inscripción → etiqueta con icono, texto y color.
StatusPill _pillEstado(String? e) {
  switch (e) {
    case 'precio_por_confirmar':
      return const StatusPill('Precio por confirmar', icon: Icons.hourglass_top_rounded, color: Fz.rosaSuave, dashed: true);
    case 'pendiente_pago':
      return const StatusPill('Falta pagar', icon: Icons.payments_rounded, color: Fz.rosa);
    case 'pago_en_revision':
      return const StatusPill('Pago en revisión', icon: Icons.manage_search_rounded, color: Fz.azulPastel, dashed: true);
    case 'confirmada':
      return const StatusPill('Confirmada', icon: Icons.check_circle_rounded, color: Fz.azulPastel);
    case 'atendida':
      return const StatusPill('Atendida', icon: Icons.verified_rounded, color: Fz.cremaClaro);
    case 'cancelada':
      return const StatusPill('Cancelada', icon: Icons.cancel_rounded, color: Fz.frambuesaSuave);
    default:
      return StatusPill(e ?? '—', icon: Icons.info_rounded);
  }
}

class _ProximaCita extends StatelessWidget {
  const _ProximaCita({required this.i});
  final Map<String, dynamic> i;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pet = (i['pets'] as Map?) ?? const {};
    final j = (i['jornadas'] as Map?) ?? const {};
    final fecha = DateTime.parse(j['fecha_inicio'] as String).toLocal();
    final dias = DateTime(fecha.year, fecha.month, fecha.day)
        .difference(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day))
        .inDays;
    final servicio = i['servicio'] == 'limpieza_dental' ? 'limpieza dental' : 'esterilización';
    final faltan = dias <= 0 ? 'Es hoy' : (dias == 1 ? 'Es mañana' : 'Faltan $dias días');
    return PopCard(
      color: Fz.azulPastel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_available_rounded, color: Fz.tinta),
          const SizedBox(width: 8),
          Expanded(child: Text('Tu próxima cita', style: t.titleMedium)),
          _pillEstado(i['estado'] as String?),
        ]),
        const SizedBox(height: 8),
        Text('${pet['nombre'] ?? 'Tu mascota'} · $servicio', style: t.headlineSmall),
        const SizedBox(height: 8),
        _linea(context, Icons.schedule_rounded, Money.fechaLarga(fecha)),
        _linea(context, Icons.location_on_rounded, '${j['sede_nombre'] ?? ''}'),
        _linea(context, Icons.hourglass_top_rounded, faltan),
        if (i['codigo'] != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Fz.cremaClaro,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Fz.tinta, width: 2),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.qr_code_2_rounded, size: 20),
              const SizedBox(width: 6),
              Text('Mi código: ', style: t.bodyMedium),
              Text('${i['codigo']}', style: Fz.display(17, w: FontWeight.w700)),
            ]),
          ),
        ],
        if (i['estado'] == 'pendiente_pago') ...[
          const SizedBox(height: 12),
          PopButton(label: 'Ver mis pagos', icon: Icons.receipt_long_rounded, onPressed: () => OwnerShell.irA(context, 3)),
        ],
      ]),
    );
  }

  Widget _linea(BuildContext context, IconData ic, String tx) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Icon(ic, size: 18, color: Fz.variante),
          const SizedBox(width: 6),
          Expanded(child: Text(tx, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}

class _SinCita extends StatelessWidget {
  const _SinCita();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      child: Row(children: [
        const Icon(Icons.event_note_rounded, size: 32),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Aún no tienes citas', style: t.titleMedium),
            const SizedBox(height: 2),
            Text('Busca una jornada cerca de ti e inscribe a tus mascotas.', style: t.bodyMedium),
          ]),
        ),
      ]),
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({required this.icon, required this.color, required this.titulo, required this.sub, required this.onTap});
  final IconData icon;
  final Color color;
  final String titulo;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: color,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Row(children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Fz.cremaClaro,
            shape: BoxShape.circle,
            border: Border.all(color: Fz.tinta, width: 2),
          ),
          child: Icon(icon, size: 28, color: Fz.tinta),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(titulo, style: t.titleLarge),
            Text(sub, style: t.bodyMedium),
          ]),
        ),
        const Icon(Icons.chevron_right_rounded, size: 28),
      ]),
    );
  }
}

class _TasaCard extends StatelessWidget {
  const _TasaCard({required this.tasa, required this.error});
  final Tasa? tasa;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tasa = this.tasa;
    return PopCard(
      color: Fz.cremaClaro,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.currency_exchange_rounded, size: 30),
        const SizedBox(width: 12),
        Expanded(
          child: tasa == null
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tasa euro BCV', style: t.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    error
                        ? 'No pudimos actualizar la tasa. El monto en Bs se confirma al pagar; los precios en \$ no cambian.'
                        : 'Tasa no disponible; el monto en Bs se confirma al pagar.',
                    style: t.bodyMedium,
                  ),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Tasa euro BCV · fecha valor ${Money.fecha(tasa.fechaValor)}', style: t.bodySmall),
                  Text('${Money.tasa(tasa.valor)} por euro', style: t.headlineSmall),
                  const SizedBox(height: 2),
                  Text('Precios en \$ · gata \$15 = ${Money.bs(Money.aBs(15, tasa.valor))}', style: t.bodyMedium),
                  if (tasa.vieja) ...[
                    const SizedBox(height: 8),
                    StatusPill(
                      'Tasa del ${DateFormat('dd/MM').format(tasa.fechaValor)}, puede variar',
                      icon: Icons.warning_amber_rounded,
                      color: Fz.rosaSuave,
                      dashed: true,
                    ),
                  ],
                ]),
        ),
      ]),
    );
  }
}
