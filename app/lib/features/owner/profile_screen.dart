import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import 'precios_screen.dart';

final _telRe = RegExp(r'^0(412|414|416|422|424|426)\d{7}$');

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _perfil;
  Object? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _cargando = true;
    });
    try {
      final p = await Data.miPerfil();
      if (mounted) setState(() => _perfil = p ?? {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _iniciales(String nombre) {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    return (partes.first[0] + (partes.length > 1 ? partes[1][0] : '')).toUpperCase();
  }

  Future<void> _editar() async {
    final nombre = TextEditingController(text: _perfil?['nombre'] as String? ?? '');
    final tel = TextEditingController(text: _perfil?['telefono'] as String? ?? '');
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Editar mis datos'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre y apellido'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe tu nombre' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono', hintText: '04141234567'),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return null;
                return _telRe.hasMatch(s) ? null : 'Escribe un teléfono válido, por ejemplo 04141234567';
              },
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(c, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Data.actualizarPerfil({
        'nombre': nombre.text.trim(),
        'telefono': tel.text.trim().isEmpty ? null : tel.text.trim(),
      });
      if (!mounted) return;
      showInfo(context, 'Datos guardados');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a entrar con tu correo y contraseña.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sí, cerrar sesión')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await sb.auth.signOut();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _ir(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Perfil')), body: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_error != null && _perfil == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tu perfil',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (_cargando && _perfil == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final p = _perfil ?? {};
    final nombre = (p['nombre'] as String?)?.trim() ?? '';
    final email = (p['email'] as String?) ?? sb.auth.currentUser?.email ?? '';
    final mode = AppMode.of(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          PopCard(
            child: Column(children: [
              Row(children: [
                Container(
                  width: 64,
                  height: 64,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Fz.rosa,
                    shape: BoxShape.circle,
                    border: Border.all(color: Fz.tinta, width: Fz.borde),
                  ),
                  child: Text(_iniciales(nombre), style: Fz.display(24)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre.isEmpty ? 'Sin nombre' : nombre, style: t.titleLarge),
                    Text(email, style: t.bodySmall),
                  ]),
                ),
              ]),
              const SizedBox(height: 12),
              _Dato(icon: Icons.badge_rounded, label: 'Cédula', value: (p['cedula'] as String?) ?? 'Sin indicar'),
              _Dato(icon: Icons.phone_rounded, label: 'Teléfono', value: (p['telefono'] as String?) ?? 'Sin indicar'),
              const SizedBox(height: 8),
              PopButton.tonal(label: 'Editar nombre y teléfono', icon: Icons.edit_rounded, onPressed: _editar),
            ]),
          ),
          const SectionTitle('Accesos'),
          _Acceso(
            icon: Icons.event_note_rounded,
            label: 'Mis inscripciones y citas',
            onTap: () => _ir(const _MisInscripcionesScreen()),
          ),
          _Acceso(icon: Icons.sell_rounded, label: 'Precios', onTap: () => _ir(const PreciosScreen())),
          _Acceso(icon: Icons.help_outline_rounded, label: 'Ayuda', onTap: () => _ir(const _AyudaScreen())),
          if (mode.canStaff) ...[
            const SizedBox(height: 8),
            PopButton.accent(label: 'Cambiar a modo equipo', icon: Icons.swap_horiz_rounded, onPressed: mode.toggle),
          ],
          const SizedBox(height: 14),
          PopButton.danger(label: 'Cerrar sesión', icon: Icons.logout_rounded, onPressed: _cerrarSesion),
          const SizedBox(height: 20),
          Text('FAUNAZULIA · Prototipo 1', textAlign: TextAlign.center, style: t.bodySmall),
        ],
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  const _Dato({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 20, color: Fz.variante),
        const SizedBox(width: 10),
        Text('$label: ', style: t.bodySmall),
        Expanded(child: Text(value, style: t.titleSmall)),
      ]),
    );
  }
}

class _Acceso extends StatelessWidget {
  const _Acceso({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: PopCard(
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
            const Icon(Icons.chevron_right_rounded),
          ]),
        ),
      );
}

const _estados = {
  'precio_por_confirmar': ('Precio por confirmar', Icons.help_outline_rounded),
  'pendiente_pago': ('Pendiente de pago', Icons.payments_outlined),
  'pago_en_revision': ('Pago en revisión', Icons.schedule_rounded),
  'confirmada': ('Confirmada', Icons.check_circle_rounded),
  'atendida': ('Atendida', Icons.task_alt_rounded),
  'cancelada': ('Cancelada', Icons.block_rounded),
};

class _MisInscripcionesScreen extends StatefulWidget {
  const _MisInscripcionesScreen();

  @override
  State<_MisInscripcionesScreen> createState() => _MisInscripcionesScreenState();
}

class _MisInscripcionesScreenState extends State<_MisInscripcionesScreen> {
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
      final r = await Data.misInscripciones();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _cancelar(Map<String, dynamic> i) async {
    final nombre = (i['pets'] as Map?)?['nombre'] ?? 'tu mascota';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Cancelar la inscripción?'),
        content: Text('Se liberará el cupo de $nombre en esta jornada.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No, volver')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Fz.frambuesa),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Data.cancelarInscripcion(i['id'] as String);
      if (!mounted) return;
      showInfo(context, 'Inscripción cancelada');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Mis inscripciones')), body: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_error != null && _items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tus inscripciones',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (_items == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    if (_items!.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: const [
          SizedBox(height: 40),
          EmptyState(
            icon: Icons.event_note_rounded,
            title: 'Sin inscripciones',
            message: 'Inscribe a tu mascota desde la pestaña Jornadas.',
          ),
        ]),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _items!.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, k) {
          final i = _items![k];
          final estado = i['estado'] as String;
          final e = _estados[estado] ?? (estado, Icons.info_outline_rounded);
          final j = i['jornadas'] as Map?;
          final fecha = j?['fecha_inicio'] == null ? null : DateTime.tryParse(j!['fecha_inicio'] as String);
          final cancelable = estado == 'pendiente_pago' || estado == 'precio_por_confirmar';
          return PopCard(
            shadow: estado != 'cancelada',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('${(i['pets'] as Map?)?['nombre'] ?? 'Mascota'}', style: t.titleLarge)),
                Text('${i['codigo'] ?? ''}', style: t.titleSmall),
              ]),
              Text('${j?['titulo'] ?? ''}', style: t.bodyMedium),
              if (fecha != null) Text('${Money.fechaLarga(fecha)} · ${j?['sede_nombre'] ?? ''}', style: t.bodySmall),
              const SizedBox(height: 8),
              StatusPill(
                e.$1,
                icon: e.$2,
                color: estado == 'confirmada' || estado == 'atendida' ? Fz.azulPastel : Fz.rosaSuave,
                dashed: estado == 'precio_por_confirmar' || estado == 'pago_en_revision',
              ),
              if (cancelable) ...[
                const SizedBox(height: 10),
                PopButton.danger(
                  label: 'Cancelar inscripción',
                  icon: Icons.close_rounded,
                  onPressed: () => _cancelar(i),
                ),
              ],
            ]),
          );
        },
      ),
    );
  }
}

class _AyudaScreen extends StatelessWidget {
  const _AyudaScreen();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Ayuda')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        PopCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cómo funciona', style: t.titleLarge),
            const SizedBox(height: 8),
            Text(
              '1. Registra a tu mascota con su peso.\n'
              '2. Inscríbela en una jornada.\n'
              '3. Paga por Pago Móvil o en efectivo en divisas.\n'
              '4. El contador o la administración verifica tu pago y tu cita queda confirmada.',
              style: t.bodyMedium,
            ),
          ]),
        ),
        const SizedBox(height: 14),
        PopCard(
          child: Row(children: [
            const Icon(Icons.chat_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('WhatsApp de soporte', style: t.titleMedium),
                Text('Por definir', style: t.bodySmall),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}
