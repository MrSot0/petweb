import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../owner/mis_citas_screen.dart';
import '../owner/mis_pagos_screen.dart';
import 'solicitar_visita_screen.dart';
import 'visita_comun.dart';
import 'visita_detalle_screen.dart';

/// Pestaña "Citas" del propietario: inscripciones a jornadas (con QR) y visitas/consultas a domicilio.
class CitasScreen extends StatefulWidget {
  const CitasScreen({super.key});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  int _seg = 0;

  void _misPagos() => Navigator.push(context, MaterialPageRoute(builder: (_) => const MisPagosScreen()));

  Widget _header(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FadeSlideIn(
          child: FzHero(
            title: 'Mis citas',
            subtitle: _seg == 0 ? 'Jornadas de esterilización y tu código QR' : 'Veterinario a domicilio y consultas',
            leading: const Icon(Icons.calendar_month_rounded, size: 36, color: Fz.tarjeta),
            child: PopButton.tonal(
              label: 'Mis pagos',
              icon: Icons.receipt_long_rounded,
              expand: false,
              onPressed: _misPagos,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 0, icon: Icon(Icons.event_rounded), label: Text('Jornadas', textAlign: TextAlign.center)),
            ButtonSegment(
              value: 1,
              icon: Icon(Icons.home_rounded),
              label: Text('Visitas y consultas', textAlign: TextAlign.center, maxLines: 2),
            ),
          ],
          selected: {_seg},
          onSelectionChanged: (s) => setState(() => _seg = s.first),
        ),
      ]);

  @override
  Widget build(BuildContext context) {
    final header = _header(context);
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _seg, children: [
          MisCitasBody(header: header),
          _VisitasBody(header: header),
        ]),
      ),
    );
  }
}

/// Lista de visitas a domicilio y consultas del propietario.
class _VisitasBody extends StatefulWidget {
  const _VisitasBody({required this.header});
  final Widget header;

  @override
  State<_VisitasBody> createState() => _VisitasBodyState();
}

class _VisitasBodyState extends State<_VisitasBody> {
  List<Map<String, dynamic>>? _visitas;
  Map<String, Pet> _pets = {};
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final petsF = Data.misMascotas().then<List<Pet>?>((v) => v).catchError((_) => null);
      final r = await Data.misVisitas();
      final pets = await petsF;
      if (!mounted) return;
      setState(() {
        _visitas = r;
        if (pets != null) _pets = {for (final p in pets) p.id: p};
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pedir() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const SolicitarVisitaScreen()));
    if (mounted) _load();
  }

  Future<void> _abrir(Map<String, dynamic> v) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => VisitaDetalleScreen(visita: v)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final children = <Widget>[widget.header, const SizedBox(height: 16)];
    children.add(FadeSlideIn(
      index: 1,
      child: PopButton(label: 'Pedir visita o consulta', icon: Icons.add_home_rounded, onPressed: _pedir),
    ));
    children.add(const SizedBox(height: 6));
    children.add(Text('Un veterinario va a tu casa. La administración confirma la fecha, la hora y el precio.',
        textAlign: TextAlign.center, style: t.bodySmall));
    children.add(const SizedBox(height: 12));

    if (_error != null && _visitas == null) {
      children.add(EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tus visitas',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: _load, expand: false),
      ));
    } else if (_visitas == null) {
      children.add(const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())));
    } else if (_visitas!.isEmpty) {
      children.add(const EmptyState(
        icon: Icons.home_rounded,
        title: 'Aún no has pedido visitas',
        message: 'Pide una consulta, vacuna o control en casa y aquí verás su estado.',
      ));
    } else {
      final activas = _visitas!.where((v) => v['estado'] != 'finalizada' && v['estado'] != 'cancelada').toList();
      final pasadas = _visitas!.where((v) => v['estado'] == 'finalizada' || v['estado'] == 'cancelada').toList();
      var n = 1;
      Widget titulo(String x) => Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 10),
            child: Text(x, textAlign: TextAlign.center, style: t.headlineSmall),
          );
      if (activas.isNotEmpty) children.add(titulo('En curso'));
      for (final v in activas) {
        children.add(FadeSlideIn(
          index: ++n,
          child: _VisitaCard(v: v, pets: _pets, alterna: n.isEven, onTap: () => _abrir(v)),
        ));
        children.add(const SizedBox(height: 14));
      }
      if (pasadas.isNotEmpty) children.add(titulo('Anteriores'));
      for (final v in pasadas) {
        children.add(FadeSlideIn(
          index: ++n,
          child: _VisitaCard(v: v, pets: _pets, alterna: n.isEven, compacta: true, onTap: () => _abrir(v)),
        ));
        children.add(const SizedBox(height: 12));
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: children,
      ),
    );
  }
}

class _VisitaCard extends StatelessWidget {
  const _VisitaCard({required this.v, required this.pets, required this.onTap, this.alterna = false, this.compacta = false});
  final Map<String, dynamic> v;
  final Map<String, Pet> pets;
  final VoidCallback onTap;
  final bool alterna;
  final bool compacta;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final estado = v['estado'] as String?;
    final vet = v['veterinario'] as Map?;
    final ids = [for (final id in (v['pet_ids'] as List? ?? const [])) '$id'];
    final nombres = [for (final id in ids) pets[id]?.nombre ?? 'Mascota'].join(', ');
    final precio = precioVisita(v);
    final pagoPill = pillPagoVisita(v);
    final porPagar = puedePagarVisita(v);
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      shadow: !compacta,
      onTap: onTap,
      child: Column(children: [
        Row(children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: estado == 'cancelada' ? Fz.frambuesaSuave : Fz.azul,
              shape: BoxShape.circle,
              border: Border.all(color: Fz.tinta, width: Fz.borde),
            ),
            child: Icon(iconoEstadoVisita(estado), color: estado == 'cancelada' ? Fz.tinta : Fz.tarjeta),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(nombreServicioVisita(v), style: t.titleMedium),
              if (nombres.isNotEmpty) Text(nombres, style: t.bodySmall),
              Text(fechaVisitaTexto(v), style: t.bodySmall),
              if (vet?['nombre'] != null) Text('Veterinario: ${vet!['nombre']}', style: t.bodySmall),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded, color: Fz.azul),
        ]),
        const SizedBox(height: 10),
        Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
          pillEstadoVisita(estado),
          StatusPill(
            precio == null ? 'Precio por confirmar' : Money.usd(precio),
            icon: precio == null ? Icons.hourglass_top_rounded : Icons.sell_rounded,
            color: Fz.tarjeta,
            dashed: precio == null,
          ),
          ?pagoPill,
        ]),
        if (v['codigo'] != null) CodigoCopiable('${v['codigo']}'),
        if (porPagar && !compacta)
          Text('Ya tiene precio: toca para ver el detalle y pagar.',
              textAlign: TextAlign.center, style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
      ]),
    );
  }
}
