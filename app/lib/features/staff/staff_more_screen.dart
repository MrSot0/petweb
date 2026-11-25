import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import 'admin_jornadas_screen.dart' show mostrarFijarPrecio, estadoInscripcionTexto;

const _roles = ['propietario', 'cirujano', 'contador', 'admin'];

String _rolTexto(String r) => switch (r) {
      'propietario' => 'Propietario',
      'cirujano' => 'Cirujano',
      'contador' => 'Contador',
      'admin' => 'Administración',
      _ => r,
    };

IconData _rolIcono(String r) => switch (r) {
      'propietario' => Icons.person_rounded,
      'cirujano' => Icons.medical_services_rounded,
      'contador' => Icons.calculate_rounded,
      _ => Icons.admin_panel_settings_rounded,
    };

/// Pestaña "Más" del equipo.
class StaffMoreScreen extends StatelessWidget {
  const StaffMoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final mode = AppMode.of(context);
    final t = Theme.of(context).textTheme;
    final email = sb.auth.currentUser?.email;
    void ir(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

    Widget item(IconData ic, String title, String sub, VoidCallback onTap, {Color color = Fz.cremaClaro}) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: PopCard(
            color: color,
            onTap: onTap,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Fz.azulPastel,
                  shape: BoxShape.circle,
                  border: Border.all(color: Fz.tinta, width: 2),
                ),
                child: Icon(ic, color: Fz.tinta),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: t.titleMedium),
                  Text(sub, style: t.bodySmall),
                ]),
              ),
              const Icon(Icons.chevron_right_rounded),
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Más')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        PopCard(
          color: Fz.rosaSuave,
          child: Row(children: [
            const FzLogo(size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(email ?? 'Equipo', style: t.titleMedium, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final r in mode.roles.where((r) => r != 'propietario'))
                    StatusPill(_rolTexto(r), icon: _rolIcono(r), color: Fz.cremaClaro),
                ]),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        item(Icons.swap_horiz_rounded, 'Cambiar a modo propietario', 'Inscribe a tus mascotas y paga como cualquier propietario',
            mode.toggle),
        if (mode.isAdmin) ...[
          item(Icons.sell_rounded, 'Precios por confirmar', 'Perros de más de 30 kg o braquiocefálicos',
              () => ir(const PreciosPorConfirmarScreen())),
          item(Icons.group_rounded, 'Usuarios y roles', 'Asigna o quita roles por correo', () => ir(const UsuariosScreen())),
          item(Icons.account_balance_wallet_rounded, 'Datos de cobro', 'Pago Móvil y efectivo que ven los propietarios',
              () => ir(const DatosCobroScreen())),
        ],
        const SizedBox(height: 12),
        PopButton.danger(
          label: 'Cerrar sesión',
          icon: Icons.logout_rounded,
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('¿Cerrar sesión?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
                  TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Cerrar sesión')),
                ],
              ),
            );
            if (ok != true) return;
            try {
              await sb.auth.signOut();
            } catch (e) {
              if (context.mounted) showError(context, e);
            }
          },
        ),
      ]),
    );
  }
}

// ======================= Precios por confirmar =======================

class PreciosPorConfirmarScreen extends StatefulWidget {
  const PreciosPorConfirmarScreen({super.key});

  @override
  State<PreciosPorConfirmarScreen> createState() => _PreciosPorConfirmarScreenState();
}

class _PreciosPorConfirmarScreenState extends State<PreciosPorConfirmarScreen> {
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
      final r = await Data.inscripcionesPorConfirmarPrecio();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Precios por confirmar')),
      body: _error != null && items == null
          ? EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar la lista',
              message: friendlyError(_error!),
              action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
            )
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 40),
                          EmptyState(
                            icon: Icons.task_alt_rounded,
                            title: 'Nada por confirmar',
                            message: 'Todas las inscripciones tienen precio.',
                          ),
                        ])
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                          itemCount: items.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
                          itemBuilder: (_, idx) {
                            final i = items[idx];
                            final pet = (i['pets'] as Map?) ?? const {};
                            final prof = (i['profiles'] as Map?) ?? const {};
                            final jor = (i['jornadas'] as Map?) ?? const {};
                            return PopCard(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(
                                  '${pet['nombre'] ?? 'Mascota'}'
                                  '${pet['peso_kg'] != null ? ' · ${pet['peso_kg']} kg' : ''}',
                                  style: t.titleLarge,
                                ),
                                Text(
                                  [
                                    pet['especie'] == 'gato' ? 'Gato' : 'Perro',
                                    if (pet['braquiocefalico'] == true) 'braquiocefálico',
                                    if (i['incluye_kit'] == true) 'con kit',
                                    if (i['incluye_cono'] == true) 'con cono',
                                  ].join(' · '),
                                  style: t.bodyMedium,
                                ),
                                const SizedBox(height: 4),
                                Text('${prof['nombre'] ?? 'Propietario'}'
                                    '${prof['telefono'] != null ? ' · ${prof['telefono']}' : ''}',
                                    style: t.bodySmall),
                                if (jor['titulo'] != null) Text(jor['titulo'] as String, style: t.bodySmall),
                                const SizedBox(height: 8),
                                StatusPill(estadoInscripcionTexto(i['estado'] as String?),
                                    icon: Icons.help_rounded, color: Fz.rosa),
                                if (i['precio_base_usd'] != null) ...[
                                  const SizedBox(height: 6),
                                  Text('Base calculada: ${Money.usd(i['precio_base_usd'] as num)}', style: t.bodySmall),
                                ],
                                const SizedBox(height: 12),
                                PopButton.accent(
                                  label: 'Fijar precio',
                                  icon: Icons.sell_rounded,
                                  onPressed: () async {
                                    if (await mostrarFijarPrecio(context, i)) _load();
                                  },
                                ),
                              ]),
                            );
                          },
                        ),
                ),
    );
  }
}

// ======================= Usuarios y roles =======================

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

  Set<String> _rolesDe(Map<String, dynamic> u) =>
      ((u['user_roles'] as List?) ?? const []).map((r) => (r as Map)['rol'] as String).toSet();

  Future<void> _cambiar(String email, String rol, bool quitar) async {
    try {
      await Data.asignarRol(email, rol, quitar: quitar);
      if (!mounted) return;
      showInfo(context, quitar ? 'Rol ${_rolTexto(rol)} quitado a $email' : 'Rol ${_rolTexto(rol)} asignado a $email');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _porCorreo() async {
    final r = await showModalBottomSheet<(String, String, bool)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Fz.crema,
      builder: (_) => const _RolPorCorreoSheet(),
    );
    if (r != null) await _cambiar(r.$1, r.$2, r.$3);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final me = sb.auth.currentUser?.id;
    final items = _items
        ?.where((u) =>
            _q.isEmpty ||
            '${u['nombre'] ?? ''} ${u['email'] ?? ''} ${u['cedula'] ?? ''}'.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios y roles')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _porCorreo,
        backgroundColor: Fz.rosa,
        foregroundColor: Fz.tinta,
        shape: const StadiumBorder(side: BorderSide(color: Fz.tinta, width: Fz.borde)),
        icon: const Icon(Icons.alternate_email_rounded),
        label: const Text('Rol por correo'),
      ),
      body: _error != null && _items == null
          ? EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar los usuarios',
              message: friendlyError(_error!),
              action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
            )
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
                    TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Buscar por nombre, correo o cédula',
                      ),
                      onChanged: (v) => setState(() => _q = v.trim()),
                    ),
                    const SizedBox(height: 8),
                    Text('Toca un rol para asignarlo o quitarlo. No puedes quitarte el rol de administración a ti mismo.',
                        style: t.bodySmall),
                    const SizedBox(height: 12),
                    if (items.isEmpty) Text('Sin resultados.', style: t.bodyMedium),
                    for (final u in items) ...[
                      PopCard(
                        padding: const EdgeInsets.all(14),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(
                            '${(u['nombre'] as String?)?.isNotEmpty == true ? u['nombre'] : 'Sin nombre'}'
                            '${u['id'] == me ? ' (tú)' : ''}',
                            style: t.titleMedium,
                          ),
                          Text(
                            [u['email'], u['cedula'], u['telefono']].whereType<String>().join(' · '),
                            style: t.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final r in _roles)
                              FilterChip(
                                label: Text(_rolTexto(r)),
                                avatar: _rolesDe(u).contains(r) ? null : Icon(_rolIcono(r), size: 18, color: Fz.tinta),
                                selected: _rolesDe(u).contains(r),
                                onSelected: u['email'] == null
                                    ? null
                                    : (sel) => _confirmar(u['email'] as String, r, !sel),
                              ),
                          ]),
                        ]),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ]),
                ),
    );
  }

  Future<void> _confirmar(String email, String rol, bool quitar) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(quitar ? '¿Quitar rol?' : '¿Asignar rol?'),
        content: Text('${quitar ? 'Quitar' : 'Asignar'} el rol ${_rolTexto(rol)} a $email.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(quitar ? 'Quitar' : 'Asignar')),
        ],
      ),
    );
    if (ok == true) await _cambiar(email, rol, quitar);
  }
}

class _RolPorCorreoSheet extends StatefulWidget {
  const _RolPorCorreoSheet();

  @override
  State<_RolPorCorreoSheet> createState() => _RolPorCorreoSheetState();
}

class _RolPorCorreoSheetState extends State<_RolPorCorreoSheet> {
  final _email = TextEditingController();
  final _key = GlobalKey<FormState>();
  String _rol = 'contador';
  bool _quitar = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_key.currentState!.validate()) {
      Navigator.of(context).pop((_email.text.trim().toLowerCase(), _rol, _quitar));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Form(
        key: _key,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Rol por correo', style: t.headlineSmall),
          const SizedBox(height: 6),
          Text('La persona debe tener una cuenta creada con ese correo.', style: t.bodyMedium),
          const SizedBox(height: 14),
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Correo'),
            validator: (v) =>
                RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch((v ?? '').trim()) ? null : 'Escribe un correo válido',
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final r in _roles)
              ChoiceChip(label: Text(_rolTexto(r)), selected: _rol == r, onSelected: (_) => setState(() => _rol = r)),
          ]),
          const SizedBox(height: 10),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Asignar'), icon: Icon(Icons.add_rounded)),
              ButtonSegment(value: true, label: Text('Quitar'), icon: Icon(Icons.remove_rounded)),
            ],
            selected: {_quitar},
            onSelectionChanged: (s) => setState(() => _quitar = s.first),
          ),
          const SizedBox(height: 16),
          if (_quitar)
            PopButton.danger(label: 'Quitar rol', onPressed: _enviar)
          else
            PopButton(label: 'Asignar rol', onPressed: _enviar),
        ]),
      ),
    );
  }
}

// ======================= Datos de cobro =======================

class DatosCobroScreen extends StatefulWidget {
  const DatosCobroScreen({super.key});

  @override
  State<DatosCobroScreen> createState() => _DatosCobroScreenState();
}

class _DatosCobroScreenState extends State<DatosCobroScreen> {
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
      final r = await Data.datosCobro();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _editar([Map<String, dynamic>? d]) async {
    final r = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DatoCobroFormScreen(dato: d, ordenSiguiente: (_items?.length ?? 0) + 1)),
    );
    if (r == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final items = _items;
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de cobro')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editar(),
        backgroundColor: Fz.rosa,
        foregroundColor: Fz.tinta,
        shape: const StadiumBorder(side: BorderSide(color: Fz.tinta, width: Fz.borde)),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
      body: _error != null && items == null
          ? EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar los datos de cobro',
              message: friendlyError(_error!),
              action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
            )
          : items == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
                    Text('Así ven los propietarios dónde pagar. Solo se muestran los activos.', style: t.bodySmall),
                    const SizedBox(height: 12),
                    if (items.isEmpty)
                      const EmptyState(
                        icon: Icons.account_balance_rounded,
                        title: 'Sin datos de cobro',
                        message: 'Agrega un Pago Móvil o instrucciones de efectivo.',
                      ),
                    for (final d in items) ...[
                      Stack(children: [
                        DatoCobroPreview(dato: d, onTap: () => _editar(d)),
                        Positioned(
                          right: 12,
                          top: 12,
                          child: d['activo'] == true
                              ? const StatusPill('Activo', icon: Icons.visibility_rounded, color: Fz.azulPastel)
                              : const StatusPill('Inactivo',
                                  icon: Icons.visibility_off_rounded, color: Fz.cremaClaro, dashed: true),
                        ),
                      ]),
                      const SizedBox(height: 14),
                    ],
                  ]),
                ),
    );
  }
}

/// Vista previa de un dato de cobro tal como lo ve el propietario.
class DatoCobroPreview extends StatelessWidget {
  const DatoCobroPreview({super.key, required this.dato, this.onTap});
  final Map<String, dynamic> dato;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pm = dato['tipo'] == 'pago_movil';
    Widget fila(String k, String? v) => (v == null || v.isEmpty)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              SizedBox(width: 90, child: Text(k, style: t.bodySmall)),
              Expanded(child: Text(v, style: t.titleMedium)),
            ]),
          );
    return PopCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(pm ? Icons.account_balance_rounded : Icons.payments_rounded, color: Fz.azul),
          const SizedBox(width: 8),
          Text(pm ? 'Pago Móvil' : 'Efectivo en divisas', style: t.titleLarge),
        ]),
        const SizedBox(height: 4),
        if (pm) ...[
          fila('Banco', dato['banco'] as String?),
          fila('Teléfono', dato['telefono'] as String?),
          fila('Cédula/RIF', dato['cedula_rif'] as String?),
          fila('Titular', dato['titular'] as String?),
        ],
        if ((dato['instrucciones'] as String?)?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(dato['instrucciones'] as String, style: t.bodyMedium),
          ),
      ]),
    );
  }
}

class DatoCobroFormScreen extends StatefulWidget {
  const DatoCobroFormScreen({super.key, this.dato, this.ordenSiguiente = 1});
  final Map<String, dynamic>? dato;
  final int ordenSiguiente;

  @override
  State<DatoCobroFormScreen> createState() => _DatoCobroFormScreenState();
}

class _DatoCobroFormScreenState extends State<DatoCobroFormScreen> {
  static final _telRe = RegExp(r'^0(412|414|416|422|424|426)\d{7}$');
  final _key = GlobalKey<FormState>();
  late String _tipo;
  late bool _activo;
  late final TextEditingController _banco, _tel, _ced, _tit, _inst;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dato ?? const {};
    _tipo = (d['tipo'] as String?) ?? 'pago_movil';
    _activo = (d['activo'] as bool?) ?? true;
    _banco = TextEditingController(text: d['banco'] as String? ?? '');
    _tel = TextEditingController(text: d['telefono'] as String? ?? '');
    _ced = TextEditingController(text: d['cedula_rif'] as String? ?? '');
    _tit = TextEditingController(text: d['titular'] as String? ?? '');
    _inst = TextEditingController(text: d['instrucciones'] as String? ?? '');
  }

  @override
  void dispose() {
    for (final c in [_banco, _tel, _ced, _tit, _inst]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _datos {
    String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final pm = _tipo == 'pago_movil';
    return {
      'tipo': _tipo,
      'banco': pm ? v(_banco) : null,
      'telefono': pm ? v(_tel)?.replaceAll(RegExp(r'[\s-]'), '') : null,
      'cedula_rif': pm ? v(_ced)?.toUpperCase() : null,
      'titular': pm ? v(_tit) : null,
      'instrucciones': v(_inst),
      'activo': _activo,
    };
  }

  Future<void> _guardar() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final datos = _datos;
      if (widget.dato == null) datos['orden'] = widget.ordenSiguiente;
      await Data.guardarDatoCobro(datos, id: (widget.dato?['id'] as num?)?.toInt());
      if (!mounted) return;
      showInfo(context, 'Datos de cobro guardados');
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
    final pm = _tipo == 'pago_movil';
    const gap = SizedBox(height: 14);
    String? req(String? v) => (v ?? '').trim().isEmpty ? 'Este campo es obligatorio' : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.dato == null ? 'Nuevo dato de cobro' : 'Editar dato de cobro')),
      body: Form(
        key: _key,
        onChanged: () => setState(() {}),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Text('Tipo', style: t.titleSmall),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
              avatar: pm ? null : const Icon(Icons.account_balance_rounded, size: 18, color: Fz.tinta),
              label: const Text('Pago Móvil'),
              selected: pm,
              onSelected: (_) => setState(() => _tipo = 'pago_movil'),
            ),
            ChoiceChip(
              avatar: !pm ? null : const Icon(Icons.payments_rounded, size: 18, color: Fz.tinta),
              label: const Text('Efectivo en divisas'),
              selected: !pm,
              onSelected: (_) => setState(() => _tipo = 'efectivo_divisa'),
            ),
          ]),
          gap,
          if (pm) ...[
            TextFormField(
              controller: _banco,
              decoration: const InputDecoration(labelText: 'Banco', hintText: '0102 Banco de Venezuela'),
              validator: req,
            ),
            gap,
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono', hintText: '04141234567'),
              validator: (v) => _telRe.hasMatch((v ?? '').replaceAll(RegExp(r'[\s-]'), ''))
                  ? null
                  : 'Teléfono no válido (ej. 04141234567)',
            ),
            gap,
            TextFormField(
              controller: _ced,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Cédula o RIF', hintText: 'J-12345678-9'),
              validator: (v) =>
                  RegExp(r'^[VEJGPvejgp]-?\d{5,9}(-?\d)?$').hasMatch((v ?? '').trim()) ? null : 'Ej. V-12345678 o J-12345678-9',
            ),
            gap,
            TextFormField(
              controller: _tit,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Titular'),
              validator: req,
            ),
            gap,
          ],
          TextFormField(
            controller: _inst,
            maxLines: 4,
            minLines: 2,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: pm ? 'Instrucciones (opcional)' : 'Instrucciones',
              hintText: pm ? null : 'Paga en efectivo el día de la jornada en la mesa de registro.',
            ),
            validator: pm ? null : req,
          ),
          PopCard(
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SwitchListTile(
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
              title: Text('Activo', style: t.titleMedium),
              subtitle: Text(_activo ? 'Los propietarios lo ven al pagar' : 'Oculto para los propietarios',
                  style: t.bodySmall),
            ),
          ),
          const SectionTitle('Vista previa'),
          Text('Así lo verá el propietario:', style: t.bodySmall),
          const SizedBox(height: 8),
          DatoCobroPreview(dato: _datos),
          const SizedBox(height: 24),
          PopButton(
            label: 'Guardar',
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving ? null : _guardar,
          ),
        ]),
      ),
    );
  }
}
