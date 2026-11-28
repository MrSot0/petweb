import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'settings_screen.dart' show rolTexto, rolIcono;

/// Opciones de rol: uno solo por persona. "propietario" = sin rol de equipo.
const _opciones = [
  ('propietario', 'Solo usa la app como propietario: mascotas, jornadas y pagos.'),
  ('cirujano', 'Ve las jornadas, escanea códigos y registra cirugías.'),
  ('contador', 'Verifica pagos, actualiza la tasa y ve estadísticas.'),
  ('admin', 'Acceso completo: jornadas, precios, usuarios y datos de cobro.'),
];

/// Rol de equipo a partir de la lista de user_roles (ignora 'propietario').
String _rolDe(Map<String, dynamic> u) {
  final roles = ((u['user_roles'] as List?) ?? const []).map((r) => (r as Map)['rol'] as String).toSet();
  for (final r in const ['admin', 'contador', 'cirujano']) {
    if (roles.contains(r)) return r;
  }
  return 'propietario';
}

/// Usuarios y roles (solo administración). Cada persona tiene UN rol de equipo o ninguno;
/// todas pueden usar el modo propietario.
class UsuariosScreen extends StatefulWidget {
  const UsuariosScreen({super.key});

  @override
  State<UsuariosScreen> createState() => _UsuariosScreenState();
}

class _UsuariosScreenState extends State<UsuariosScreen> {
  List<Map<String, dynamic>>? _items;
  Object? _error;
  String _q = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.usuarios();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _abrir(Map<String, dynamic> u) async {
    final cambiado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RolSheet(usuario: u, actual: _rolDe(u)),
    );
    if (cambiado == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Usuarios y roles')), body: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_error != null && _items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los usuarios',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (_items == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final me = sb.auth.currentUser?.id;
    final q = _q.toLowerCase();
    final items = _items!
        .where((u) => q.isEmpty || '${u['nombre'] ?? ''} ${u['email'] ?? ''} ${u['cedula'] ?? ''}'.toLowerCase().contains(q))
        .toList();
    final equipo = _items!.where((u) => _rolDe(u) != 'propietario').length;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        FadeSlideIn(
          child: FzHero(
            title: '${_items!.length} personas',
            subtitle: '$equipo en el equipo. Toca a alguien para cambiar su rol. '
                'El cambio se aplica cuando la persona vuelve a abrir la app.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Buscar por nombre, correo o cédula',
          ),
          onChanged: (v) => setState(() => _q = v.trim()),
        ),
        const SizedBox(height: 14),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.person_search_rounded,
            title: 'Sin resultados',
            message: 'Prueba con otro nombre, correo o cédula.',
          ),
        for (var k = 0; k < items.length; k++) ...[
          FadeSlideIn(
            index: k + 1,
            child: Builder(builder: (context) {
              final u = items[k];
              final rol = _rolDe(u);
              final nombre = (u['nombre'] as String?)?.trim();
              final equipoRol = rol != 'propietario';
              return PopCard(
                color: k.isEven ? Fz.tarjeta : Fz.azul50,
                padding: const EdgeInsets.all(14),
                onTap: () => _abrir(u),
                child: Row(children: [
                  FzAvatar(url: Data.fotoUrl(u['avatar_path'] as String?), text: iniciales(nombre), size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '${nombre?.isNotEmpty == true ? nombre : 'Sin nombre'}${u['id'] == me ? ' (tú)' : ''}',
                        style: t.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        [u['email'], u['cedula']].whereType<String>().join(' · '),
                        style: t.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      StatusPill(
                        rolTexto(rol),
                        icon: rolIcono(rol),
                        color: equipoRol ? Fz.azul100 : Fz.tarjeta,
                        dashed: !equipoRol,
                      ),
                    ]),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Fz.azul),
                ]),
              );
            }),
          ),
          const SizedBox(height: 12),
        ],
      ]),
    );
  }
}

class _RolSheet extends StatefulWidget {
  const _RolSheet({required this.usuario, required this.actual});
  final Map<String, dynamic> usuario;
  final String actual;

  @override
  State<_RolSheet> createState() => _RolSheetState();
}

class _RolSheetState extends State<_RolSheet> {
  late String _rol = widget.actual;
  bool _saving = false;

  bool get _soyYo => widget.usuario['id'] == sb.auth.currentUser?.id;

  Future<void> _guardar() async {
    final u = widget.usuario;
    final nombre = (u['nombre'] as String?)?.trim().isNotEmpty == true ? u['nombre'] as String : (u['email'] ?? 'esta persona');
    if (_soyYo && widget.actual == 'admin' && _rol != 'admin') {
      showInfo(context, 'No puedes quitarte a ti mismo el rol de administración. Pídeselo a otra persona administradora.');
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Cambiar rol?', textAlign: TextAlign.center),
        content: Text(
          '$nombre pasará de ${rolTexto(widget.actual)} a ${rolTexto(_rol)}.\n\n'
          'El cambio se aplica cuando la persona vuelve a abrir la app.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, cambiar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await Data.setRol(u['id'] as String, _rol);
      if (!mounted) return;
      showInfo(context, 'Listo: $nombre ahora es ${rolTexto(_rol)}.');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final s = e.toString().toLowerCase();
      showInfo(
        context,
        s.contains('ti mismo') || s.contains('yourself') || s.contains('propio') || s.contains('self')
            ? 'No puedes quitarte a ti mismo el rol de administración.'
            : 'No se pudo cambiar el rol: ${friendlyError(e)}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final u = widget.usuario;
    final nombre = (u['nombre'] as String?)?.trim();
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Center(child: FzAvatar(url: Data.fotoUrl(u['avatar_path'] as String?), text: iniciales(nombre), size: 64)),
          const SizedBox(height: 8),
          Text(nombre?.isNotEmpty == true ? nombre! : 'Sin nombre', textAlign: TextAlign.center, style: t.headlineSmall),
          if (u['email'] != null) Text(u['email'] as String, textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 6),
          Text('Elige un solo rol. Todas las personas pueden usar el modo propietario.',
              textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Fz.variante)),
          const SizedBox(height: 14),
          for (final (r, desc) in _opciones) ...[
            _OpcionRol(
              rol: r,
              desc: desc,
              selected: _rol == r,
              actual: widget.actual == r,
              onTap: _saving ? null : () => setState(() => _rol = r),
            ),
            const SizedBox(height: 10),
          ],
          if (_soyYo && widget.actual == 'admin')
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text('Esta es tu cuenta: no puedes quitarte el rol de administración.',
                  textAlign: TextAlign.center, style: t.bodySmall),
            ),
          Text('El cambio se aplica cuando la persona vuelve a abrir la app.',
              textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 12),
          PopButton(
            label: 'Guardar',
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _rol == widget.actual || _saving ? null : _guardar,
          ),
        ]),
      ),
    );
  }
}

class _OpcionRol extends StatelessWidget {
  const _OpcionRol({required this.rol, required this.desc, required this.selected, required this.actual, this.onTap});
  final String rol;
  final String desc;
  final bool selected;
  final bool actual;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fg = selected ? Fz.tarjeta : Fz.tinta;
    return Semantics(
      selected: selected,
      button: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected ? Fz.azul : Fz.tarjeta,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Fz.tinta, width: Fz.borde),
          boxShadow: selected ? const [BoxShadow(color: Fz.tinta, offset: Fz.sombra)] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(rolIcono(rol), color: selected ? Fz.tarjeta : Fz.azul, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(rolTexto(rol) + (actual ? ' (actual)' : ''), style: t.titleMedium?.copyWith(color: fg)),
                    Text(desc, style: t.bodySmall?.copyWith(color: selected ? Fz.azul50 : Fz.variante)),
                  ]),
                ),
                Icon(selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded, color: fg),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
