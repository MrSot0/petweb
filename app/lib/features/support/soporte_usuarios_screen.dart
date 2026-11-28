import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../scan/ficha_screen.dart';

String _rolTexto(String? r) => switch (r) {
  'admin' => 'Administración',
  'contador' => 'Contador',
  'cirujano' => 'Cirujano',
  'soporte' => 'Soporte',
  _ => 'Propietario',
};

String _fechaHora(String? iso) {
  final d = DateTime.tryParse(iso ?? '');
  return d == null ? '—' : Money.fechaLarga(d);
}

/// 0414-1234567 -> 584141234567 (para wa.me).
String _waNumero(String telefono) {
  var d = telefono.replaceAll(RegExp(r'\D'), '');
  if (d.startsWith('0')) d = d.substring(1);
  if (!d.startsWith('58')) d = '58$d';
  return d;
}

/// Mensaje amable cuando el servidor bloquea una acción de soporte.
String _errorSoporte(Object e) {
  var s = e.toString();
  if (e is FunctionException) {
    final det = e.details;
    if (det is Map && det['error'] != null) s = det['error'].toString();
    if (e.status == 403) {
      return 'No tienes permiso para esto. Soporte no puede cambiar roles ni modificar cuentas de administración.';
    }
  }
  final l = s.toLowerCase();
  if (l.contains('admin') ||
      l.contains('permiso') ||
      l.contains('forbidden') ||
      l.contains('not allowed') ||
      l.contains('row-level security') ||
      l.contains('rol')) {
    return 'No tienes permiso para esto. Soporte no puede cambiar roles ni modificar cuentas de administración.';
  }
  return friendlyError(s);
}

/// Pestaña "Usuarios" del rol soporte: buscar cuentas y ayudar a sus dueños.
class SoporteUsuariosScreen extends StatefulWidget {
  const SoporteUsuariosScreen({super.key});

  @override
  State<SoporteUsuariosScreen> createState() => _SoporteUsuariosScreenState();
}

class _SoporteUsuariosScreenState extends State<SoporteUsuariosScreen> {
  final _buscar = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>>? _items;
  Object? _error;
  bool _cargando = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = ++_token;
    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      final r = await Data.soporteUsuarios(_buscar.text);
      if (mounted && token == _token) setState(() => _items = r);
    } catch (e) {
      if (mounted && token == _token) setState(() => _error = e);
    } finally {
      if (mounted && token == _token) setState(() => _cargando = false);
    }
  }

  void _onBuscar(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
    setState(() {});
  }

  Future<void> _abrir(Map<String, dynamic> u) async {
    final cambio = await Navigator.of(context)
        .push<bool>(MaterialPageRoute(builder: (_) => SoporteUsuarioDetalle(usuario: u)));
    if (cambio == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = _items;
    final hero = FzHero(
      title: 'Soporte',
      subtitle: 'Busca una cuenta para ayudar a su dueño',
      leading: const Icon(Icons.support_agent_rounded, size: 40, color: Fz.tarjeta),
      child: TextField(
        controller: _buscar,
        onChanged: _onBuscar,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) {
          _debounce?.cancel();
          _load();
        },
        decoration: InputDecoration(
          hintText: 'Nombre, correo, cédula o teléfono',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _buscar.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Limpiar búsqueda',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () {
                    _buscar.clear();
                    _debounce?.cancel();
                    _load();
                  },
                ),
        ),
      ),
    );

    final children = <Widget>[
      FadeSlideIn(child: hero),
      if (_cargando) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator()),
      const SizedBox(height: 14),
    ];
    if (_error != null && items == null) {
      children.add(
        EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'No pudimos cargar los usuarios',
          message: friendlyError(_error!),
          action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
        ),
      );
    } else if (items == null) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    } else if (items.isEmpty) {
      children.add(
        EmptyState(
          icon: Icons.person_search_rounded,
          title: 'Sin resultados',
          message: _buscar.text.trim().isEmpty
              ? 'Todavía no hay usuarios registrados.'
              : 'No encontramos cuentas con "${_buscar.text.trim()}". Prueba con otro dato.',
        ),
      );
    } else {
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Text(
            '${items.length} ${items.length == 1 ? 'cuenta' : 'cuentas'}',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            itemCount: children.length + (items?.length ?? 0),
            itemBuilder: (context, i) {
              if (i < children.length) return children[i];
              final idx = i - children.length;
              final u = items![idx];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: FadeSlideIn(
                  index: idx + 1,
                  child: _UsuarioCard(u: u, alterna: idx.isOdd, onTap: () => _abrir(u)),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _UsuarioCard extends StatelessWidget {
  const _UsuarioCard({required this.u, required this.alterna, required this.onTap});
  final Map<String, dynamic> u;
  final bool alterna;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nombre = (u['nombre'] as String?)?.trim();
    final confirmado = u['confirmado'] != false;
    final pend = (u['pagos_pendientes'] as num?)?.toInt() ?? 0;
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              FzAvatar(url: Data.fotoUrl(u['avatar_path'] as String?), text: iniciales(nombre), size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nombre == null || nombre.isEmpty ? 'Sin nombre' : nombre, style: t.titleMedium),
                    Text(u['email'] as String? ?? '—', style: t.bodySmall, overflow: TextOverflow.ellipsis),
                    Text(
                      u['ultimo_acceso'] == null
                          ? 'Nunca ha entrado'
                          : 'Último acceso: ${_fechaHora(u['ultimo_acceso'] as String?)}',
                      style: t.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Fz.azul),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              StatusPill(
                _rolTexto(u['rol'] as String?),
                icon: u['rol'] == 'admin' ? Icons.shield_rounded : Icons.person_rounded,
                color: Fz.azul100,
              ),
              if (!confirmado)
                const StatusPill(
                  'Correo sin confirmar',
                  icon: Icons.mark_email_unread_rounded,
                  color: Fz.frambuesaSuave,
                  dashed: true,
                ),
              StatusPill('${u['mascotas'] ?? 0} mascotas', icon: Icons.pets_rounded, color: Fz.tarjeta),
              StatusPill('${u['inscripciones'] ?? 0} inscripciones', icon: Icons.event_rounded, color: Fz.tarjeta),
              if (pend > 0)
                StatusPill(
                  '$pend ${pend == 1 ? 'pago pendiente' : 'pagos pendientes'}',
                  icon: Icons.hourglass_top_rounded,
                  color: Fz.azul200,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Detalle de una cuenta para soporte: datos editables, acciones de acceso y consulta.
class SoporteUsuarioDetalle extends StatefulWidget {
  const SoporteUsuarioDetalle({super.key, required this.usuario});
  final Map<String, dynamic> usuario;

  @override
  State<SoporteUsuarioDetalle> createState() => _SoporteUsuarioDetalleState();
}

class _SoporteUsuarioDetalleState extends State<SoporteUsuarioDetalle> {
  late final Map<String, dynamic> _u = Map<String, dynamic>.from(widget.usuario);
  late final _nombre = TextEditingController(text: _u['nombre'] as String? ?? '');
  late final _cedula = TextEditingController(text: _u['cedula'] as String? ?? '');
  late final _telefono = TextEditingController(text: _u['telefono'] as String? ?? '');
  final _form = GlobalKey<FormState>();
  bool _guardando = false;
  String? _accionEnCurso;
  bool _cambio = false;

  late Future<List<Map<String, dynamic>>> _mascotas;
  late Future<List<Map<String, dynamic>>> _inscripciones;
  late Future<List<Map<String, dynamic>>> _pagos;
  late Future<List<Map<String, dynamic>>> _bitacora;

  String get _id => _u['id'] as String;
  bool get _esAdmin => _u['rol'] == 'admin';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombre.dispose();
    _cedula.dispose();
    _telefono.dispose();
    super.dispose();
  }

  void _cargar() {
    _mascotas = Data.mascotasDe(_id);
    _inscripciones = Data.inscripcionesDe(_id);
    _pagos = Data.pagosDe(_id);
    _bitacora = Data.bitacoraSoporte(_id);
  }

  Future<void> _refrescar() async {
    setState(_cargar);
    await Future.wait(
      [_mascotas, _inscripciones, _pagos, _bitacora].map((f) => f.catchError((_) => <Map<String, dynamic>>[])),
    );
  }

  Future<bool> _confirmar(String titulo, String mensaje, String accion) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(titulo, textAlign: TextAlign.center),
          content: Text(mensaje, textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(accion)),
          ],
        ),
      ) ==
      true;

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final cambios = {
      'nombre': _nombre.text.trim(),
      'cedula': _cedula.text.trim().isEmpty ? null : _cedula.text.trim(),
      'telefono': _telefono.text.trim().isEmpty ? null : _telefono.text.trim(),
    };
    if (!await _confirmar('Guardar cambios', '¿Actualizar los datos de ${_nombre.text.trim()}?', 'Guardar')) return;
    setState(() => _guardando = true);
    try {
      await Data.editarPerfilDe(_id, cambios);
      _u.addAll(cambios);
      _cambio = true;
      if (mounted) showInfo(context, 'Datos actualizados.');
      setState(() => _bitacora = Data.bitacoraSoporte(_id));
    } catch (e) {
      if (mounted) showInfo(context, _errorSoporte(e));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _accion(String accion) async {
    final nombre = (_u['nombre'] as String?) ?? 'este usuario';
    final (titulo, msg, boton) = switch (accion) {
      'reiniciar_clave' => (
        'Reiniciar contraseña',
        'Se creará una contraseña temporal para $nombre y la actual dejará de funcionar.',
        'Reiniciar',
      ),
      'enviar_recuperacion' => (
        'Enviar correo de recuperación',
        'Le enviaremos a ${_u['email'] ?? 'su correo'} un enlace para crear una nueva contraseña.',
        'Enviar',
      ),
      _ => ('Confirmar correo', 'Marcaremos el correo de $nombre como confirmado para que pueda entrar.', 'Confirmar'),
    };
    if (!await _confirmar(titulo, msg, boton)) return;
    setState(() => _accionEnCurso = accion);
    try {
      final r = await Data.soporteAccion(accion, _id);
      _cambio = true;
      if (!mounted) return;
      switch (accion) {
        case 'reiniciar_clave':
          final clave = r['clave_temporal']?.toString();
          if (clave != null) await _mostrarClave(clave);
        case 'enviar_recuperacion':
          showInfo(context, 'Correo de recuperación enviado.');
        default:
          setState(() => _u['confirmado'] = true);
          showInfo(context, 'Correo confirmado.');
      }
      if (mounted) setState(() => _bitacora = Data.bitacoraSoporte(_id));
    } catch (e) {
      if (mounted) showInfo(context, _errorSoporte(e));
    } finally {
      if (mounted) setState(() => _accionEnCurso = null);
    }
  }

  Future<void> _mostrarClave(String clave) {
    final telefono = (_u['telefono'] as String?)?.trim();
    final nombre = (_u['nombre'] as String?)?.trim();
    final mensaje =
        'Hola${nombre == null || nombre.isEmpty ? '' : ' $nombre'}, te escribe el equipo de soporte de '
        'FAUNAZULIA. Tu contraseña temporal es: $clave\n\nEntra a la app con tu correo ${_u['email'] ?? ''} '
        'y cámbiala de inmediato en Ajustes.';
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final t = Theme.of(ctx).textTheme;
        return AlertDialog(
          title: const Text('Contraseña temporal', textAlign: TextAlign.center),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  decoration: BoxDecoration(
                    color: Fz.azul50,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Fz.tinta, width: Fz.borde),
                  ),
                  child: SelectableText(
                    clave,
                    textAlign: TextAlign.center,
                    style: Fz.display(30, color: Fz.tinta).copyWith(letterSpacing: 1.5),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: clave));
                    if (ctx.mounted) showInfo(ctx, 'Contraseña copiada');
                  },
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copiar contraseña'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Envíasela por WhatsApp y pídele cambiarla en Ajustes.',
                  textAlign: TextAlign.center,
                  style: t.titleSmall,
                ),
                const SizedBox(height: 4),
                Text('Por seguridad no se volverá a mostrar.', textAlign: TextAlign.center, style: t.bodySmall),
                const SizedBox(height: 12),
                PopButton(
                  label: 'Enviar por WhatsApp',
                  icon: Icons.chat_rounded,
                  onPressed: telefono == null || telefono.isEmpty
                      ? null
                      : () async {
                          final ok = await abrirEnlace(
                            'https://wa.me/${_waNumero(telefono)}?text=${Uri.encodeComponent(mensaje)}',
                          );
                          if (!ok && ctx.mounted) showInfo(ctx, 'No pudimos abrir WhatsApp.');
                        },
                ),
                if (telefono == null || telefono.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Esta cuenta no tiene teléfono registrado.', textAlign: TextAlign.center, style: t.bodySmall),
                ],
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Listo'))],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final nombre = (_u['nombre'] as String?)?.trim();
    final confirmado = _u['confirmado'] != false;
    final ocupado = _accionEnCurso != null;
    var i = 0;
    Widget item(Widget w) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FadeSlideIn(index: i++, child: w),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_cambio);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Cuenta'),
          leading: BackButton(onPressed: () => Navigator.of(context).pop(_cambio)),
        ),
        body: RefreshIndicator(
          onRefresh: _refrescar,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                item(
                  FzHero(
                    title: nombre == null || nombre.isEmpty ? 'Sin nombre' : nombre,
                    subtitle: _u['email'] as String?,
                    leading: FzAvatar(
                      url: Data.fotoUrl(_u['avatar_path'] as String?),
                      text: iniciales(nombre),
                      size: 84,
                    ),
                    child: Column(
                      children: [
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            StatusPill(_rolTexto(_u['rol'] as String?), icon: Icons.person_rounded, color: Fz.azul100),
                            confirmado
                                ? const StatusPill(
                                    'Correo confirmado',
                                    icon: Icons.mark_email_read_rounded,
                                    color: Fz.azul50,
                                  )
                                : const StatusPill(
                                    'Correo sin confirmar',
                                    icon: Icons.mark_email_unread_rounded,
                                    color: Fz.frambuesaSuave,
                                    dashed: true,
                                  ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Registro: ${_fechaHora(_u['created_at'] as String?)}',
                          textAlign: TextAlign.center,
                          style: t.bodySmall?.copyWith(color: Fz.azul50),
                        ),
                        Text(
                          _u['ultimo_acceso'] == null
                              ? 'Nunca ha entrado'
                              : 'Último acceso: ${_fechaHora(_u['ultimo_acceso'] as String?)}',
                          textAlign: TextAlign.center,
                          style: t.bodySmall?.copyWith(color: Fz.azul50),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_esAdmin)
                  item(
                    PopCard(
                      color: Fz.azul100,
                      child: Row(
                        children: [
                          const Icon(Icons.shield_rounded, color: Fz.azul),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Es una cuenta de administración: soporte no puede modificarla. Solo puedes consultarla.',
                              style: t.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                item(
                  _Seccion(
                    titulo: 'Datos de la cuenta',
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _nombre,
                            enabled: !_esAdmin,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Nombre',
                              prefixIcon: Icon(Icons.person_rounded),
                            ),
                            validator: (v) => (v == null || v.trim().length < 2) ? 'Escribe el nombre.' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _cedula,
                            enabled: !_esAdmin,
                            decoration: const InputDecoration(
                              labelText: 'Cédula',
                              prefixIcon: Icon(Icons.badge_rounded),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _telefono,
                            enabled: !_esAdmin,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Teléfono',
                              hintText: '04141234567',
                              prefixIcon: Icon(Icons.phone_rounded),
                            ),
                            validator: (v) {
                              final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                              if (s.isEmpty) return null;
                              return RegExp(r'^0\d{10}$').hasMatch(s)
                                  ? null
                                  : 'Escribe 11 dígitos, por ejemplo 04141234567.';
                            },
                          ),
                          const SizedBox(height: 14),
                          PopButton.tonal(
                            label: 'Guardar datos',
                            icon: Icons.save_rounded,
                            loading: _guardando,
                            onPressed: _esAdmin || ocupado ? null : _guardar,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                item(
                  _Seccion(
                    titulo: 'Acceso',
                    color: Fz.azul50,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        PopButton(
                          label: 'Reiniciar contraseña',
                          icon: Icons.lock_reset_rounded,
                          loading: _accionEnCurso == 'reiniciar_clave',
                          onPressed: _esAdmin || ocupado ? null : () => _accion('reiniciar_clave'),
                        ),
                        const SizedBox(height: 10),
                        PopButton.tonal(
                          label: 'Enviar correo de recuperación',
                          icon: Icons.forward_to_inbox_rounded,
                          loading: _accionEnCurso == 'enviar_recuperacion',
                          onPressed: _esAdmin || ocupado ? null : () => _accion('enviar_recuperacion'),
                        ),
                        if (!confirmado) ...[
                          const SizedBox(height: 10),
                          PopButton.tonal(
                            label: 'Confirmar correo',
                            icon: Icons.mark_email_read_rounded,
                            loading: _accionEnCurso == 'confirmar_correo',
                            onPressed: _esAdmin || ocupado ? null : () => _accion('confirmar_correo'),
                          ),
                        ],
                        const SizedBox(height: 8),
                        Text(
                          'Soporte no puede cambiar roles. Para eso, escribe a la administración.',
                          textAlign: TextAlign.center,
                          style: t.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                item(
                  _Seccion(
                    titulo: 'Mascotas',
                    child: _Lista(
                      future: _mascotas,
                      vacio: 'Sin mascotas registradas',
                      fila: (m) {
                        final p = Pet(m);
                        return _Fila(
                          leading: FzAvatar(
                            url: p.fotoUrl,
                            text: iniciales(p.nombre),
                            icon: Icons.pets_rounded,
                            size: 40,
                          ),
                          titulo: p.nombre,
                          subtitulo: '${p.descripcion}${p.esterilizada ? ' · Esterilizada' : ''}',
                        );
                      },
                    ),
                  ),
                ),
                item(
                  _Seccion(
                    titulo: 'Inscripciones',
                    color: Fz.azul50,
                    child: _Lista(
                      future: _inscripciones,
                      vacio: 'Sin inscripciones',
                      fila: (m) {
                        final pet = fichaMapa(m['pets']);
                        final jor = fichaMapa(m['jornadas']);
                        final f = DateTime.tryParse((jor['fecha_inicio'] as String?) ?? '');
                        return _Fila(
                          leading: const Icon(Icons.event_rounded, color: Fz.azul),
                          titulo: '${pet['nombre'] ?? 'Mascota'} · ${jor['titulo'] ?? 'Jornada'}',
                          subtitulo: [
                            if (f != null) Money.fecha(f.toLocal()),
                            _estadoInscripcion(m['estado'] as String?),
                          ].join(' · '),
                          extra: m['codigo'] is String ? CodigoCopiable(m['codigo'] as String) : null,
                        );
                      },
                    ),
                  ),
                ),
                item(
                  _Seccion(
                    titulo: 'Pagos',
                    child: _Lista(
                      future: _pagos,
                      vacio: 'Sin pagos registrados',
                      fila: (m) {
                        final jor = m['jornadas'] == null ? null : fichaMapa(m['jornadas']);
                        final concepto =
                            jor?['titulo'] as String? ?? (m['visita_id'] != null ? 'Visita a domicilio' : 'Pago');
                        return _Fila(
                          leading: const Icon(Icons.receipt_long_rounded, color: Fz.azul),
                          titulo: '${Money.usd(m['monto_usd'] as num?)} · $concepto',
                          subtitulo: [
                            m['metodo'] == 'efectivo_divisa' ? 'Efectivo' : 'Pago Móvil',
                            _estadoPago(m['estado'] as String?),
                            if (m['referencia'] != null) 'Ref. ${m['referencia']}',
                            if (m['created_at'] != null)
                              Money.fecha(DateTime.parse(m['created_at'] as String).toLocal()),
                          ].join(' · '),
                        );
                      },
                    ),
                  ),
                ),
                item(
                  _Seccion(
                    titulo: 'Bitácora de soporte',
                    color: Fz.azul50,
                    child: _Lista(
                      future: _bitacora,
                      vacio: 'Sin acciones de soporte en esta cuenta',
                      fila: (m) {
                        final actor = fichaMapa(m['actor'])['nombre'] as String?;
                        final detalle = m['nota'];
                        return _Fila(
                          leading: const Icon(Icons.history_rounded, color: Fz.azul),
                          titulo: _accionTexto(m['accion'] as String?),
                          subtitulo: [
                            _fechaHora(m['created_at'] as String?),
                            if (actor != null) 'por $actor',
                            if (detalle is String && detalle.isNotEmpty) detalle,
                          ].join(' · '),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _accionTexto(String? a) => switch (a) {
    'reiniciar_clave' => 'Contraseña reiniciada',
    'enviar_recuperacion' => 'Correo de recuperación enviado',
    'confirmar_correo' => 'Correo confirmado',
    'editar_perfil' => 'Datos editados',
    null => 'Acción',
    _ => a.replaceAll('_', ' '),
  };

  static String _estadoInscripcion(String? e) => switch (e) {
    'precio_por_confirmar' => 'Precio por confirmar',
    'pendiente_pago' => 'Falta pagar',
    'pago_en_revision' => 'Pago en revisión',
    'confirmada' => 'Confirmada',
    'atendida' => 'Atendida',
    'cancelada' => 'Cancelada',
    _ => e ?? '—',
  };

  static String _estadoPago(String? e) => switch (e) {
    'pendiente' => 'Por verificar',
    'verificado' => 'Verificado',
    'rechazado' => 'Rechazado',
    'anulado' => 'Anulado',
    _ => e ?? '—',
  };
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child, this.color = Fz.tarjeta});
  final String titulo;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => PopCard(
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        child,
      ],
    ),
  );
}

/// Lista de solo lectura dentro de una sección (cargando / vacío / error).
class _Lista extends StatelessWidget {
  const _Lista({required this.future, required this.vacio, required this.fila});
  final Future<List<Map<String, dynamic>>> future;
  final String vacio;
  final Widget Function(Map<String, dynamic>) fila;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'No pudimos cargar esta sección: ${friendlyError(snap.error!)}',
            textAlign: TextAlign.center,
            style: t.bodySmall,
          );
        }
        final rows = snap.data;
        if (rows == null) {
          return const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: LinearProgressIndicator());
        }
        if (rows.isEmpty) {
          return Text(vacio, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Fz.variante));
        }
        return Column(
          children: [
            for (final (i, r) in rows.indexed) ...[if (i > 0) const Divider(height: 14), fila(r)],
          ],
        );
      },
    );
  }
}

class _Fila extends StatelessWidget {
  const _Fila({required this.leading, required this.titulo, required this.subtitulo, this.extra});
  final Widget leading;
  final String titulo;
  final String subtitulo;
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(
      children: [
        SizedBox(width: 40, child: Center(child: leading)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: t.titleSmall),
              if (subtitulo.isNotEmpty) Text(subtitulo, style: t.bodySmall),
              ?extra,
            ],
          ),
        ),
      ],
    );
  }
}
