import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../owner/owner_shell.dart';
import '../owner/pets_screen.dart';
import 'visita_comun.dart';

const _maxMascotas = 5;
const _pasos = ['Servicio', 'Mascotas', 'Lugar', 'Fecha', 'Resumen'];

/// Pedir una visita o consulta a domicilio, por pasos.
class SolicitarVisitaScreen extends StatefulWidget {
  const SolicitarVisitaScreen({super.key});

  @override
  State<SolicitarVisitaScreen> createState() => _SolicitarVisitaScreenState();
}

class _SolicitarVisitaScreenState extends State<SolicitarVisitaScreen> {
  List<Map<String, dynamic>>? _servicios;
  List<Pet> _pets = [];
  Tasa? _tasa;
  Object? _error;

  int _paso = 0;
  Map<String, dynamic>? _servicio;
  final Set<String> _sel = {};
  final _motivo = TextEditingController();
  final _dir = TextEditingController();
  final _refLugar = TextEditingController();
  final _maps = TextEditingController();
  Map<String, dynamic>? _mapa; // {url, lat, lng}
  bool _resolviendo = false;
  DateTime? _fecha;
  String _franja = 'manana';
  bool _enviando = false;
  bool _intentoLugar = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _motivo.dispose();
    _dir.dispose();
    _refLugar.dispose();
    _maps.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([Data.serviciosDomicilio(), Data.misMascotas()]);
      Tasa? tasa;
      try {
        tasa = await Data.tasaVigente();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _servicios = r[0] as List<Map<String, dynamic>>;
        _pets = r[1] as List<Pet>;
        _tasa = tasa;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  double? get _precio => (_servicio?['precio_usd'] as num?)?.toDouble();

  // ---------- Mapa ----------
  Future<void> _pegarMapa() async {
    try {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      final tx = d?.text?.trim();
      if (tx == null || tx.isEmpty) {
        if (mounted) showInfo(context, 'No hay texto copiado.');
        return;
      }
      final m = RegExp(r'https?://\S+').firstMatch(tx);
      setState(() => _maps.text = m?.group(0) ?? tx);
      await _resolverMapa();
    } catch (_) {
      if (mounted) showInfo(context, 'No pudimos leer lo que copiaste.');
    }
  }

  Future<void> _resolverMapa() async {
    final url = _maps.text.trim();
    if (url.isEmpty) return;
    if (!url.startsWith('http')) {
      showInfo(context, 'Pega un enlace de Google Maps (empieza por https://).');
      return;
    }
    setState(() {
      _resolviendo = true;
      _mapa = null;
    });
    try {
      final r = await Data.resolverMapa(url);
      if (mounted) setState(() => _mapa = r);
    } catch (e) {
      if (mounted) showInfo(context, 'No pudimos leer la ubicación de ese enlace. Revisa que sea de Google Maps.');
    } finally {
      if (mounted) setState(() => _resolviendo = false);
    }
  }

  double? _num(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

  // ---------- Pasos ----------
  String? _problemaPaso() {
    switch (_paso) {
      case 0:
        return _servicio == null ? 'Elige el servicio que necesitas.' : null;
      case 1:
        return _sel.isEmpty ? 'Elige al menos una mascota.' : null;
      case 2:
        return _dir.text.trim().length < 8 ? 'Escribe la dirección completa (calle, casa o edificio, sector).' : null;
      case 3:
        return _fecha == null ? 'Elige la fecha que prefieres.' : null;
    }
    return null;
  }

  void _siguiente() {
    if (_paso == 2) setState(() => _intentoLugar = true);
    final p = _problemaPaso();
    if (p != null) {
      showInfo(context, p);
      return;
    }
    if (_paso < _pasos.length - 1) {
      FocusScope.of(context).unfocus();
      setState(() => _paso++);
    } else {
      _enviar();
    }
  }

  void _atras() {
    if (_paso == 0) {
      Navigator.pop(context);
    } else {
      setState(() => _paso--);
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha ?? inicio,
      firstDate: inicio,
      lastDate: inicio.add(const Duration(days: 90)),
      helpText: 'Fecha preferida',
    );
    if (d != null) setState(() => _fecha = d);
  }

  void _togglePet(Pet p) {
    setState(() {
      if (_sel.contains(p.id)) {
        _sel.remove(p.id);
      } else if (_sel.length >= _maxMascotas) {
        showInfo(context, 'Puedes elegir hasta $_maxMascotas mascotas por visita.');
      } else {
        _sel.add(p.id);
      }
    });
  }

  Future<void> _enviar() async {
    setState(() => _enviando = true);
    try {
      final mapsUrl = _maps.text.trim();
      final r = await Data.solicitarVisita(
        servicioId: (_servicio!['id'] as num).toInt(),
        petIds: _sel.toList(),
        motivo: _motivo.text.trim().isEmpty ? null : _motivo.text.trim(),
        direccion: _dir.text.trim(),
        referencia: _refLugar.text.trim().isEmpty ? null : _refLugar.text.trim(),
        mapsUrl: mapsUrl.isEmpty ? null : (_mapa?['url'] as String? ?? mapsUrl),
        lat: _num(_mapa?['lat']),
        lng: _num(_mapa?['lng']),
        fecha: _fecha!,
        franja: _franja,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => _VisitaEnviada(codigo: r['codigo'] as String?)),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  // ---------- UI ----------
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _paso == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _paso--);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Pedir visita o consulta')),
        body: _body(context),
        bottomNavigationBar: _servicios == null ? null : _pie(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los servicios',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: _load, expand: false),
      );
    }
    if (_servicios == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final contenido = switch (_paso) {
      0 => _pasoServicio(t),
      1 => _pasoMascotas(t),
      2 => _pasoLugar(t),
      3 => _pasoFecha(t),
      _ => _pasoResumen(t),
    };
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Progreso(paso: _paso),
        const SizedBox(height: 16),
        KeyedSubtree(key: ValueKey(_paso), child: FadeSlideIn(child: contenido)),
      ]),
    );
  }

  Widget _pie(BuildContext context) {
    final ultimo = _paso == _pasos.length - 1;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
        decoration: const BoxDecoration(
          color: Fz.tarjeta,
          border: Border(top: BorderSide(color: Fz.tinta, width: 2)),
        ),
        child: Row(children: [
          if (_paso > 0) ...[
            Expanded(
              flex: 2,
              child: PopButton.tonal(
                label: 'Atrás',
                icon: Icons.arrow_back_rounded,
                onPressed: _enviando ? null : _atras,
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: 3,
            child: PopButton(
              label: ultimo ? 'Enviar solicitud' : 'Siguiente',
              icon: ultimo ? Icons.send_rounded : Icons.arrow_forward_rounded,
              loading: _enviando,
              onPressed: _siguiente,
            ),
          ),
        ]),
      ),
    );
  }

  Widget _titulo(TextTheme t, String titulo, [String? sub]) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(children: [
          Text(titulo, textAlign: TextAlign.center, style: t.headlineSmall),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub, textAlign: TextAlign.center, style: t.bodySmall),
          ],
        ]),
      );

  Widget _pasoServicio(TextTheme t) {
    final s = _servicios!;
    if (s.isEmpty) {
      return const EmptyState(
        icon: Icons.home_repair_service_rounded,
        title: 'No hay servicios disponibles',
        message: 'Por ahora no tenemos visitas a domicilio. Vuelve a revisar pronto.',
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _titulo(t, '¿Qué necesitas?', 'Un veterinario va a tu casa.'),
      for (var k = 0; k < s.length; k++) ...[
        FadeSlideIn(
          index: k,
          child: _ServicioOpcion(
            s: s[k],
            selected: _servicio?['id'] == s[k]['id'],
            tasa: _tasa,
            onTap: () => setState(() => _servicio = s[k]),
          ),
        ),
        const SizedBox(height: 12),
      ],
    ]);
  }

  Widget _pasoMascotas(TextTheme t) {
    if (_pets.isEmpty) {
      return EmptyState(
        icon: Icons.pets_rounded,
        title: 'Primero registra a tu mascota',
        message: 'Así el veterinario sabe a quién va a atender.',
        action: PopButton(
          label: 'Ir a Mis mascotas',
          icon: Icons.add_rounded,
          expand: false,
          onPressed: () {
            OwnerShell.irA(context, 3);
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
      );
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _titulo(t, '¿A quién atendemos?', 'Elige hasta $_maxMascotas mascotas · ${_sel.length} elegida${_sel.length == 1 ? '' : 's'}'),
      LayoutBuilder(builder: (context, c) {
        final w = (c.maxWidth - 2 * 10) / 3;
        return Wrap(spacing: 10, runSpacing: 10, alignment: WrapAlignment.center, children: [
          for (final p in _pets)
            SizedBox(width: w, child: _PetOpcion(p: p, selected: _sel.contains(p.id), onTap: () => _togglePet(p))),
        ]);
      }),
      const SizedBox(height: 20),
      Text('Motivo o síntomas', textAlign: TextAlign.center, style: t.titleMedium),
      const SizedBox(height: 8),
      TextField(
        controller: _motivo,
        minLines: 3,
        maxLines: 6,
        maxLength: 500,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Ej.: no come desde ayer, vómitos, le toca la vacuna…',
          helperText: 'Opcional, pero ayuda al veterinario a prepararse.',
        ),
      ),
    ]);
  }

  Widget _pasoLugar(TextTheme t) {
    final lat = _num(_mapa?['lat']), lng = _num(_mapa?['lng']);
    final dirError = _intentoLugar && _dir.text.trim().length < 8;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _titulo(t, '¿Dónde es la visita?', 'Escribe la dirección como se la darías a un taxista.'),
      TextField(
        controller: _dir,
        minLines: 2,
        maxLines: 4,
        textCapitalization: TextCapitalization.sentences,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Dirección',
          hintText: 'Av., calle, casa o edificio, sector',
          prefixIcon: const Icon(Icons.home_rounded),
          errorText: dirError ? 'Escribe la dirección completa' : null,
        ),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: _refLugar,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Punto de referencia (opcional)',
          hintText: 'Frente a la panadería, portón negro…',
          prefixIcon: Icon(Icons.place_rounded),
        ),
      ),
      const SizedBox(height: 20),
      Text('Ubicación en Google Maps (opcional)', textAlign: TextAlign.center, style: t.titleMedium),
      const SizedBox(height: 4),
      Text('En Google Maps toca tu ubicación › Compartir › Copiar enlace, y pégalo aquí.',
          textAlign: TextAlign.center, style: t.bodySmall),
      const SizedBox(height: 10),
      TextField(
        controller: _maps,
        keyboardType: TextInputType.url,
        onChanged: (_) => setState(() => _mapa = null),
        onSubmitted: (_) => _resolverMapa(),
        decoration: InputDecoration(
          labelText: 'Enlace de Google Maps',
          hintText: 'https://maps.app.goo.gl/…',
          prefixIcon: const Icon(Icons.link_rounded),
          suffixIcon: _maps.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Quitar enlace',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() {
                    _maps.clear();
                    _mapa = null;
                  }),
                ),
        ),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: PopButton.tonal(
            label: 'Pegar',
            icon: Icons.content_paste_rounded,
            onPressed: _resolviendo ? null : _pegarMapa,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PopButton.tonal(
            label: 'Ver en mapa',
            icon: Icons.map_rounded,
            loading: _resolviendo,
            onPressed: _resolviendo ? null : _resolverMapa,
          ),
        ),
      ]),
      if (lat != null && lng != null) ...[
        const SizedBox(height: 14),
        MapaPreview(lat: lat, lng: lng, enlace: _mapa?['url'] as String? ?? _maps.text.trim(), height: 180),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: Fz.azul),
          const SizedBox(width: 6),
          Text('Ubicación encontrada', style: t.titleSmall),
        ]),
      ],
    ]);
  }

  Widget _pasoFecha(TextTheme t) {
    final f = _fecha == null ? null : DateFormat("EEEE d 'de' MMMM", 'es').format(_fecha!);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _titulo(t, '¿Cuándo te viene bien?', 'Es tu preferencia: la administración confirma la fecha y la hora.'),
      PopCard(
        color: _fecha == null ? Fz.tarjeta : Fz.azul50,
        onTap: _elegirFecha,
        child: Row(children: [
          const Icon(Icons.event_rounded, color: Fz.azul),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fecha preferida', style: t.bodySmall),
              Text(f == null ? 'Toca para elegir' : f[0].toUpperCase() + f.substring(1), style: t.titleMedium),
            ]),
          ),
          const Icon(Icons.edit_calendar_rounded, color: Fz.azul),
        ]),
      ),
      const SizedBox(height: 20),
      Text('Franja', textAlign: TextAlign.center, style: t.titleMedium),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: _FranjaOpcion(
            label: 'Mañana',
            icon: Icons.wb_sunny_rounded,
            selected: _franja == 'manana',
            onTap: () => setState(() => _franja = 'manana'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _FranjaOpcion(
            label: 'Tarde',
            icon: Icons.wb_twilight_rounded,
            selected: _franja == 'tarde',
            onTap: () => setState(() => _franja = 'tarde'),
          ),
        ),
      ]),
    ]);
  }

  Widget _pasoResumen(TextTheme t) {
    final nombres = _pets.where((p) => _sel.contains(p.id)).map((p) => p.nombre).join(', ');
    final f = DateFormat("EEEE d 'de' MMMM", 'es').format(_fecha!);
    final precio = _precio;
    Widget fila(IconData ic, String l, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(ic, size: 20, color: Fz.azul),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(l, style: t.bodySmall),
                Text(v, style: t.titleSmall),
              ]),
            ),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _titulo(t, 'Revisa tu solicitud'),
      FzHero(
        title: precio == null ? 'Precio por confirmar' : Money.usd(precio),
        subtitle: precio == null
            ? 'La administración te dirá el precio'
            : (_tasa == null
                ? 'Precio de referencia · el monto en Bs se confirma al pagar'
                : 'Precio de referencia · ${Money.bs(Money.aBs(precio, _tasa!.valor))}'),
        leading: const Icon(Icons.home_rounded, size: 34, color: Fz.tarjeta),
      ),
      const SizedBox(height: 14),
      PopCard(
        color: Fz.tarjeta,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          fila(Icons.medical_services_rounded, 'Servicio',
              '${_servicio!['nombre']} · ${duracionTexto((_servicio!['duracion_min'] as num?)?.toInt())}'),
          fila(Icons.pets_rounded, 'Mascotas', nombres),
          if (_motivo.text.trim().isNotEmpty) fila(Icons.notes_rounded, 'Motivo o síntomas', _motivo.text.trim()),
          fila(Icons.home_rounded, 'Dirección', _dir.text.trim()),
          if (_refLugar.text.trim().isNotEmpty) fila(Icons.place_rounded, 'Referencia', _refLugar.text.trim()),
          if (_maps.text.trim().isNotEmpty)
            fila(Icons.map_rounded, 'Google Maps', _mapa != null ? 'Ubicación encontrada' : _maps.text.trim()),
          fila(Icons.event_rounded, 'Fecha preferida', '${f[0].toUpperCase()}${f.substring(1)} · ${franjaTexto(_franja)}'),
        ]),
      ),
      const SizedBox(height: 14),
      PopCard(
        color: Fz.azul50,
        shadow: false,
        child: Row(children: [
          const Icon(Icons.info_rounded, color: Fz.azul),
          const SizedBox(width: 10),
          Expanded(
            child: Text('La administración te confirmará la fecha, la hora y el precio. Pagas cuando el precio esté confirmado.',
                style: t.bodyMedium),
          ),
        ]),
      ),
    ]);
  }
}

class _Progreso extends StatelessWidget {
  const _Progreso({required this.paso});
  final int paso;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      label: 'Paso ${paso + 1} de ${_pasos.length}: ${_pasos[paso]}',
      excludeSemantics: true,
      child: Column(children: [
        Row(children: [
          for (var k = 0; k < _pasos.length; k++) ...[
            if (k > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 10,
                decoration: BoxDecoration(
                  color: k < paso ? Fz.azul : (k == paso ? Fz.azul400 : Fz.tarjeta),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Fz.tinta, width: 1.5),
                ),
              ),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Text('Paso ${paso + 1} de ${_pasos.length} · ${_pasos[paso]}', textAlign: TextAlign.center, style: t.labelMedium),
      ]),
    );
  }
}

class _ServicioOpcion extends StatelessWidget {
  const _ServicioOpcion({required this.s, required this.selected, required this.onTap, this.tasa});
  final Map<String, dynamic> s;
  final bool selected;
  final VoidCallback onTap;
  final Tasa? tasa;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = selected ? Fz.tarjeta : Fz.tinta;
    final sub = selected ? Fz.azul50 : Fz.variante;
    final precio = (s['precio_usd'] as num?)?.toDouble();
    final desc = s['descripcion'] as String?;
    return Semantics(
      selected: selected,
      button: true,
      child: PopCard(
        color: selected ? Fz.azul : Fz.tarjeta,
        shadow: selected,
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: selected ? Fz.tarjeta : Fz.azul100,
              shape: BoxShape.circle,
              border: Border.all(color: Fz.tinta, width: Fz.borde),
            ),
            child: Icon(selected ? Icons.check_rounded : Icons.medical_services_rounded, color: selected ? Fz.azul : Fz.tinta),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${s['nombre']}', style: t.titleMedium?.copyWith(color: fg)),
              if (desc != null && desc.trim().isNotEmpty) Text(desc, style: t.bodySmall?.copyWith(color: sub)),
              const SizedBox(height: 2),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 16, color: sub),
                const SizedBox(width: 4),
                Text(duracionTexto((s['duracion_min'] as num?)?.toInt()), style: t.labelMedium?.copyWith(color: sub)),
              ]),
            ]),
          ),
          const SizedBox(width: 8),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(precio == null ? 'Precio por\nconfirmar' : Money.usd(precio),
                textAlign: TextAlign.end,
                style: precio == null ? t.labelMedium?.copyWith(color: fg) : t.titleLarge?.copyWith(color: fg)),
            if (precio != null && tasa != null)
              Text(Money.bs(Money.aBs(precio, tasa!.valor)), style: t.labelSmall?.copyWith(color: sub)),
          ]),
        ]),
      ),
    );
  }
}

class _PetOpcion extends StatelessWidget {
  const _PetOpcion({required this.p, required this.selected, required this.onTap});
  final Pet p;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      selected: selected,
      button: true,
      label: p.nombre,
      child: PopCard(
        color: selected ? Fz.azul : Fz.tarjeta,
        shadow: selected,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        child: Stack(children: [
          Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              PetAvatar(esPerro: p.esPerro, url: p.fotoUrl, size: 52),
              const SizedBox(height: 6),
              Text(p.nombre,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleSmall?.copyWith(color: selected ? Fz.tarjeta : Fz.tinta)),
              Text(p.esPerro ? 'Perro' : 'Gato',
                  textAlign: TextAlign.center, style: t.labelSmall?.copyWith(color: selected ? Fz.azul50 : Fz.variante)),
            ]),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Icon(selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                size: 20, color: selected ? Fz.tarjeta : Fz.variante),
          ),
        ]),
      ),
    );
  }
}

class _FranjaOpcion extends StatelessWidget {
  const _FranjaOpcion({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: PopCard(
          onTap: onTap,
          color: selected ? Fz.azul : Fz.tarjeta,
          shadow: selected,
          child: SizedBox(
            height: 64,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(selected ? Icons.check_circle_rounded : icon, color: selected ? Fz.tarjeta : Fz.tinta),
              const SizedBox(height: 4),
              Text(label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: selected ? Fz.tarjeta : Fz.tinta)),
            ]),
          ),
        ),
      );
}

class _VisitaEnviada extends StatelessWidget {
  const _VisitaEnviada({this.codigo});
  final String? codigo;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.check_circle_rounded,
          title: 'Solicitud enviada',
          message: 'La administración te confirmará la fecha, la hora y el precio. Te avisaremos por notificación.',
          action: Column(mainAxisSize: MainAxisSize.min, children: [
            if (codigo != null) ...[
              CodigoCopiable(codigo!, grande: true),
              const SizedBox(height: 16),
            ],
            PopButton(label: 'Ver mis visitas', icon: Icons.list_alt_rounded, expand: false, onPressed: () => Navigator.pop(context)),
          ]),
        ),
      ),
    );
  }
}
