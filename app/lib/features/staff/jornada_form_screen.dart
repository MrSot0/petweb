import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/webp.dart';
import '../../core/widgets.dart';
import 'admin_jornadas_screen.dart' show estadosJornada, estadoJornadaTexto;

/// ¿Es un enlace de Google Maps? (maps.app.goo.gl, goo.gl/maps, google.*/maps, maps.google.*)
bool esEnlaceGoogleMaps(String s) => RegExp(
      r'^https?://(maps\.app\.goo\.gl/|goo\.gl/maps/|(www\.)?google\.[a-z.]+/maps|maps\.google\.[a-z.]+/)',
      caseSensitive: false,
    ).hasMatch(s.trim());

/// Formulario para crear o editar una jornada (solo administración).
class JornadaFormScreen extends StatefulWidget {
  const JornadaFormScreen({super.key, this.jornada});
  final Jornada? jornada;

  @override
  State<JornadaFormScreen> createState() => _JornadaFormScreenState();
}

class _JornadaFormScreenState extends State<JornadaFormScreen> {
  static const _ciudades = ['Maracaibo', 'San Francisco'];
  static final _waRe = RegExp(r'^https://(chat\.whatsapp\.com|wa\.me)/');

  final _form = GlobalKey<FormState>();
  late final TextEditingController _titulo, _desc, _sede, _dir, _otraCiudad, _maps, _wa, _cupos;
  late DateTime _fecha;
  late TimeOfDay _hora;
  late String _ciudad; // Maracaibo | San Francisco | otra
  late bool _dental;
  late String _estado;
  bool _saving = false;
  bool _waLoading = false;

  // Mapa
  double? _lat, _lng;
  String? _mapaResuelto; // enlace para el que valen _lat/_lng
  String? _mapaError;
  bool _mapaLoading = false;
  Timer? _debounce;
  int _mapaSeq = 0;

  // Portada
  String? _imagenPath;
  bool _subiendo = false;

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
    _maps = TextEditingController(text: j?.mapsUrl ?? '');
    _lat = j?.lat;
    _lng = j?.lng;
    _mapaResuelto = j?.mapsUrl;
    _wa = TextEditingController();
    _cupos = TextEditingController(text: (j?.cuposTotal ?? 40).toString());
    final f = j?.fecha ?? DateTime.now().add(const Duration(days: 14));
    _fecha = DateTime(f.year, f.month, f.day);
    _hora = j != null ? TimeOfDay.fromDateTime(f) : const TimeOfDay(hour: 8, minute: 0);
    _dental = j?.limpiezaDental ?? false;
    _estado = j?.estado ?? 'borrador';
    _imagenPath = j?.m['imagen_path'] as String?;
    if (j != null) _cargarWa(j.id);
    // Jornada vieja con enlace pero sin coordenadas: resolver de una vez.
    if (j?.mapsUrl != null && (j?.lat == null || j?.lng == null)) {
      _mapaResuelto = null;
      _resolverMapa(j!.mapsUrl!);
    }
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
    _debounce?.cancel();
    for (final c in [_titulo, _desc, _sede, _dir, _otraCiudad, _maps, _wa, _cupos]) {
      c.dispose();
    }
    super.dispose();
  }

  // ---------------- Mapa ----------------

  void _mapaCambio(String v) {
    _debounce?.cancel();
    final s = v.trim();
    setState(() {
      _mapaError = null;
      if (s != _mapaResuelto) {
        _lat = null;
        _lng = null;
        _mapaResuelto = null;
      }
    });
    if (s.isEmpty) return;
    if (!esEnlaceGoogleMaps(s)) {
      setState(() => _mapaError = 'Este enlace no es de Google Maps. En Google Maps toca "Compartir" y copia el enlace.');
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 650), () => _resolverMapa(s));
  }

  Future<void> _resolverMapa(String url) async {
    final seq = ++_mapaSeq;
    setState(() {
      _mapaLoading = true;
      _mapaError = null;
    });
    try {
      final r = await Data.resolverMapa(url);
      if (!mounted || seq != _mapaSeq) return;
      final lat = (r['lat'] as num?)?.toDouble();
      final lng = (r['lng'] as num?)?.toDouble();
      setState(() {
        _mapaLoading = false;
        if (lat == null || lng == null) {
          _mapaError = 'No encontramos la ubicación en ese enlace. Prueba con el enlace de "Compartir".';
        } else {
          _lat = lat;
          _lng = lng;
          _mapaResuelto = url;
        }
      });
    } catch (e) {
      if (!mounted || seq != _mapaSeq) return;
      setState(() {
        _mapaLoading = false;
        _mapaError = 'No pudimos leer la ubicación: ${friendlyError(e)}';
      });
    }
  }

  Future<void> _pegarMapa() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final s = (d?.text ?? '').trim();
    if (!mounted) return;
    if (s.isEmpty) {
      showInfo(context, 'El portapapeles está vacío. Copia el enlace en Google Maps.');
      return;
    }
    // Si se copió texto con el enlace dentro ("Mira esta ubicación https://..."), toma solo el enlace.
    final m = RegExp(r'https?://\S+').firstMatch(s);
    final url = m?.group(0) ?? s;
    _maps.text = url;
    _maps.selection = TextSelection.collapsed(offset: url.length);
    _mapaCambio(url);
  }

  // ---------------- Portada ----------------

  Future<void> _elegirPortada(bool camara) async {
    try {
      final x = await WebpPipeline.elegir(camara: camara);
      if (x == null || !mounted) return;
      setState(() => _subiendo = true);
      final path = await Data.subirFoto(x, carpeta: 'jornadas');
      if (mounted) setState(() => _imagenPath = path);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  // ---------------- Fecha y guardar ----------------

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
    if (_form.currentState?.validate() != true) return;
    if (_subiendo) {
      showInfo(context, 'Espera a que termine de subir la portada.');
      return;
    }
    final maps = _maps.text.trim();
    if (maps.isNotEmpty && _mapaLoading) {
      showInfo(context, 'Estamos leyendo la ubicación del enlace. Inténtalo en un momento.');
      return;
    }
    final valido = maps.isNotEmpty && _mapaResuelto == maps && _lat != null && _lng != null;
    final inicio = DateTime(_fecha.year, _fecha.month, _fecha.day, _hora.hour, _hora.minute);
    final datos = <String, dynamic>{
      'titulo': _titulo.text.trim(),
      'descripcion': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'fecha_inicio': inicio.toUtc().toIso8601String(),
      'sede_nombre': _sede.text.trim(),
      'direccion': _dir.text.trim().isEmpty ? null : _dir.text.trim(),
      'ciudad': _ciudad == 'otra' ? _otraCiudad.text.trim() : _ciudad,
      'maps_url': maps.isEmpty ? null : maps,
      'lat': valido ? _lat : null,
      'lng': valido ? _lng : null,
      'imagen_path': _imagenPath,
      'whatsapp_url': _wa.text.trim().isEmpty ? null : _wa.text.trim(),
      'cupos_total': int.tryParse(_cupos.text.trim()) ?? 1,
      'incluye_limpieza_dental': _dental,
      'estado': _estado,
    };
    final uid = sb.auth.currentUser?.id;
    if (widget.jornada == null && uid != null) datos['created_by'] = uid;
    setState(() => _saving = true);
    try {
      await Data.guardarJornada(datos, id: widget.jornada?.id);
      if (!mounted) return;
      showInfo(
          context,
          maps.isNotEmpty && !valido
              ? 'Jornada guardada. No pudimos ubicarla en el mapa: revisa el enlace.'
              : (widget.jornada == null ? 'Jornada creada' : 'Jornada actualizada'));
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
    final mapsTxt = _maps.text.trim();
    final portadaUrl = Data.fotoUrl(_imagenPath);
    return Scaffold(
      appBar: AppBar(title: Text(widget.jornada == null ? 'Nueva jornada' : 'Editar jornada')),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          // ---- Portada ----
          FadeSlideIn(
            child: PopCard(
              padding: EdgeInsets.zero,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(Fz.radioTarjeta - 2)),
                  child: SizedBox(
                    height: 170,
                    child: Stack(fit: StackFit.expand, children: [
                      if (portadaUrl != null)
                        Image.network(portadaUrl, fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const ColoredBox(color: Fz.azul100))
                      else
                        ColoredBox(
                          color: Fz.azul700,
                          child: CustomPaint(
                            painter: PawPatternPainter(),
                            child: Center(
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.add_photo_alternate_rounded, size: 38, color: Fz.tarjeta),
                                const SizedBox(height: 6),
                                Text('Portada de la jornada', style: t.titleSmall?.copyWith(color: Fz.tarjeta)),
                              ]),
                            ),
                          ),
                        ),
                      if (_subiendo)
                        const ColoredBox(
                          color: Color(0x880E1C3A),
                          child: Center(child: CircularProgressIndicator(color: Fz.tarjeta)),
                        ),
                    ]),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                    OutlinedButton.icon(
                      onPressed: _subiendo ? null : () => _elegirPortada(false),
                      icon: const Icon(Icons.photo_library_rounded),
                      label: Text(portadaUrl == null ? 'Elegir foto' : 'Cambiar foto'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _subiendo ? null : () => _elegirPortada(true),
                      icon: const Icon(Icons.photo_camera_rounded),
                      label: const Text('Cámara'),
                    ),
                    if (portadaUrl != null)
                      TextButton.icon(
                        onPressed: _subiendo ? null : () => setState(() => _imagenPath = null),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: const Text('Quitar'),
                      ),
                  ]),
                ),
              ]),
            ),
          ),
          const SectionTitle('Datos de la jornada'),
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
          Text('Ciudad', textAlign: TextAlign.center, style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 8, children: [
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

          // ---- Mapa ----
          const SectionTitle('Ubicación en Google Maps'),
          TextFormField(
            controller: _maps,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(
              labelText: 'Enlace de Google Maps',
              hintText: 'https://maps.app.goo.gl/…',
              prefixIcon: const Icon(Icons.map_rounded),
              errorText: _mapaError,
              errorMaxLines: 3,
              suffixIcon: _mapaLoading
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : mapsTxt.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Borrar enlace',
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () {
                            _maps.clear();
                            _mapaCambio('');
                          },
                        ),
            ),
            onChanged: _mapaCambio,
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return null; // opcional
              if (!esEnlaceGoogleMaps(s)) return 'Este enlace no es de Google Maps.';
              return null;
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pegarMapa,
                icon: const Icon(Icons.content_paste_rounded),
                label: const Text('Pegar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: mapsTxt.isEmpty
                    ? null
                    : () async {
                        final ok = await abrirEnlace(mapsTxt);
                        if (!ok && context.mounted) showInfo(context, 'No pudimos abrir el enlace.');
                      },
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Abrir en Maps'),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_lat != null && _lng != null && _mapaResuelto != null && _mapaResuelto == mapsTxt) ...[
            MapaPreview(lat: _lat!, lng: _lng!, enlace: mapsTxt, height: 180),
            const SizedBox(height: 6),
            Text('Vista previa · toca el mapa para abrirlo', textAlign: TextAlign.center, style: t.bodySmall),
          ] else if (mapsTxt.isEmpty)
            Text(
              'En Google Maps busca la sede, toca "Compartir" y copia el enlace. Luego toca "Pegar".',
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),

          // ---- Detalles ----
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
            color: _dental ? Fz.azul100 : Fz.tarjeta,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SwitchListTile(
              value: _dental,
              onChanged: (v) => setState(() => _dental = v),
              title: Text('Incluye limpieza dental', style: t.titleMedium),
            ),
          ),
          gap,
          Text('Estado', textAlign: TextAlign.center, style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final e in estadosJornada)
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
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
          const SizedBox(height: 24),
          PopButton(
            label: widget.jornada == null ? 'Crear jornada' : 'Guardar cambios',
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving || _subiendo ? null : _guardar,
          ),
        ]),
      ),
    );
  }
}
