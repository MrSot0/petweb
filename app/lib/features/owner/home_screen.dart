import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../citas/solicitar_visita_screen.dart';
import '../citas/visita_comun.dart';
import 'mis_citas_screen.dart';
import 'mis_pagos_screen.dart';
import 'owner_shell.dart';
import 'precios_screen.dart';

/// Inicio del propietario: saludo, próxima cita (con QR), accesos y tasa euro BCV.
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

  /// "Ver todas mis citas" lleva a la pestaña Citas.
  void _misCitas() => OwnerShell.irA(context, 2);

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _refresh();
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
            final accesos = [
              _Acceso(icon: Icons.event_rounded, titulo: 'Jornadas', sub: 'Fechas y cupos', onTap: () => OwnerShell.irA(context, 1)),
              _Acceso(
                  icon: Icons.calendar_month_rounded, titulo: 'Citas', sub: 'Tu QR y visitas', onTap: () => OwnerShell.irA(context, 2)),
              _Acceso(
                icon: Icons.add_home_rounded,
                titulo: 'Pedir visita',
                sub: 'Veterinario a domicilio',
                onTap: () => _abrir(const SolicitarVisitaScreen()),
              ),
              _Acceso(
                icon: Icons.receipt_long_rounded,
                titulo: 'Mis pagos',
                sub: 'Pagar y ver estado',
                onTap: () => _abrir(const MisPagosScreen()),
              ),
              _Acceso(icon: Icons.pets_rounded, titulo: 'Mis mascotas', sub: 'Fotos y datos', onTap: () => OwnerShell.irA(context, 3)),
              _Acceso(
                icon: Icons.sell_rounded,
                titulo: 'Precios',
                sub: 'Gatos desde \$10',
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PreciosScreen())),
              ),
            ];
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  FadeSlideIn(child: _Saludo(perfil: d.perfil)),
                  const SizedBox(height: 16),
                  FadeSlideIn(
                    index: 1,
                    child: d.proxima != null ? _ProximaCita(i: d.proxima!, onMisCitas: _misCitas) : const _SinCita(),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 22, 4, 12),
                    child: Text('¿Qué quieres hacer?',
                        textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
                  ),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.05,
                    children: [
                      for (var k = 0; k < accesos.length; k++)
                        FadeSlideIn(
                          index: k + 2,
                          child: _AccesoTile(a: accesos[k], alterna: k % 4 == 1 || k % 4 == 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  FadeSlideIn(index: 8, child: _TasaCard(tasa: d.tasa, error: d.tasaError)),
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
    final nombre = ((perfil?['nombre'] as String?) ?? '').trim();
    final pila = nombre.isEmpty ? '' : nombre.split(RegExp(r'\s+')).first;
    final hoy = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());
    return FzHero(
      leading: FzAvatar(
        url: Data.fotoUrl(perfil?['avatar_path'] as String?),
        text: iniciales(nombre),
        size: 76,
        color: Fz.azul100,
      ),
      title: pila.isEmpty ? '¡Hola!' : 'Hola, $pila',
      subtitle: hoy[0].toUpperCase() + hoy.substring(1),
    );
  }
}

class _ProximaCita extends StatelessWidget {
  const _ProximaCita({required this.i, required this.onMisCitas});
  final Map<String, dynamic> i;
  final VoidCallback onMisCitas;

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
    final hayCodigo = i['codigo'] != null;
    return PopCard(
      color: Fz.azul50,
      child: Column(children: [
        Text('Tu próxima cita', textAlign: TextAlign.center, style: t.titleSmall?.copyWith(color: Fz.azul700)),
        const SizedBox(height: 4),
        Text('${pet['nombre'] ?? 'Tu mascota'} · $servicio', textAlign: TextAlign.center, style: t.headlineSmall),
        const SizedBox(height: 8),
        pillEstadoInscripcion(i['estado'] as String?),
        const SizedBox(height: 10),
        Text(faltan, textAlign: TextAlign.center, style: t.titleLarge?.copyWith(color: Fz.azul)),
        Text(Money.fechaLarga(fecha), textAlign: TextAlign.center, style: t.bodyMedium),
        Text('${j['sede_nombre'] ?? ''}', textAlign: TextAlign.center, style: t.bodySmall),
        if (hayCodigo) ...[
          const SizedBox(height: 2),
          CodigoCopiable('${i['codigo']}'),
        ],
        const SizedBox(height: 12),
        if (hayCodigo)
          PopButton(
            label: 'Mi código QR',
            icon: Icons.qr_code_2_rounded,
            onPressed: () => mostrarCodigoQr(context, i),
          ),
        if (i['estado'] == 'pendiente_pago') ...[
          const SizedBox(height: 10),
          PopButton.tonal(
            label: 'Ir a pagar',
            icon: Icons.payments_rounded,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisPagosScreen())),
          ),
        ],
        const SizedBox(height: 4),
        TextButton.icon(onPressed: onMisCitas, icon: const Icon(Icons.list_alt_rounded), label: const Text('Ver todas mis citas')),
      ]),
    );
  }
}

class _SinCita extends StatelessWidget {
  const _SinCita();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: Fz.azul50,
      child: Column(children: [
        const Icon(Icons.event_note_rounded, size: 34, color: Fz.azul),
        const SizedBox(height: 6),
        Text('Aún no tienes citas', textAlign: TextAlign.center, style: t.titleMedium),
        const SizedBox(height: 2),
        Text('Busca una jornada cerca de ti e inscribe a tus mascotas.', textAlign: TextAlign.center, style: t.bodyMedium),
        const SizedBox(height: 12),
        PopButton(label: 'Ver jornadas', icon: Icons.event_rounded, expand: false, onPressed: () => OwnerShell.irA(context, 1)),
      ]),
    );
  }
}

class _Acceso {
  const _Acceso({required this.icon, required this.titulo, required this.sub, required this.onTap});
  final IconData icon;
  final String titulo;
  final String sub;
  final VoidCallback onTap;
}

class _AccesoTile extends StatelessWidget {
  const _AccesoTile({required this.a, required this.alterna});
  final _Acceso a;
  final bool alterna;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      onTap: a.onTap,
      padding: const EdgeInsets.all(12),
      child: Semantics(
        button: true,
        label: a.titulo,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Fz.azul,
              shape: BoxShape.circle,
              border: Border.all(color: Fz.tinta, width: Fz.borde),
            ),
            child: Icon(a.icon, size: 32, color: Fz.tarjeta),
          ),
          const SizedBox(height: 10),
          Text(a.titulo, textAlign: TextAlign.center, style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(a.sub, textAlign: TextAlign.center, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
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
      color: Fz.tarjeta,
      child: Column(children: [
        const Icon(Icons.currency_exchange_rounded, size: 28, color: Fz.azul),
        const SizedBox(height: 4),
        if (tasa == null) ...[
          Text('Tasa euro BCV', textAlign: TextAlign.center, style: t.titleMedium),
          const SizedBox(height: 2),
          Text(
            error
                ? 'No pudimos actualizar la tasa. El monto en Bs se confirma al pagar; los precios en \$ no cambian.'
                : 'Tasa no disponible; el monto en Bs se confirma al pagar.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
        ] else ...[
          Text('Tasa euro BCV · fecha valor ${Money.fecha(tasa.fechaValor)}', textAlign: TextAlign.center, style: t.bodySmall),
          Text('${Money.tasa(tasa.valor)} por euro', textAlign: TextAlign.center, style: t.headlineSmall),
          const SizedBox(height: 2),
          Text('Precios en \$ · gata \$15 = ${Money.bs(Money.aBs(15, tasa.valor))}',
              textAlign: TextAlign.center, style: t.bodyMedium),
          if (tasa.vieja) ...[
            const SizedBox(height: 8),
            StatusPill(
              'Tasa del ${DateFormat('dd/MM').format(tasa.fechaValor)}, puede variar',
              icon: Icons.warning_amber_rounded,
              color: Fz.azul50,
              dashed: true,
            ),
          ],
        ],
      ]),
    );
  }
}
