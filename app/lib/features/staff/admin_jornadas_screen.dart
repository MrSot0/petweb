import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'tasa_screen.dart' show parseBs;

const _estados = ['borrador', 'publicada', 'cerrada', 'finalizada', 'cancelada'];

String estadoJornadaTexto(String e) => switch (e) {
      'borrador' => 'Borrador',
      'publicada' => 'Publicada',
      'cerrada' => 'Inscripciones cerradas',
      'finalizada' => 'Finalizada',
      'cancelada' => 'Cancelada',
      _ => e,
    };

Widget estadoJornadaPill(String e) => switch (e) {
      'publicada' => const StatusPill('Publicada', icon: Icons.public_rounded, color: Fz.azulPastel),
      'borrador' => const StatusPill('Borrador', icon: Icons.edit_note_rounded, color: Fz.cremaClaro, dashed: true),
      'cerrada' => const StatusPill('Cerrada', icon: Icons.lock_rounded, color: Fz.rosaSuave),
      'finalizada' => const StatusPill('Finalizada', icon: Icons.flag_rounded, color: Fz.cremaClaro),
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
/// Devuelve true si se guardó.
Future<bool> mostrarFijarPrecio(BuildContext context, Map<String, dynamic> inscripcion) async {
  final pet = (inscripcion['pets'] as Map?) ?? const {};
  final ctrl = TextEditingController();
  final key = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) {
      var saving = false;
      return StatefulBuilder(builder: (c, setD) {
        Future<void> guardar() async {
          if (!key.currentState!.validate()) return;
          setD(() => saving = true);
          try {
            await Data.fijarPrecio(inscripcion['id'] as String, parseBs(ctrl.text)!);
            if (c.mounted) Navigator.pop(c, true);
          } catch (e) {
            setD(() => saving = false);
            if (c.mounted) showError(c, e);
          }
        }

        return AlertDialog(
          title: const Text('Fijar precio'),
          content: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                '${pet['nombre'] ?? 'Mascota'}'
                '${pet['peso_kg'] != null ? ' · ${pet['peso_kg']} kg' : ''}'
                '${pet['braquiocefalico'] == true ? ' · braquiocefálico' : ''}',
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
                  style: Theme.of(c).textTheme.bodySmall),
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

/// Lista de todas las jornadas (solo administración).
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
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => JornadaDetalleScreen(jornada: j)));
    if (r == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jornadas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nueva,
        backgroundColor: Fz.rosa,
        foregroundColor: Fz.tinta,
        shape: const StadiumBorder(side: BorderSide(color: Fz.tinta, width: Fz.borde)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva jornada'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
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
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: items.isEmpty
          ? ListView(children: [
              const SizedBox(height: 40),
              EmptyState(
                icon: Icons.event_busy_rounded,
                title: 'Aún no hay jornadas',
                message: 'Crea la primera con "Nueva jornada".',
                action: PopButton(label: 'Nueva jornada', icon: Icons.add_rounded, onPressed: _nueva, expand: false),
              ),
            ])
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (_, i) {
                final j = items[i];
                final libres = j.cuposLibres;
                return PopCard(
                  onTap: () => _abrir(j),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: Text(j.titulo, style: t.titleLarge)),
                      const SizedBox(width: 8),
                      estadoJornadaPill(j.estado),
                    ]),
                    const SizedBox(height: 6),
                    Text(Money.fechaLarga(j.fecha), style: t.bodyMedium),
                    Text('${j.sede} · ${j.ciudad}', style: t.bodySmall),
                    const SizedBox(height: 10),
                    Row(children: [
                      const Icon(Icons.event_seat_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        libres == null
                            ? '${j.cuposTotal} cupos'
                            : '${j.cuposTotal - libres} de ${j.cuposTotal} cupos ocupados · $libres libres',
                        style: t.titleSmall,
                      ),
                    ]),
                    if (libres != null && j.cuposTotal > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: ((j.cuposTotal - libres) / j.cuposTotal).clamp(0, 1).toDouble(),
                          minHeight: 8,
                        ),
                      ),
                    ],
                  ]),
                );
              },
            ),
    );
  }
}

/// Detalle de una jornada con la lista de inscritos.
class JornadaDetalleScreen extends StatefulWidget {
  const JornadaDetalleScreen({super.key, required this.jornada});
  final Jornada jornada;

  @override
  State<JornadaDetalleScreen> createState() => _JornadaDetalleScreenState();
}

class _JornadaDetalleScreenState extends State<JornadaDetalleScreen> {
  List<Map<String, dynamic>>? _ins;
  Object? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.inscritosJornada(widget.jornada.id);
      if (mounted) setState(() => _ins = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _editar() async {
    final r = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => JornadaFormScreen(jornada: widget.jornada)));
    if (r == true && mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final j = widget.jornada;
    final t = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(j.titulo),
          actions: [IconButton(tooltip: 'Editar jornada', icon: const Icon(Icons.edit_rounded), onPressed: _editar)],
        ),
        body: _error != null && _ins == null
            ? EmptyState(
                icon: Icons.wifi_off_rounded,
                title: 'No pudimos cargar los inscritos',
                message: friendlyError(_error!),
                action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
              )
            : _ins == null
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
                      PopCard(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          estadoJornadaPill(j.estado),
                          const SizedBox(height: 8),
                          Text(Money.fechaLarga(j.fecha), style: t.titleMedium),
                          Text('${j.sede} · ${j.ciudad}', style: t.bodyMedium),
                          if (j.direccion != null) Text(j.direccion!, style: t.bodySmall),
                          const SizedBox(height: 6),
                          Text(
                            '${_ins!.length} inscritos · ${j.cuposTotal} cupos'
                            '${j.limpiezaDental ? ' · con limpieza dental' : ''}',
                            style: t.titleSmall,
                          ),
                        ]),
                      ),
                      SectionTitle('Inscritos (${_ins!.length})'),
                      if (_ins!.isEmpty)
                        Text('Nadie se ha inscrito todavía.', style: t.bodyMedium)
                      else
                        for (final i in _ins!) ...[_inscrito(i, t), const SizedBox(height: 12)],
                    ]),
                  ),
      ),
    );
  }

  Widget _inscrito(Map<String, dynamic> i, TextTheme t) {
    final pet = (i['pets'] as Map?) ?? const {};
    final prof = (i['profiles'] as Map?) ?? const {};
    final estado = i['estado'] as String?;
    final porConfirmar = estado == 'precio_por_confirmar';
    final tel = prof['telefono'] as String?;
    return PopCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.pets_rounded, color: Fz.azul),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${pet['nombre'] ?? 'Mascota'}'
              '${pet['especie'] != null ? ' · ${pet['especie'] == 'perro' ? 'Perro' : 'Gato'}' : ''}'
              '${pet['peso_kg'] != null ? ' · ${pet['peso_kg']} kg' : ''}',
              style: t.titleMedium,
            ),
          ),
          Text(Money.usd((i['precio_total_usd'] as num?)), style: t.titleMedium),
        ]),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: Text('${prof['nombre'] ?? 'Propietario'}${tel != null ? ' · $tel' : ''}', style: t.bodySmall),
          ),
          if (tel != null)
            IconButton(
              tooltip: 'Copiar teléfono',
              icon: const Icon(Icons.copy_rounded, size: 20),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: tel));
                if (mounted) showInfo(context, 'Teléfono copiado');
              },
            ),
        ]),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          StatusPill(
            estadoInscripcionTexto(estado),
            icon: estadoInscripcionIcono(estado),
            color: porConfirmar ? Fz.rosa : (estado == 'confirmada' ? Fz.azulPastel : Fz.cremaClaro),
            dashed: estado == 'pendiente_pago',
          ),
          if (i['incluye_kit'] == true)
            const StatusPill('Kit', icon: Icons.medical_services_rounded, color: Fz.cremaClaro),
          if (i['codigo'] != null) Text('Cód. ${i['codigo']}', style: t.bodySmall),
        ]),
        if (porConfirmar) ...[
          const SizedBox(height: 10),
          PopButton.accent(
            label: 'Fijar precio',
            icon: Icons.sell_rounded,
            onPressed: () async {
              if (await mostrarFijarPrecio(context, i)) {
                _changed = true;
                _load();
              }
            },
          ),
        ],
      ]),
    );
  }
}

/// Formulario para crear o editar una jornada.
class JornadaFormScreen extends StatefulWidget {
  const JornadaFormScreen({super.key, this.jornada});
  final Jornada? jornada;

  @override
  State<JornadaFormScreen> createState() => _JornadaFormScreenState();
}

class _JornadaFormScreenState extends State<JornadaFormScreen> {
  static const _ciudades = ['Maracaibo', 'San Francisco'];
  static final _waRe = RegExp(r'^https://(chat\.whatsapp\.com|wa\.me)/');
  static final _parRe = RegExp(r'^\s*\(?\s*(-?\d{1,3}(?:\.\d+)?)\s*[,;\s]\s*(-?\d{1,3}(?:\.\d+)?)\s*\)?\s*$');

  final _form = GlobalKey<FormState>();
  late final TextEditingController _titulo, _desc, _sede, _dir, _otraCiudad, _lat, _lng, _wa, _cupos;
  late DateTime _fecha;
  late TimeOfDay _hora;
  late String _ciudad; // Maracaibo | San Francisco | otra
  late bool _dental;
  late String _estado;
  bool _saving = false;
  bool _waLoading = false;

  @override
  void initState() {
    super.initState();
    final j = widget.jornada;
    _titulo = TextEditingController(text: j?.titulo ?? '');
    _desc = TextEditingController(text: j?.descripcion ?? '');
    _sede = TextEditingController(text: j?.sede ?? '');
    _dir = TextEditingController(text: j?.direccion ?? '');
    final c = j?.ciudad ?? 'Maracaibo';
    _ciudad = _ciudades.contains(c) ? c : 'otra';
    _otraCiudad = TextEditingController(text: _ciudad == 'otra' ? c : '');
    _lat = TextEditingController(text: j?.lat?.toString() ?? '');
    _lng = TextEditingController(text: j?.lng?.toString() ?? '');
    _wa = TextEditingController();
    _cupos = TextEditingController(text: (j?.cuposTotal ?? 40).toString());
    final f = j?.fecha ?? DateTime.now().add(const Duration(days: 14));
    _fecha = DateTime(f.year, f.month, f.day);
    _hora = j != null ? TimeOfDay.fromDateTime(f) : const TimeOfDay(hour: 8, minute: 0);
    _dental = j?.limpiezaDental ?? false;
    _estado = j?.estado ?? 'borrador';
    if (j != null) _cargarWa(j.id);
  }

  Future<void> _cargarWa(String id) async {
    setState(() => _waLoading = true);
    try {
      final u = await Data.whatsappJornada(id);
      if (mounted && u != null && _wa.text.isEmpty) _wa.text = u;
    } catch (_) {
      // Si no se puede leer, el admin puede escribirlo de nuevo.
    } finally {
      if (mounted) setState(() => _waLoading = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_titulo, _desc, _sede, _dir, _otraCiudad, _lat, _lng, _wa, _cupos]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Si se pega "10.6427, -71.6125" en cualquiera de los dos campos, se reparte.
  void _quizaPar(String v) {
    final m = _parRe.firstMatch(v);
    if (m == null) return;
    _lat.text = m.group(1)!;
    _lng.text = m.group(2)!;
    _lng.selection = TextSelection.collapsed(offset: _lng.text.length);
    setState(() {});
  }

  String? _validaCoord(String? v, double max, String nombre) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null; // opcional
    final n = double.tryParse(s.replaceAll(',', '.'));
    if (n == null) return '$nombre no es un número';
    if (n < -max || n > max) return '$nombre debe estar entre -$max y $max';
    return null;
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year - 1),
      lastDate: DateTime(hoy.year + 2),
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _elegirHora() async {
    final h = await showTimePicker(context: context, initialTime: _hora);
    if (h != null) setState(() => _hora = h);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final lat = _lat.text.trim().isEmpty ? null : double.parse(_lat.text.trim().replaceAll(',', '.'));
    final lng = _lng.text.trim().isEmpty ? null : double.parse(_lng.text.trim().replaceAll(',', '.'));
    if ((lat == null) != (lng == null)) {
      showInfo(context, 'Escribe latitud y longitud, o deja ambas vacías.');
      return;
    }
    final inicio = DateTime(_fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);
    final datos = <String, dynamic>{
      'titulo': _titulo.text.trim(),
      'descripcion': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'fecha_inicio': inicio.toUtc().toIso8601String(),
      'sede_nombre': _sede.text.trim(),
      'direccion': _dir.text.trim().isEmpty ? null : _dir.text.trim(),
      'ciudad': _ciudad == 'otra' ? _otraCiudad.text.trim() : _ciudad,
      'lat': lat,
      'lng': lng,
      'whatsapp_url': _wa.text.trim().isEmpty ? null : _wa.text.trim(),
      'cupos_total': int.parse(_cupos.text.trim()),
      'incluye_limpieza_dental': _dental,
      'estado': _estado,
    };
    if (widget.jornada == null && sb.auth.currentUser != null) datos['created_by'] = sb.auth.currentUser!.id;
    setState(() => _saving = true);
    try {
      await Data.guardarJornada(datos, id: widget.jornada?.id);
      if (!mounted) return;
      showInfo(context, widget.jornada == null ? 'Jornada creada' : 'Jornada actualizada');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    const gap = SizedBox(height: 14);
    String? req(String? v) => (v ?? '').trim().isEmpty ? 'Este campo es obligatorio' : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.jornada == null ? 'Nueva jornada' : 'Editar jornada')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          TextFormField(
            controller: _titulo,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título', hintText: 'Jornada de esterilización · La Limpia'),
            validator: req,
          ),
          gap,
          TextFormField(
            controller: _desc,
            maxLines: 4,
            minLines: 2,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
          ),
          gap,
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
          gap,
          TextFormField(
            controller: _sede,
            maxLength: 120,
            decoration: const InputDecoration(labelText: 'Sede', hintText: 'Casa comunal La Limpia'),
            validator: req,
          ),
          gap,
          TextFormField(
            controller: _dir,
            maxLength: 250,
            decoration: const InputDecoration(labelText: 'Dirección (opcional)'),
          ),
          gap,
          Text('Ciudad', style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            for (final c in [..._ciudades, 'otra'])
              ChoiceChip(
                label: Text(c == 'otra' ? 'Otra' : c),
                selected: _ciudad == c,
                onSelected: (_) => setState(() => _ciudad = c),
              ),
          ]),
          if (_ciudad == 'otra') ...[
            gap,
            TextFormField(
              controller: _otraCiudad,
              decoration: const InputDecoration(labelText: 'Nombre de la ciudad'),
              validator: req,
            ),
          ],
          const SectionTitle('Ubicación en el mapa'),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: TextFormField(
                controller: _lat,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Latitud', hintText: '10.6427'),
                onChanged: _quizaPar,
                validator: (v) => _validaCoord(v, 90, 'La latitud'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _lng,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Longitud', hintText: '-71.6125'),
                onChanged: _quizaPar,
                validator: (v) => _validaCoord(v, 180, 'La longitud'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: Fz.variante),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'En Google Maps mantén presionado el punto y copia las coordenadas. '
                'Puedes pegar "10.6427, -71.6125" en un solo campo y se reparten solas.',
                style: t.bodySmall,
              ),
            ),
          ]),
          TextButton.icon(
            onPressed: () async {
              final d = await Clipboard.getData(Clipboard.kTextPlain);
              final s = d?.text ?? '';
              if (_parRe.hasMatch(s)) {
                _quizaPar(s);
              } else if (context.mounted) {
                showInfo(context, 'El portapapeles no tiene coordenadas como "10.6427, -71.6125".');
              }
            },
            icon: const Icon(Icons.content_paste_rounded),
            label: const Text('Pegar coordenadas'),
          ),
          const SectionTitle('Detalles'),
          TextFormField(
            controller: _wa,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Enlace del grupo de WhatsApp (opcional)',
              hintText: 'https://chat.whatsapp.com/…',
              helperText: 'Solo lo ven los inscritos con pago confirmado.',
              suffixIcon: _waLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : null,
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return null;
              if (!_waRe.hasMatch(s)) return 'Debe empezar por https://chat.whatsapp.com/ o https://wa.me/';
              return null;
            },
          ),
          gap,
          TextFormField(
            controller: _cupos,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(labelText: 'Cupos'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n < 1) return 'Escribe al menos 1 cupo';
              if (n > 1000) return 'Máximo 1000 cupos';
              return null;
            },
          ),
          gap,
          PopCard(
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SwitchListTile(
              value: _dental,
              onChanged: (v) => setState(() => _dental = v),
              title: Text('Incluye limpieza dental', style: t.titleMedium),
            ),
          ),
          gap,
          Text('Estado', style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final e in _estados)
              ChoiceChip(
                label: Text(estadoJornadaTexto(e)),
                selected: _estado == e,
                onSelected: (_) => setState(() => _estado = e),
              ),
          ]),
          const SizedBox(height: 6),
          Text(
            _estado == 'publicada'
                ? 'Visible para los propietarios: pueden inscribirse.'
                : _estado == 'borrador'
                    ? 'Solo la ve administración.'
                    : 'Los propietarios no pueden inscribirse.',
            style: t.bodySmall,
          ),
          const SizedBox(height: 24),
          PopButton(
            label: widget.jornada == null ? 'Crear jornada' : 'Guardar cambios',
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving ? null : _guardar,
          ),
        ]),
      ),
    );
  }
}
