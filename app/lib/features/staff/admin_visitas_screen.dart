import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import 'jornada_detalle_screen.dart' show waNumero, estadoPagoTexto;
import 'servicios_domicilio_screen.dart';
import 'tasa_screen.dart' show parseBs;
import 'verificar_screen.dart' show CodigoCopiable, staffFecha, staffNum, staffStr, staffMetodo;

// ---------------- Textos de visitas ----------------

String staffVisitaEstadoTexto(String? e) => switch (e) {
      'solicitada' => 'Solicitada',
      'confirmada' => 'Confirmada',
      'en_camino' => 'En camino',
      'en_atencion' => 'En atención',
      'finalizada' => 'Finalizada',
      'cancelada' => 'Cancelada',
      _ => e ?? '—',
    };

IconData staffVisitaEstadoIcono(String? e) => switch (e) {
      'solicitada' => Icons.mark_email_unread_rounded,
      'confirmada' => Icons.event_available_rounded,
      'en_camino' => Icons.directions_car_rounded,
      'en_atencion' => Icons.medical_services_rounded,
      'finalizada' => Icons.flag_rounded,
      _ => Icons.cancel_rounded,
    };

Widget staffVisitaEstadoPill(String? e) => StatusPill(
      staffVisitaEstadoTexto(e),
      icon: staffVisitaEstadoIcono(e),
      color: switch (e) {
        'cancelada' => Fz.frambuesaSuave,
        'finalizada' => Fz.azul200,
        'confirmada' || 'en_camino' || 'en_atencion' => Fz.azul100,
        _ => Fz.tarjeta,
      },
      dashed: e == 'solicitada',
    );

String _franja(String? f) => f == 'tarde' ? 'Tarde' : (f == 'manana' ? 'Mañana' : (f ?? ''));

DateTime? _fechaDia(dynamic v) {
  final s = staffStr(v);
  if (s == null) return null;
  final d = DateTime.tryParse(s);
  return d == null ? null : DateTime(d.year, d.month, d.day);
}

Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

List<String> _petIds(Map<String, dynamic> v) =>
    ((v['pet_ids'] as List?) ?? const []).map((e) => e.toString()).toList();

String? _enlaceMapa(Map<String, dynamic> v) {
  final url = staffStr(v['maps_url']);
  if (url != null) return url;
  final lat = staffNum(v['lat']);
  final lng = staffNum(v['lng']);
  return lat != null && lng != null ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : null;
}

Future<void> _abrirWhatsApp(BuildContext context, String? tel) async {
  final wa = waNumero(tel);
  if (wa == null) return;
  final ok = await abrirEnlace('https://wa.me/$wa');
  if (!ok && context.mounted) showInfo(context, 'No pudimos abrir WhatsApp.');
}

/// Citas (visitas a domicilio) para el equipo. Administración gestiona; el contador ve en solo lectura.
class AdminVisitasScreen extends StatefulWidget {
  const AdminVisitasScreen({super.key});

  @override
  State<AdminVisitasScreen> createState() => _AdminVisitasScreenState();
}

class _AdminVisitasScreenState extends State<AdminVisitasScreen> {
  static const _segs = [
    ('solicitada', 'Solicitadas', Icons.mark_email_unread_rounded, {'solicitada'}),
    ('confirmada', 'Confirmadas', Icons.event_available_rounded, {'confirmada'}),
    ('en_curso', 'En curso', Icons.directions_car_rounded, {'en_camino', 'en_atencion'}),
    ('finalizada', 'Finalizadas', Icons.flag_rounded, {'finalizada'}),
    ('cancelada', 'Canceladas', Icons.cancel_rounded, {'cancelada'}),
  ];

  String _seg = 'solicitada';
  List<Map<String, dynamic>>? _items;
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
      final r = await Data.visitas();
      final ids = {for (final v in r) ..._petIds(v)}.toList();
      Map<String, Pet> pets = {};
      try {
        pets = {for (final p in await Data.mascotasPorIds(ids)) p.id: p};
      } catch (_) {
        // Sin mascotas igual se muestran las visitas.
      }
      if (!mounted) return;
      setState(() {
        _items = r;
        _pets = pets;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Set<String> _estados(String seg) => _segs.firstWhere((s) => s.$1 == seg).$4;

  int _cuenta(String seg) {
    final es = _estados(seg);
    return (_items ?? const []).where((v) => es.contains(v['estado'])).length;
  }

  Future<void> _abrir(Map<String, dynamic> v) async {
    final pets = [for (final id in _petIds(v)) ?_pets[id]];
    final r = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => AdminVisitaDetalleScreen(visita: v, mascotas: pets)),
    );
    if (r == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppMode.of(context).isAdmin;
    final solicitadas = _items == null ? null : _cuenta('solicitada');
    return Scaffold(
      appBar: AppBar(title: const Text('Citas a domicilio')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: FadeSlideIn(
            child: FzHero(
              leading: Text(solicitadas?.toString() ?? '–', style: Fz.display(40, color: Fz.tarjeta)),
              title: solicitadas == 1 ? 'solicitud por gestionar' : 'solicitudes por gestionar',
              subtitle: admin
                  ? 'Confirma fecha, veterinario y precio de cada visita.'
                  : 'Vista de solo lectura. Los pagos se verifican en Pagos.',
              child: admin
                  ? OutlinedButton.icon(
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => const ServiciosDomicilioScreen())),
                      icon: const Icon(Icons.price_change_rounded),
                      label: const Text('Servicios y precios a domicilio'),
                    )
                  : null,
            ),
          ),
        ),
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final s in _segs)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    avatar: _seg == s.$1 ? null : Icon(s.$3, size: 18, color: Fz.tinta),
                    label: Text(_items == null ? s.$2 : '${s.$2} · ${_cuenta(s.$1)}'),
                    selected: _seg == s.$1,
                    onSelected: (_) => setState(() => _seg = s.$1),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(child: _body()),
      ]),
    );
  }

  Widget _body() {
    if (_error != null && _items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar las citas',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    final es = _estados(_seg);
    final visibles = items.where((v) => es.contains(v['estado'])).toList();
    if (_seg == 'finalizada' || _seg == 'cancelada') {
      visibles.sort((a, b) => (staffStr(b['fecha_hora']) ?? staffStr(b['fecha_preferida']) ?? '')
          .compareTo(staffStr(a['fecha_hora']) ?? staffStr(a['fecha_preferida']) ?? ''));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: visibles.isEmpty
          ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
              const SizedBox(height: 40),
              EmptyState(
                icon: _seg == 'solicitada' ? Icons.task_alt_rounded : Icons.inbox_rounded,
                title: switch (_seg) {
                  'solicitada' => 'Todo al día',
                  'confirmada' => 'No hay visitas confirmadas',
                  'en_curso' => 'Ninguna visita en curso',
                  'finalizada' => 'Aún no hay visitas finalizadas',
                  _ => 'No hay visitas canceladas',
                },
                message: _seg == 'solicitada' ? 'No hay solicitudes esperando gestión.' : null,
              ),
            ])
          : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: visibles.length,
              itemBuilder: (_, i) {
                final v = visibles[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: FadeSlideIn(
                    key: ValueKey(v['id']),
                    index: i,
                    child: AdminVisitaCard(
                      visita: v,
                      mascotas: [for (final id in _petIds(v)) ?_pets[id]],
                      alt: i.isOdd,
                      onTap: () => _abrir(v),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

/// Tarjeta de una visita a domicilio.
class AdminVisitaCard extends StatelessWidget {
  const AdminVisitaCard({super.key, required this.visita, required this.mascotas, this.onTap, this.alt = false});
  final Map<String, dynamic> visita;
  final List<Pet> mascotas;
  final VoidCallback? onTap;
  final bool alt;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = visita;
    final serv = _map(v['servicios_domicilio']);
    final prop = _map(v['propietario']);
    final vet = _map(v['veterinario']);
    final pago = v['pago'] is Map ? _map(v['pago']) : null;
    final codigo = staffStr(v['codigo']);
    final tel = staffStr(prop['telefono']);
    final pref = _fechaDia(v['fecha_preferida']);
    final cita = staffFecha(v['fecha_hora']);
    final precio = staffNum(v['precio_usd']);
    final enlace = _enlaceMapa(v);
    final direccion = staffStr(v['direccion']);

    Widget meta(IconData ic, String s) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ic, size: 17, color: Fz.azul),
            const SizedBox(width: 8),
            Expanded(child: Text(s, style: t.bodyMedium)),
          ]),
        );

    return PopCard(
      onTap: onTap,
      color: alt ? Fz.azul50 : Fz.tarjeta,
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (codigo != null) CodigoCopiable(codigo, compacto: true),
          const Spacer(),
          staffVisitaEstadoPill(staffStr(v['estado'])),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          FzAvatar(
            url: Data.fotoUrl(staffStr(prop['avatar_path'])),
            text: iniciales(staffStr(prop['nombre'])),
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(staffStr(serv['nombre']) ?? 'Visita a domicilio',
                  style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
              Text(staffStr(prop['nombre']) ?? 'Propietario', style: t.bodySmall),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(precio == null ? 'Por confirmar' : Money.usd(precio), style: precio == null ? t.titleSmall : Fz.display(19)),
            if (tel != null && waNumero(tel) != null)
              IconButton(
                tooltip: 'WhatsApp del propietario',
                icon: const Icon(Icons.chat_rounded, color: Fz.azul),
                onPressed: () => _abrirWhatsApp(context, tel),
              ),
          ]),
        ]),
        const Divider(height: 18),
        meta(Icons.pets_rounded,
            mascotas.isEmpty ? '${_petIds(v).length} mascota(s)' : mascotas.map((p) => '${p.nombre} (${p.descripcion})').join(', ')),
        if (cita != null)
          meta(Icons.event_available_rounded, 'Cita: ${Money.fechaLarga(cita)}')
        else if (pref != null)
          meta(Icons.calendar_month_rounded, 'Prefiere ${Money.fecha(pref)} · ${_franja(staffStr(v['franja']))}'),
        if (direccion != null) meta(Icons.place_rounded, direccion),
        meta(Icons.medical_services_rounded,
            staffStr(vet['nombre']) == null ? 'Sin veterinario asignado' : 'Veterinario: ${staffStr(vet['nombre'])}'),
        meta(pago?['estado'] == 'verificado' ? Icons.check_circle_rounded : Icons.payments_rounded,
            pago == null ? 'Sin pago reportado' : '${estadoPagoTexto(staffStr(pago['estado']))} · ${staffMetodo(staffStr(pago['metodo']))}'),
        if (enlace != null)
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () async {
                final ok = await abrirEnlace(enlace);
                if (!ok && context.mounted) showInfo(context, 'No pudimos abrir el mapa.');
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Abrir en Maps'),
            ),
          ),
      ]),
    );
  }
}

/// Detalle de una visita. El admin confirma fecha y hora, veterinario y precio, o cancela con motivo.
class AdminVisitaDetalleScreen extends StatefulWidget {
  const AdminVisitaDetalleScreen({super.key, required this.visita, this.mascotas = const []});
  final Map<String, dynamic> visita;
  final List<Pet> mascotas;

  @override
  State<AdminVisitaDetalleScreen> createState() => _AdminVisitaDetalleScreenState();
}

class _AdminVisitaDetalleScreenState extends State<AdminVisitaDetalleScreen> {
  final _form = GlobalKey<FormState>();
  final _precio = TextEditingController();
  late DateTime _fecha;
  late TimeOfDay _hora;
  String? _vetId;
  List<Map<String, dynamic>>? _cirujanos;
  late List<Pet> _mascotas = widget.mascotas;
  bool _busy = false;

  Map<String, dynamic> get v => widget.visita;
  String get _estado => staffStr(v['estado']) ?? 'solicitada';

  @override
  void initState() {
    super.initState();
    final cita = staffFecha(v['fecha_hora']);
    final pref = _fechaDia(v['fecha_preferida']) ?? DateTime.now().add(const Duration(days: 1));
    final base = cita ?? pref;
    _fecha = DateTime(base.year, base.month, base.day);
    _hora = cita != null
        ? TimeOfDay.fromDateTime(cita)
        : (v['franja'] == 'tarde' ? const TimeOfDay(hour: 15, minute: 0) : const TimeOfDay(hour: 9, minute: 0));
    _vetId = staffStr(v['veterinario_id']);
    final precio = staffNum(v['precio_usd']);
    if (precio != null) _precio.text = _fmt(precio);
    _cargar();
  }

  static String _fmt(double n) => n == n.roundToDouble() ? n.round().toString() : n.toStringAsFixed(2);

  Future<void> _cargar() async {
    if (_mascotas.isEmpty && _petIds(v).isNotEmpty) {
      Data.mascotasPorIds(_petIds(v)).then((p) {
        if (mounted) setState(() => _mascotas = p);
      }).catchError((_) {});
    }
    try {
      final r = await Data.cirujanos();
      if (mounted) setState(() => _cirujanos = r);
    } catch (_) {
      if (mounted) setState(() => _cirujanos = const []);
    }
    // Precio sugerido: el del servicio, si la visita aún no tiene precio.
    if (_precio.text.isEmpty) {
      try {
        final servs = await Data.serviciosDomicilio(todos: true);
        final s = servs.where((x) => x['id']?.toString() == v['servicio_id']?.toString()).firstOrNull;
        final p = staffNum(s?['precio_usd']);
        if (mounted && p != null && _precio.text.isEmpty) setState(() => _precio.text = _fmt(p));
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _precio.dispose();
    super.dispose();
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha.isBefore(DateTime(hoy.year, hoy.month, hoy.day)) ? DateTime(hoy.year, hoy.month, hoy.day) : _fecha,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day),
      lastDate: DateTime(hoy.year + 1, hoy.month, hoy.day),
      helpText: 'Fecha de la visita',
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(context: context, initialTime: _hora, helpText: 'Hora de la visita');
    if (h != null) setState(() => _hora = h);
  }

  Future<void> _elegirVet() async {
    final lista = _cirujanos ?? const [];
    if (lista.isEmpty) {
      showInfo(context, 'No hay cirujanos registrados. Asígnale el rol a alguien en Usuarios.');
      return;
    }
    final id = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (c) {
        final t = Theme.of(c).textTheme;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(c).size.height * .7),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Elegir veterinario', textAlign: TextAlign.center, style: t.headlineSmall),
              const SizedBox(height: 8),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lista.length,
                  itemBuilder: (_, i) {
                    final p = lista[i];
                    final sel = p['id']?.toString() == _vetId;
                    return ListTile(
                      minTileHeight: 60,
                      selected: sel,
                      selectedTileColor: Fz.azul,
                      selectedColor: Fz.tarjeta,
                      leading: FzAvatar(
                        url: Data.fotoUrl(staffStr(p['avatar_path'])),
                        text: iniciales(staffStr(p['nombre'])),
                        size: 42,
                      ),
                      title: Text(staffStr(p['nombre']) ?? 'Cirujano',
                          style: t.titleMedium?.copyWith(color: sel ? Fz.tarjeta : Fz.tinta)),
                      subtitle: staffStr(p['telefono']) == null
                          ? null
                          : Text(staffStr(p['telefono'])!, style: t.bodySmall?.copyWith(color: sel ? Fz.azul50 : null)),
                      trailing: sel ? const Icon(Icons.check_circle_rounded, color: Fz.tarjeta) : null,
                      onTap: () => Navigator.pop(c, p['id']?.toString()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
        );
      },
    );
    if (id != null) setState(() => _vetId = id);
  }

  Future<void> _guardar() async {
    if (_form.currentState?.validate() != true) return;
    if (_vetId == null) {
      showInfo(context, 'Elige el veterinario que hará la visita.');
      return;
    }
    final fh = DateTime(_fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);
    if (fh.isBefore(DateTime.now())) {
      showInfo(context, 'La fecha y hora ya pasaron. Elige otra.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Data.gestionarVisita(staffStr(v['id'])!, fechaHora: fh, veterinarioId: _vetId, precio: parseBs(_precio.text));
      if (!mounted) return;
      showInfo(context, _estado == 'solicitada' ? 'Visita confirmada. Avisaremos al propietario.' : 'Visita actualizada');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  Future<void> _cancelar() async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CancelarSheet(),
    );
    if (motivo == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await Data.cancelarVisita(staffStr(v['id'])!, motivo);
      if (!mounted) return;
      showInfo(context, 'Visita cancelada. El propietario verá el motivo.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final admin = AppMode.of(context).isAdmin;
    final serv = _map(v['servicios_domicilio']);
    final prop = _map(v['propietario']);
    final vet = _map(v['veterinario']);
    final pago = v['pago'] is Map ? _map(v['pago']) : null;
    final codigo = staffStr(v['codigo']);
    final tel = staffStr(prop['telefono']);
    final pref = _fechaDia(v['fecha_preferida']);
    final cita = staffFecha(v['fecha_hora']);
    final precio = staffNum(v['precio_usd']);
    final enlace = _enlaceMapa(v);
    final lat = staffNum(v['lat']);
    final lng = staffNum(v['lng']);
    final gestionable = admin && (_estado == 'solicitada' || _estado == 'confirmada');
    final cancelable = admin && _estado != 'finalizada' && _estado != 'cancelada';
    final dur = staffNum(serv['duracion_min'])?.round();
    final vetSel = (_cirujanos ?? const []).where((c) => c['id']?.toString() == _vetId).firstOrNull;

    Widget fila(String k, String val, {String? sub, Widget? trailing}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 96, child: Text(k, style: t.bodySmall)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(val, style: t.titleMedium),
                if (sub != null) Text(sub, style: t.bodySmall),
              ]),
            ),
            ?trailing,
          ]),
        );

    Widget seccion(String titulo, List<Widget> hijos, {Color color = Fz.tarjeta}) => PopCard(
          color: color,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(titulo, textAlign: TextAlign.center, style: t.titleLarge),
            const SizedBox(height: 8),
            ...hijos,
          ]),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Visita a domicilio')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FadeSlideIn(
            child: FzHero(
              leading: FzAvatar(url: Data.fotoUrl(staffStr(prop['avatar_path'])), text: iniciales(staffStr(prop['nombre'])), size: 52),
              title: staffStr(serv['nombre']) ?? 'Visita a domicilio',
              subtitle: [
                staffStr(prop['nombre']) ?? 'Propietario',
                if (dur != null) '$dur min',
                precio == null ? 'precio por confirmar' : Money.usd(precio),
              ].join(' · '),
              child: Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 8, children: [
                staffVisitaEstadoPill(_estado),
                if (codigo != null)
                  Container(
                    decoration: BoxDecoration(
                      color: Fz.tarjeta,
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(color: Fz.tinta, width: Fz.borde),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: CodigoCopiable(codigo),
                  ),
              ]),
            ),
          ),
          const SizedBox(height: 16),

          // ---- Cita ----
          seccion('Cita', [
            if (cita != null) fila('Fecha y hora', Money.fechaLarga(cita)),
            if (pref != null) fila('Preferencia', '${Money.fecha(pref)} · ${_franja(staffStr(v['franja']))}'),
            fila('Veterinario', staffStr(vet['nombre']) ?? 'Sin asignar', sub: staffStr(vet['telefono'])),
            fila('Precio', precio == null ? 'Por confirmar' : Money.usd(precio)),
            if (staffStr(v['motivo']) != null) fila('Motivo', staffStr(v['motivo'])!),
          ]),
          const SizedBox(height: 16),

          // ---- Propietario y lugar ----
          seccion('Propietario y lugar', [
            fila('Nombre', staffStr(prop['nombre']) ?? '—'),
            fila(
              'WhatsApp',
              tel ?? '—',
              trailing: tel == null || waNumero(tel) == null
                  ? null
                  : IconButton(
                      tooltip: 'Abrir WhatsApp',
                      icon: const Icon(Icons.chat_rounded, color: Fz.azul),
                      onPressed: () => _abrirWhatsApp(context, tel),
                    ),
            ),
            if (staffStr(v['direccion']) != null) fila('Dirección', staffStr(v['direccion'])!, sub: staffStr(v['referencia_lugar'])),
            if (lat != null && lng != null) ...[
              const SizedBox(height: 6),
              MapaPreview(lat: lat, lng: lng, enlace: enlace, height: 160),
            ],
            if (enlace != null)
              Center(
                child: TextButton.icon(
                  onPressed: () async {
                    final ok = await abrirEnlace(enlace);
                    if (!ok && context.mounted) showInfo(context, 'No pudimos abrir el mapa.');
                  },
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Abrir en Maps'),
                ),
              ),
          ], color: Fz.azul50),
          const SizedBox(height: 16),

          // ---- Mascotas ----
          seccion('Mascotas', [
            if (_mascotas.isEmpty)
              Text('${_petIds(v).length} mascota(s)', textAlign: TextAlign.center, style: t.bodyMedium)
            else
              for (final p in _mascotas)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    FzAvatar(url: p.fotoUrl, icon: Icons.pets_rounded, size: 44),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.nombre, style: t.titleMedium),
                        Text(
                          [
                            p.descripcion,
                            if (p.edadMeses != null) '${p.edadMeses} meses',
                            if (p.braqui) 'braquiocefálico',
                            if (p.esterilizada) 'esterilizada',
                          ].join(' · '),
                          style: t.bodySmall,
                        ),
                      ]),
                    ),
                  ]),
                ),
          ]),
          const SizedBox(height: 16),

          // ---- Pago ----
          seccion('Pago', [
            if (pago == null)
              Text('Sin pago reportado todavía.', textAlign: TextAlign.center, style: t.bodyMedium)
            else ...[
              fila('Estado', estadoPagoTexto(staffStr(pago['estado']))),
              fila('Método', staffMetodo(staffStr(pago['metodo']))),
              if (staffNum(pago['monto_usd']) != null) fila('Monto', Money.usd(staffNum(pago['monto_usd']))),
              if (staffStr(pago['referencia']) != null) fila('Referencia', staffStr(pago['referencia'])!),
              if (pago['estado'] == 'pendiente')
                Text('Verifícalo en la pestaña Pagos.', textAlign: TextAlign.center, style: t.bodySmall),
            ],
          ]),

          // ---- Informe / cancelación ----
          if (staffStr(v['informe']) != null) ...[
            const SizedBox(height: 16),
            seccion('Informe del veterinario', [Text(staffStr(v['informe'])!, style: t.bodyMedium)], color: Fz.azul100),
          ],
          if (_estado == 'cancelada' && staffStr(v['motivo_cancelacion']) != null) ...[
            const SizedBox(height: 16),
            seccion('Cancelada', [Text('Motivo: ${staffStr(v['motivo_cancelacion'])}', style: t.bodyMedium)],
                color: Fz.frambuesaSuave),
          ],

          // ---- Gestión (solo admin) ----
          if (gestionable) ...[
            const SectionTitle('Gestionar visita'),
            PopCard(
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Row(children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _elegirFecha,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Fecha', suffixIcon: Icon(Icons.calendar_month_rounded)),
                          child: Text(Money.fecha(_fecha), style: t.bodyLarge),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: _elegirHora,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: 'Hora', suffixIcon: Icon(Icons.schedule_rounded)),
                          child: Text(_hora.format(context), style: t.bodyLarge),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 14),
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: _cirujanos == null ? null : _elegirVet,
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Veterinario', suffixIcon: Icon(Icons.expand_more_rounded)),
                      child: _cirujanos == null
                          ? const LinearProgressIndicator()
                          : Row(children: [
                              FzAvatar(
                                url: Data.fotoUrl(staffStr(vetSel?['avatar_path'])),
                                text: iniciales(staffStr(vetSel?['nombre'])),
                                icon: Icons.medical_services_rounded,
                                size: 32,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  staffStr(vetSel?['nombre']) ?? staffStr(vet['nombre']) ?? 'Elegir veterinario',
                                  style: t.bodyLarge,
                                ),
                              ),
                            ]),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _precio,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: r'Precio en $',
                      prefixText: r'$ ',
                      helperText: 'Precargado con el precio sugerido del servicio.',
                    ),
                    validator: (s) {
                      final n = parseBs(s ?? '');
                      if (n == null || n <= 0) return 'Escribe el precio de la visita';
                      if (n > 2000) return 'El monto parece demasiado alto';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  PopButton(
                    label: _estado == 'solicitada' ? 'Confirmar visita' : 'Guardar cambios',
                    icon: Icons.event_available_rounded,
                    loading: _busy,
                    onPressed: _busy ? null : _guardar,
                  ),
                ]),
              ),
            ),
          ],
          if (cancelable) ...[
            const SizedBox(height: 16),
            PopButton.danger(label: 'Cancelar visita', icon: Icons.event_busy_rounded, onPressed: _busy ? null : _cancelar),
          ],
          if (!admin) ...[
            const SizedBox(height: 16),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.visibility_rounded, size: 16, color: Fz.variante),
              const SizedBox(width: 6),
              Flexible(
                child: Text('Solo lectura: administración gestiona las visitas.',
                    textAlign: TextAlign.center, style: t.bodySmall),
              ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Hoja para cancelar una visita: motivo obligatorio.
class _CancelarSheet extends StatefulWidget {
  const _CancelarSheet();

  @override
  State<_CancelarSheet> createState() => _CancelarSheetState();
}

class _CancelarSheetState extends State<_CancelarSheet> {
  static const _rapidos = ['Sin veterinario disponible', 'Fuera de la zona de servicio', 'Lo pidió el propietario', 'No se pudo contactar'];
  final _ctrl = TextEditingController();
  String? _chip;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _motivo => [?_chip, if (_ctrl.text.trim().isNotEmpty) _ctrl.text.trim()].join('. ');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Cancelar visita', textAlign: TextAlign.center, style: t.headlineSmall),
          const SizedBox(height: 6),
          Text('El propietario verá este motivo. Queda registrado.', textAlign: TextAlign.center, style: t.bodyMedium),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final m in _rapidos)
              ChoiceChip(
                label: Text(m),
                selected: _chip == m,
                onSelected: (s) => setState(() => _chip = s ? m : null),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            minLines: 2,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: _chip == null ? 'Motivo' : 'Detalle (opcional)'),
          ),
          const SizedBox(height: 8),
          PopButton.danger(
            label: 'Cancelar visita',
            icon: Icons.event_busy_rounded,
            onPressed: _motivo.length < 3 ? null : () => Navigator.of(context).pop(_motivo),
          ),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver'))),
        ]),
      ),
    );
  }
}
