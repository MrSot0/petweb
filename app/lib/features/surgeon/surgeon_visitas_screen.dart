import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../scan/ficha_screen.dart';

/// 0414-1234567 -> 584141234567 (para wa.me).
String _waNumero(String telefono) {
  var d = telefono.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = d.substring(1);
  if (!d.startsWith('58')) d = '58$d';
  return d;
}

enum _Grupo { proximas, enCurso, finalizadas }

_Grupo _grupoDe(String? estado) => switch (estado) {
  'en_camino' || 'en_atencion' => _Grupo.enCurso,
  'finalizada' || 'cancelada' => _Grupo.finalizadas,
  _ => _Grupo.proximas,
};

/// Visitas a domicilio asignadas al veterinario (rol cirujano).
class SurgeonVisitasScreen extends StatefulWidget {
  const SurgeonVisitasScreen({super.key});

  @override
  State<SurgeonVisitasScreen> createState() => _SurgeonVisitasScreenState();
}

class _SurgeonVisitasScreenState extends State<SurgeonVisitasScreen> {
  List<Map<String, dynamic>>? _items;
  Object? _error;
  _Grupo _grupo = _Grupo.proximas;
  final Map<String, Future<List<Pet>>> _mascotas = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.visitas(veterinarioId: sb.auth.currentUser!.id);
      _mascotas.clear();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<List<Pet>> _petsDe(Map<String, dynamic> v) => _mascotas.putIfAbsent(
    v['id'] as String,
    () => Data.mascotasPorIds(((v['pet_ids'] as List?) ?? const []).map((e) => e.toString()).toList()),
  );

  @override
  Widget build(BuildContext context) {
    final items = _items;
    Widget body;
    if (_error != null && items == null) {
      body = EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tus visitas',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    } else if (items == null) {
      body = const Center(child: CircularProgressIndicator());
    } else {
      final cuenta = {
        for (final g in _Grupo.values) g: items.where((v) => _grupoDe(v['estado'] as String?) == g).length,
      };
      final lista = items.where((v) => _grupoDe(v['estado'] as String?) == _grupo).toList()
        ..sort((a, b) {
          final c = _cuando(a).compareTo(_cuando(b));
          return _grupo == _Grupo.finalizadas ? -c : c;
        });
      final enCurso = cuenta[_Grupo.enCurso]!;
      final proximas = cuenta[_Grupo.proximas]!;
      body = RefreshIndicator(
        onRefresh: _load,
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          itemCount: lista.isEmpty ? 2 : lista.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeSlideIn(
                    child: FzHero(
                      title: 'Visitas a domicilio',
                      subtitle:
                          '$proximas ${proximas == 1 ? 'próxima' : 'próximas'} · $enCurso en curso · '
                          '${cuenta[_Grupo.finalizadas]} ${cuenta[_Grupo.finalizadas] == 1 ? 'finalizada' : 'finalizadas'}',
                      leading: const Icon(Icons.home_work_rounded, size: 40, color: Fz.tarjeta),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Center(
                    child: SegmentedButton<_Grupo>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: _Grupo.proximas, label: Text('Próximas')),
                        ButtonSegment(value: _Grupo.enCurso, label: Text('En curso')),
                        ButtonSegment(value: _Grupo.finalizadas, label: Text('Finalizadas')),
                      ],
                      selected: {_grupo},
                      onSelectionChanged: (s) => setState(() => _grupo = s.first),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
              );
            }
            if (lista.isEmpty) {
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: EmptyState(
                  icon: Icons.event_available_rounded,
                  title: switch (_grupo) {
                    _Grupo.proximas => 'Sin visitas próximas',
                    _Grupo.enCurso => 'Ninguna visita en curso',
                    _Grupo.finalizadas => 'Aún no hay visitas finalizadas',
                  },
                  message: _grupo == _Grupo.proximas
                      ? 'Cuando la administración te asigne una visita aparecerá aquí.'
                      : null,
                ),
              );
            }
            final v = lista[i - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: FadeSlideIn(
                index: i,
                child: _VisitaCard(
                  key: ValueKey(v['id']),
                  v: v,
                  alterna: i.isEven,
                  mascotas: _petsDe(v),
                  onCambio: _load,
                ),
              ),
            );
          },
        ),
      );
    }
    return Scaffold(body: SafeArea(child: body));
  }

  static DateTime _cuando(Map<String, dynamic> v) =>
      DateTime.tryParse((v['fecha_hora'] as String?) ?? '')?.toLocal() ??
      DateTime.tryParse((v['fecha_preferida'] as String?) ?? '') ??
      DateTime(2100);
}

class _VisitaCard extends StatefulWidget {
  const _VisitaCard({
    super.key,
    required this.v,
    required this.alterna,
    required this.mascotas,
    required this.onCambio,
  });
  final Map<String, dynamic> v;
  final bool alterna;
  final Future<List<Pet>> mascotas;
  final Future<void> Function() onCambio;

  @override
  State<_VisitaCard> createState() => _VisitaCardState();
}

class _VisitaCardState extends State<_VisitaCard> {
  bool _busy = false;

  Map<String, dynamic> get v => widget.v;
  String get _codigo => (v['codigo'] as String?) ?? '';

  Future<void> _cambiar(String estado, String ok) async {
    setState(() => _busy = true);
    try {
      await Data.estadoVisita(v['id'] as String, estado);
      if (mounted) showInfo(context, ok);
      await widget.onCambio();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finalizar() async {
    final informe = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InformeSheet(codigo: _codigo),
    );
    if (informe == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await Data.estadoVisita(v['id'] as String, 'finalizada', informe: informe);
      if (mounted) showInfo(context, 'Visita finalizada. El informe quedó guardado.');
      await widget.onCambio();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _whatsapp(String telefono) async {
    final nombre = fichaMapa(v['propietario'])['nombre'] as String?;
    final msg =
        'Hola${nombre != null ? ' $nombre' : ''}, te escribe el veterinario de FAUNAZULIA '
        'por tu visita a domicilio $_codigo.';
    final ok = await abrirEnlace('https://wa.me/${_waNumero(telefono)}?text=${Uri.encodeComponent(msg)}');
    if (!ok && mounted) showInfo(context, 'No pudimos abrir WhatsApp.');
  }

  String _fechaTexto() {
    final fh = DateTime.tryParse((v['fecha_hora'] as String?) ?? '');
    if (fh != null) return Money.fechaLarga(fh);
    final fp = DateTime.tryParse((v['fecha_preferida'] as String?) ?? '');
    final franja = switch (v['franja']) {
      'manana' => 'mañana',
      'tarde' => 'tarde',
      _ => null,
    };
    if (fp == null) return 'Fecha por confirmar';
    return '${Money.fecha(fp)}${franja != null ? ' · en la $franja' : ''} (por confirmar)';
  }

  StatusPill _estadoPill() => switch (v['estado'] as String?) {
    'solicitada' => const StatusPill('Por confirmar', icon: Icons.help_rounded, color: Fz.azul50, dashed: true),
    'confirmada' => const StatusPill('Confirmada', icon: Icons.verified_rounded, color: Fz.azul100),
    'en_camino' => const StatusPill('En camino', icon: Icons.directions_car_rounded, color: Fz.azul200),
    'en_atencion' => const StatusPill('En atención', icon: Icons.medical_services_rounded, color: Fz.azul200),
    'finalizada' => const StatusPill('Finalizada', icon: Icons.check_circle_rounded, color: Fz.azul100),
    'cancelada' => const StatusPill('Cancelada', icon: Icons.block_rounded, color: Fz.frambuesaSuave),
    final e => StatusPill(e ?? 'Sin estado', icon: Icons.info_rounded),
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final estado = v['estado'] as String?;
    final servicio = fichaMapa(v['servicios_domicilio']);
    final prop = fichaMapa(v['propietario']);
    final telefono = prop['telefono'] as String?;
    final lat = (v['lat'] as num?)?.toDouble();
    final lng = (v['lng'] as num?)?.toDouble();
    final enlaceMapa =
        (v['maps_url'] as String?) ??
        (lat != null && lng != null ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : null);
    final duracion = (servicio['duracion_min'] as num?)?.toInt();

    return PopCard(
      color: widget.alterna ? Fz.azul50 : Fz.tarjeta,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(child: _estadoPill()),
          const SizedBox(height: 8),
          Text(servicio['nombre'] as String? ?? 'Visita a domicilio', textAlign: TextAlign.center, style: t.titleLarge),
          Text(
            [_fechaTexto(), if (duracion != null) '$duracion min'].join(' · '),
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
          Center(child: CodigoCopiable(_codigo)),
          const Divider(height: 20),
          // Propietario
          Row(
            children: [
              FzAvatar(
                url: Data.fotoUrl(prop['avatar_path'] as String?),
                text: iniciales(prop['nombre'] as String?),
                size: 44,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(prop['nombre'] as String? ?? 'Propietario', style: t.titleMedium),
                    if (telefono != null) Text(telefono, style: t.bodySmall),
                  ],
                ),
              ),
              if (telefono != null)
                IconButton.filledTonal(
                  tooltip: 'Escribir por WhatsApp',
                  icon: const Icon(Icons.chat_rounded),
                  onPressed: () => _whatsapp(telefono),
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Mascotas
          FutureBuilder<List<Pet>>(
            future: widget.mascotas,
            builder: (context, snap) {
              if (snap.hasError) {
                return Text('No pudimos cargar las mascotas.', textAlign: TextAlign.center, style: t.bodySmall);
              }
              final pets = snap.data;
              if (pets == null) return const LinearProgressIndicator();
              if (pets.isEmpty) return Text('Sin mascotas indicadas', textAlign: TextAlign.center, style: t.bodySmall);
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final p in pets)
                    Container(
                      padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                      decoration: BoxDecoration(
                        color: Fz.azul100,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: Fz.tinta, width: 1.6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FzAvatar(url: p.fotoUrl, text: iniciales(p.nombre), icon: Icons.pets_rounded, size: 32),
                          const SizedBox(width: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(p.nombre, style: t.titleSmall),
                              Text(p.descripcion, style: t.bodySmall?.copyWith(fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
          if ((v['motivo'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            _Linea(icon: Icons.notes_rounded, label: 'Motivo', value: v['motivo'] as String),
          ],
          const SizedBox(height: 6),
          _Linea(icon: Icons.location_on_rounded, label: 'Dirección', value: (v['direccion'] as String?) ?? '—'),
          if ((v['referencia_lugar'] as String?)?.isNotEmpty == true)
            _Linea(icon: Icons.signpost_rounded, label: 'Referencia', value: v['referencia_lugar'] as String),
          if (lat != null && lng != null) ...[
            const SizedBox(height: 8),
            MapaPreview(lat: lat, lng: lng, enlace: enlaceMapa, height: 150),
          ],
          if (enlaceMapa != null) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () async {
                final ok = await abrirEnlace(enlaceMapa);
                if (!ok && context.mounted) showInfo(context, 'No pudimos abrir el mapa.');
              },
              icon: const Icon(Icons.map_rounded),
              label: const Text('Abrir en Maps'),
            ),
          ],
          if (estado == 'finalizada' && (v['informe'] as String?)?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Fz.azul100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Fz.tinta, width: 1.6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Informe', textAlign: TextAlign.center, style: t.titleMedium),
                  const SizedBox(height: 4),
                  SelectableText(v['informe'] as String, style: t.bodyMedium),
                ],
              ),
            ),
          ],
          if (estado == 'cancelada' && v['motivo_cancelacion'] != null) ...[
            const SizedBox(height: 6),
            _Linea(icon: Icons.block_rounded, label: 'Motivo de cancelación', value: v['motivo_cancelacion'] as String),
          ],
          if (estado == 'confirmada') ...[
            const SizedBox(height: 12),
            PopButton(
              label: 'Voy en camino',
              icon: Icons.directions_car_rounded,
              loading: _busy,
              onPressed: () => _cambiar('en_camino', 'Le avisamos al propietario que vas en camino.'),
            ),
          ],
          if (estado == 'en_camino') ...[
            const SizedBox(height: 12),
            PopButton(
              label: 'Comenzar atención',
              icon: Icons.medical_services_rounded,
              loading: _busy,
              onPressed: () => _cambiar('en_atencion', 'Atención iniciada.'),
            ),
          ],
          if (estado == 'en_atencion') ...[
            const SizedBox(height: 12),
            PopButton(label: 'Finalizar', icon: Icons.task_alt_rounded, loading: _busy, onPressed: _finalizar),
          ],
          if (estado == 'solicitada') ...[
            const SizedBox(height: 10),
            Text(
              'La administración aún debe confirmar la fecha y hora.',
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _Linea extends StatelessWidget {
  const _Linea({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Fz.azul),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.bodySmall),
                Text(value, style: t.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hoja con el informe obligatorio para finalizar la visita.
class _InformeSheet extends StatefulWidget {
  const _InformeSheet({required this.codigo});
  final String codigo;

  @override
  State<_InformeSheet> createState() => _InformeSheetState();
}

class _InformeSheetState extends State<_InformeSheet> {
  final _form = GlobalKey<FormState>();
  final _diag = TextEditingController();
  final _trat = TextEditingController();
  final _rec = TextEditingController();

  @override
  void dispose() {
    _diag.dispose();
    _trat.dispose();
    _rec.dispose();
    super.dispose();
  }

  String? _req(String? v) => (v == null || v.trim().length < 3) ? 'Escribe este dato (mínimo 3 caracteres).' : null;

  void _enviar() {
    if (!_form.currentState!.validate()) return;
    final informe =
        'Diagnóstico:\n${_diag.text.trim()}\n\n'
        'Tratamiento:\n${_trat.text.trim()}\n\n'
        'Recomendaciones:\n${_rec.text.trim()}';
    Navigator.of(context).pop(informe);
  }

  Widget _campo(TextEditingController c, String label, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      validator: _req,
      minLines: 2,
      maxLines: 5,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), alignLabelWithHint: true),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Informe de la visita', textAlign: TextAlign.center, style: t.headlineSmall),
              if (widget.codigo.isNotEmpty) Center(child: CodigoCopiable(widget.codigo)),
              const SizedBox(height: 4),
              Text(
                'Es obligatorio para finalizar. El propietario podrá leerlo.',
                textAlign: TextAlign.center,
                style: t.bodySmall,
              ),
              const SizedBox(height: 16),
              _campo(_diag, 'Diagnóstico', Icons.biotech_rounded),
              _campo(_trat, 'Tratamiento', Icons.medication_rounded),
              _campo(_rec, 'Recomendaciones', Icons.tips_and_updates_rounded),
              const SizedBox(height: 4),
              PopButton(label: 'Finalizar visita', icon: Icons.task_alt_rounded, onPressed: _enviar),
              const SizedBox(height: 8),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Volver')),
            ],
          ),
        ),
      ),
    );
  }
}
