import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'tasa_screen.dart' show parseBs;
import 'verificar_screen.dart' show staffNum, staffStr;

/// Servicios y precios de las visitas a domicilio (solo administración).
class ServiciosDomicilioScreen extends StatefulWidget {
  const ServiciosDomicilioScreen({super.key});

  @override
  State<ServiciosDomicilioScreen> createState() => _ServiciosDomicilioScreenState();
}

class _ServiciosDomicilioScreenState extends State<ServiciosDomicilioScreen> {
  List<Map<String, dynamic>>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.serviciosDomicilio(todos: true);
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _editar([Map<String, dynamic>? s]) async {
    final siguiente = (_items ?? const []).fold<int>(0, (m, e) {
      final o = (staffNum(e['orden']) ?? 0).round();
      return o > m ? o : m;
    });
    final ok = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => _ServicioFormScreen(servicio: s, ordenSugerido: siguiente + 1)),
    );
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Servicios a domicilio')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nuevo servicio'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null && _items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los servicios',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: items.length + 1,
        itemBuilder: (_, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(children: [
                FadeSlideIn(
                  child: FzHero(
                    leading: const Icon(Icons.home_work_rounded, color: Fz.tarjeta, size: 34),
                    title: 'Servicios y precios',
                    subtitle: 'Lo que los propietarios pueden pedir a domicilio. Sin precio = "por confirmar".',
                  ),
                ),
                if (items.isEmpty)
                  const EmptyState(
                    icon: Icons.medical_services_rounded,
                    title: 'Aún no hay servicios',
                    message: 'Crea el primero con "Nuevo servicio".',
                  ),
              ]),
            );
          }
          final s = items[i - 1];
          final activo = s['activo'] != false;
          final precio = staffNum(s['precio_usd']);
          final dur = staffNum(s['duracion_min'])?.round();
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeSlideIn(
              index: i,
              child: Opacity(
                opacity: activo ? 1 : .65,
                child: PopCard(
                  color: i.isEven ? Fz.azul50 : Fz.tarjeta,
                  padding: const EdgeInsets.all(14),
                  onTap: () => _editar(s),
                  child: Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(staffStr(s['nombre']) ?? 'Servicio', style: t.titleMedium),
                        if (staffStr(s['descripcion']) != null)
                          Text(staffStr(s['descripcion'])!, style: t.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 6),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          if (dur != null) StatusPill('$dur min', icon: Icons.schedule_rounded, color: Fz.tarjeta),
                          activo
                              ? const StatusPill('Activo', icon: Icons.visibility_rounded, color: Fz.azul100)
                              : const StatusPill('Oculto', icon: Icons.visibility_off_rounded, color: Fz.tarjeta, dashed: true),
                        ]),
                      ]),
                    ),
                    const SizedBox(width: 10),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(precio == null ? 'Por confirmar' : Money.usd(precio),
                          style: precio == null ? t.titleSmall : Fz.display(19)),
                      Text('orden ${(staffNum(s['orden']) ?? 0).round()}', style: t.bodySmall),
                    ]),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ServicioFormScreen extends StatefulWidget {
  const _ServicioFormScreen({this.servicio, required this.ordenSugerido});
  final Map<String, dynamic>? servicio;
  final int ordenSugerido;

  @override
  State<_ServicioFormScreen> createState() => _ServicioFormScreenState();
}

class _ServicioFormScreenState extends State<_ServicioFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre, _desc, _dur, _precio, _orden;
  late bool _activo;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.servicio;
    String num(dynamic v) {
      final n = staffNum(v);
      if (n == null) return '';
      return n == n.roundToDouble() ? n.round().toString() : n.toString();
    }

    _nombre = TextEditingController(text: staffStr(s?['nombre']) ?? '');
    _desc = TextEditingController(text: staffStr(s?['descripcion']) ?? '');
    _dur = TextEditingController(text: s == null ? '60' : num(s['duracion_min']));
    _precio = TextEditingController(text: num(s?['precio_usd']));
    _orden = TextEditingController(text: s == null ? '${widget.ordenSugerido}' : num(s['orden']));
    _activo = s?['activo'] != false;
  }

  @override
  void dispose() {
    for (final c in [_nombre, _desc, _dur, _precio, _orden]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_form.currentState?.validate() != true) return;
    final datos = <String, dynamic>{
      'nombre': _nombre.text.trim(),
      'descripcion': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'duracion_min': int.tryParse(_dur.text.trim()),
      'precio_usd': _precio.text.trim().isEmpty ? null : parseBs(_precio.text),
      'activo': _activo,
      'orden': int.tryParse(_orden.text.trim()) ?? 0,
    };
    final id = widget.servicio?['id'];
    setState(() => _saving = true);
    try {
      await Data.guardarServicioDomicilio(datos, id: id is int ? id : (id is num ? id.toInt() : null));
      if (!mounted) return;
      showInfo(context, widget.servicio == null ? 'Servicio creado' : 'Servicio actualizado');
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
    return Scaffold(
      appBar: AppBar(title: Text(widget.servicio == null ? 'Nuevo servicio' : 'Editar servicio')),
      body: Form(
        key: _form,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _nombre,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Consulta general a domicilio'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe el nombre del servicio' : null,
            ),
            gap,
            TextFormField(
              controller: _desc,
              maxLines: 4,
              minLines: 2,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
            ),
            gap,
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(
                child: TextFormField(
                  controller: _dur,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Duración (min)'),
                  validator: (v) {
                    final n = int.tryParse((v ?? '').trim());
                    if (n == null || n < 5) return 'Mínimo 5 min';
                    if (n > 600) return 'Máximo 600 min';
                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _precio,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: r'Precio en $', prefixText: r'$ ', helperText: 'Vacío = por confirmar'),
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return null;
                    final n = parseBs(s);
                    if (n == null || n <= 0) return 'Monto no válido';
                    if (n > 2000) return 'Demasiado alto';
                    return null;
                  },
                ),
              ),
            ]),
            gap,
            TextFormField(
              controller: _orden,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Orden en la lista', helperText: 'Los números menores van primero.'),
            ),
            gap,
            PopCard(
              shadow: false,
              color: _activo ? Fz.azul100 : Fz.tarjeta,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SwitchListTile(
                value: _activo,
                onChanged: (v) => setState(() => _activo = v),
                title: Text('Activo', style: t.titleMedium),
                subtitle: Text(_activo ? 'Los propietarios lo ven al pedir una cita.' : 'Oculto para los propietarios.'),
              ),
            ),
            const SizedBox(height: 24),
            PopButton(
              label: widget.servicio == null ? 'Crear servicio' : 'Guardar cambios',
              icon: Icons.save_rounded,
              loading: _saving,
              onPressed: _saving ? null : _guardar,
            ),
          ]),
        ),
      ),
    );
  }
}
