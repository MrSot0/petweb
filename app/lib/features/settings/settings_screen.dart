import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show UserAttributes;

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/notificaciones.dart';
import '../../core/theme.dart';
import '../../core/webp.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import '../owner/precios_screen.dart';
import '../staff/honorarios_admin_screen.dart';
import '../staff/servicios_domicilio_screen.dart';
import '../staff/tasa_screen.dart';
import 'datos_cobro_screen.dart';
import 'fijar_precio.dart';
import 'notificaciones_screen.dart';
import 'usuarios_screen.dart';

final _telRe = RegExp(r'^0(412|414|416|422|424|426)\d{7}$');

/// Texto visible de un rol.
String rolTexto(String? r) => switch (r) {
      'cirujano' => 'Cirujano',
      'contador' => 'Contador',
      'admin' => 'Administración',
      'soporte' => 'Soporte',
      _ => 'Propietario',
    };

IconData rolIcono(String? r) => switch (r) {
      'cirujano' => Icons.medical_services_rounded,
      'contador' => Icons.calculate_rounded,
      'admin' => Icons.admin_panel_settings_rounded,
      'soporte' => Icons.support_agent_rounded,
      _ => Icons.pets_rounded,
    };

/// Ajustes generales para todas las cuentas (propietario, cirujano, contador, administración y soporte).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Preferencia persistida en el teléfono (Notificaciones.activas / setActivas).
  bool _notificaciones = true;

  Map<String, dynamic>? _perfil;
  Object? _error;
  bool _subiendo = false;

  @override
  void initState() {
    super.initState();
    _load();
    Notificaciones.activas().then((v) {
      if (mounted) setState(() => _notificaciones = v);
    });
  }

  Future<void> _setNotificaciones(bool v) async {
    setState(() => _notificaciones = v);
    try {
      await Notificaciones.setActivas(v); // al activar, pide permiso (Android 13+)
      if (mounted) {
        showInfo(context, v ? 'Notificaciones activadas' : 'Notificaciones desactivadas. Igual las verás en la bandeja.');
      }
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _copiarSoporte() async {
    await Clipboard.setData(const ClipboardData(text: Data.whatsappSoporte));
    if (mounted) showInfo(context, 'Número copiado');
  }

  Future<void> _abrirSoporte() async {
    try {
      final ok = await abrirEnlace(Data.whatsappSoporteUrl);
      if (!ok && mounted) showInfo(context, 'No pudimos abrir WhatsApp. Escribe al 0414-625-0848.');
    } catch (_) {
      if (mounted) showInfo(context, 'No pudimos abrir WhatsApp. Escribe al 0414-625-0848.');
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final p = await Data.miPerfil();
      if (mounted) setState(() => _perfil = p ?? {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _ir(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));

  // ---------- Foto de perfil ----------
  Future<void> _cambiarFoto() async {
    final camara = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Foto de perfil', textAlign: TextAlign.center, style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 14),
            PopButton(label: 'Tomar foto', icon: Icons.photo_camera_rounded, onPressed: () => Navigator.pop(c, true)),
            const SizedBox(height: 12),
            PopButton.tonal(
                label: 'Elegir de la galería', icon: Icons.photo_library_rounded, onPressed: () => Navigator.pop(c, false)),
          ]),
        ),
      ),
    );
    if (camara == null) return;
    try {
      final x = await WebpPipeline.elegir(camara: camara);
      if (x == null) return;
      setState(() => _subiendo = true);
      final path = await Data.subirFoto(x, carpeta: 'avatares');
      await Data.actualizarFotoPerfil(path);
      if (!mounted) return;
      showInfo(context, 'Foto actualizada');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _subiendo = false);
    }
  }

  // ---------- Mi cuenta ----------
  Future<void> _editarDatos() async {
    final p = _perfil ?? {};
    final nombre = TextEditingController(text: p['nombre'] as String? ?? '');
    final cedula = TextEditingController(text: p['cedula'] as String? ?? '');
    final tel = TextEditingController(text: p['telefono'] as String? ?? '');
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Mis datos', textAlign: TextAlign.center),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nombre,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre y apellido', prefixIcon: Icon(Icons.person_rounded)),
                validator: (v) => (v ?? '').trim().length < 3 ? 'Escribe tu nombre' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: cedula,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Cédula', hintText: 'V-12345678', prefixIcon: Icon(Icons.badge_rounded)),
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return null;
                  return RegExp(r'^[VEve]-?\d{6,9}$').hasMatch(s) ? null : 'Escríbela así: V-12345678';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: tel,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Teléfono', hintText: '04141234567', prefixIcon: Icon(Icons.phone_rounded)),
                validator: (v) {
                  final s = (v ?? '').replaceAll(RegExp(r'[\s-]'), '');
                  if (s.isEmpty) return null;
                  return _telRe.hasMatch(s) ? null : 'Escribe un teléfono válido, por ejemplo 04141234567';
                },
              ),
            ]),
          ),
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
    if (ok == true) {
      String? norm(String s) => s.trim().isEmpty ? null : s.trim();
      var ced = norm(cedula.text)?.toUpperCase();
      if (ced != null && !ced.contains('-')) ced = '${ced[0]}-${ced.substring(1)}';
      try {
        await Data.actualizarPerfil({
          'nombre': nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          'cedula': ced,
          'telefono': norm(tel.text.replaceAll(RegExp(r'[\s-]'), '')),
        });
        if (mounted) {
          showInfo(context, 'Datos guardados');
          _load();
        }
      } catch (e) {
        if (mounted) showError(context, e);
      }
    }
    nombre.dispose();
    cedula.dispose();
    tel.dispose();
  }

  Future<void> _cambiarClave() async {
    final clave = TextEditingController();
    final clave2 = TextEditingController();
    final key = GlobalKey<FormState>();
    var ver = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('Cambiar contraseña', textAlign: TextAlign.center),
          content: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: clave,
                obscureText: !ver,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: 'Contraseña nueva',
                  helperText: 'Mínimo 8 caracteres.',
                  prefixIcon: const Icon(Icons.lock_rounded),
                  suffixIcon: IconButton(
                    tooltip: ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                    icon: Icon(ver ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                    onPressed: () => setD(() => ver = !ver),
                  ),
                ),
                validator: (v) => (v ?? '').length < 8 ? 'Usa al menos 8 caracteres.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: clave2,
                obscureText: !ver,
                decoration: const InputDecoration(labelText: 'Repite la contraseña', prefixIcon: Icon(Icons.lock_reset_rounded)),
                validator: (v) => v != clave.text ? 'Las contraseñas no coinciden.' : null,
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(c, true);
              },
              child: const Text('Cambiar'),
            ),
          ],
        ),
      ),
    );
    final nueva = clave.text;
    clave.dispose();
    clave2.dispose();
    if (ok != true) return;
    try {
      await sb.auth.updateUser(UserAttributes(password: nueva));
      if (mounted) showInfo(context, 'Contraseña cambiada. Úsala la próxima vez que entres.');
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      showInfo(
        context,
        s.contains('same_password') || s.contains('should be different')
            ? 'La contraseña nueva debe ser distinta de la actual.'
            : friendlyError(e),
      );
    }
  }

  Future<void> _cerrarSesion() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Cerrar sesión?', textAlign: TextAlign.center),
        content: const Text('Tendrás que volver a entrar con tu correo y contraseña.', textAlign: TextAlign.center),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Fz.frambuesa),
            child: const Text('Sí, cerrar sesión'),
          ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajustes'),
        centerTitle: true,
        actions: const [CampanaNotificaciones(), SizedBox(width: 8)],
      ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null && _perfil == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tus ajustes',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (_perfil == null) return const Center(child: CircularProgressIndicator());

    final t = Theme.of(context).textTheme;
    final mode = AppMode.of(context);
    final p = _perfil!;
    final nombre = (p['nombre'] as String?)?.trim() ?? '';
    final email = (p['email'] as String?) ?? sb.auth.currentUser?.email ?? '';
    final foto = Data.fotoUrl(p['avatar_path'] as String?);
    var i = 0;
    Widget anim(Widget w) => FadeSlideIn(index: i++, child: w);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          anim(FzHero(
            title: nombre.isEmpty ? 'Sin nombre' : nombre,
            subtitle: email,
            leading: Semantics(
              button: true,
              label: 'Cambiar foto de perfil',
              child: GestureDetector(
                onTap: _subiendo ? null : _cambiarFoto,
                child: Stack(clipBehavior: Clip.none, children: [
                  FzAvatar(url: foto, text: iniciales(nombre), size: 104, color: Fz.azul100),
                  if (_subiendo)
                    const Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x880E1C3A), shape: BoxShape.circle),
                        child: Center(child: CircularProgressIndicator(color: Fz.tarjeta)),
                      ),
                    ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Fz.tarjeta,
                        shape: BoxShape.circle,
                        border: Border.all(color: Fz.tinta, width: Fz.borde),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, size: 20, color: Fz.azul),
                    ),
                  ),
                ]),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Fz.tarjeta,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Fz.tinta, width: Fz.borde),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(rolIcono(mode.rol), size: 18, color: Fz.azul),
                const SizedBox(width: 6),
                Text(rolTexto(mode.rol), style: t.titleSmall?.copyWith(color: Fz.azul900)),
              ]),
            ),
          )),

          // ---------- Mi cuenta ----------
          const _Titulo('Mi cuenta'),
          anim(_Grupo(children: [
            _Item(
              icon: Icons.edit_rounded,
              title: 'Nombre, cédula y teléfono',
              subtitle: [
                (p['cedula'] as String?) ?? 'Cédula sin indicar',
                (p['telefono'] as String?) ?? 'Teléfono sin indicar',
              ].join(' · '),
              onTap: _editarDatos,
            ),
            _Item(icon: Icons.lock_rounded, title: 'Cambiar contraseña', onTap: _cambiarClave),
            _Item(
              icon: Icons.mail_rounded,
              title: 'Correo',
              subtitle: '$email\nNo se puede cambiar desde la app.',
            ),
          ])),

          // ---------- Modo ----------
          if (mode.canStaff) ...[
            const _Titulo('Modo de la app'),
            anim(PopCard(
              color: Fz.azul50,
              child: Column(children: [
                Icon(mode.staff ? Icons.groups_rounded : Icons.pets_rounded, size: 34, color: Fz.azul),
                const SizedBox(height: 6),
                Text(
                  mode.staff ? 'Estás en modo equipo' : 'Estás en modo propietario',
                  textAlign: TextAlign.center,
                  style: t.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  mode.staff
                      ? 'En modo propietario ves tus mascotas, te inscribes en jornadas y pagas como cualquier persona.'
                      : 'En modo equipo vuelves a tus herramientas de ${rolTexto(mode.rol).toLowerCase()}: '
                          '${mode.isCirujano ? 'jornadas, visitas y honorarios' : mode.isSoporte ? 'usuarios y soporte' : 'pagos, jornadas, citas y escaneo'}.',
                  textAlign: TextAlign.center,
                  style: t.bodyMedium?.copyWith(color: Fz.variante),
                ),
                const SizedBox(height: 14),
                PopButton(
                  label: mode.staff ? 'Usar modo propietario' : 'Usar modo equipo',
                  icon: Icons.swap_horiz_rounded,
                  onPressed: mode.toggle,
                ),
              ]),
            )),
          ],

          // ---------- Gestión (admin y contador) ----------
          if (mode.isAdmin || mode.isContador) ...[
            const _Titulo('Gestión'),
            anim(_Grupo(children: [
              _Item(
                icon: Icons.currency_exchange_rounded,
                title: 'Tasa del día',
                subtitle: 'Euro BCV para el equivalente en bolívares',
                onTap: () => _ir(const TasaScreen()),
              ),
              _Item(
                icon: Icons.medical_services_rounded,
                title: 'Honorarios de cirujanos',
                subtitle: 'Pendientes, pagados y tarifas',
                onTap: () => _ir(const HonorariosAdminScreen()),
              ),
              if (mode.isAdmin)
                _Item(
                  icon: Icons.home_work_rounded,
                  title: 'Servicios a domicilio',
                  subtitle: 'Servicios, duración y precios de las visitas',
                  onTap: () => _ir(const ServiciosDomicilioScreen()),
                ),
            ])),
          ],

          // ---------- Administración ----------
          if (mode.isAdmin) ...[
            const _Titulo('Administración'),
            anim(_Grupo(children: [
              _Item(
                icon: Icons.group_rounded,
                title: 'Usuarios y roles',
                subtitle: 'Asigna un rol de equipo a cada persona',
                onTap: () => _ir(const UsuariosScreen()),
              ),
              _Item(
                icon: Icons.account_balance_wallet_rounded,
                title: 'Datos de cobro',
                subtitle: 'Pago Móvil y efectivo que ven los propietarios',
                onTap: () => _ir(const DatosCobroScreen()),
              ),
              _Item(
                icon: Icons.sell_rounded,
                title: 'Precios por confirmar',
                subtitle: 'Perros de más de 30 kg o braquiocefálicos',
                onTap: () => _ir(const PreciosPorConfirmarScreen()),
              ),
            ])),
          ],

          // ---------- Preferencias ----------
          const _Titulo('Preferencias'),
          anim(_Grupo(children: [
            SwitchListTile(
              secondary: Icon(
                  _notificaciones ? Icons.notifications_active_rounded : Icons.notifications_off_rounded,
                  color: Fz.azul),
              value: _notificaciones,
              onChanged: _setNotificaciones,
              title: const Text('Notificaciones en el teléfono', textAlign: TextAlign.center),
              subtitle: Text(
                _notificaciones
                    ? 'Activadas: pagos, citas, jornadas y mascotas.'
                    : 'Desactivadas. Igual quedan en la bandeja.',
                textAlign: TextAlign.center,
              ),
            ),
            ValueListenableBuilder<int>(
              valueListenable: Notificaciones.noLeidas,
              builder: (_, n, _) => _Item(
                icon: Icons.inbox_rounded,
                title: 'Bandeja de notificaciones',
                subtitle: n == 0 ? 'Estás al día' : (n == 1 ? '1 sin leer' : '$n sin leer'),
                onTap: () => _ir(const NotificacionesScreen()),
              ),
            ),
          ])),

          // ---------- Ayuda ----------
          const _Titulo('Ayuda'),
          anim(_Grupo(children: [
            const _Faq(
              icon: Icons.sell_rounded,
              q: '¿Cuánto cuesta?',
              a: 'El precio depende de la especie, el sexo y el peso. Se cobra en dólares y te mostramos el equivalente '
                  'en bolívares con la tasa del euro BCV. Perros de más de 30 kg o braquiocefálicos tienen precio por '
                  'confirmar: la administración lo fija antes de que pagues.',
            ),
            const _Faq(
              icon: Icons.medical_services_rounded,
              q: '¿Qué es el kit recomendado?',
              a: 'Es el kit post-operatorio con lo necesario para la recuperación en casa (+\$5 gato, +\$7 perro). '
                  'Es opcional, pero lo recomendamos. El cono también es opcional.',
            ),
            const _Faq(
              icon: Icons.payments_rounded,
              q: '¿Cómo pago y cuándo se verifica?',
              a: 'Paga por Pago Móvil (con número de referencia y foto del comprobante) o en efectivo en divisas. '
                  'El contador o la administración revisa el pago y, al verificarlo, tu cita queda confirmada.',
            ),
            _Item(
              icon: Icons.list_alt_rounded,
              title: 'Ver lista de precios',
              onTap: () => _ir(const PreciosScreen()),
            ),
            const _Item(icon: Icons.info_outline_rounded, title: 'Versión', subtitle: 'Prototipo 0.3'),
          ])),
          const SizedBox(height: 14),
          anim(PopCard(
            color: Fz.azul50,
            child: Column(children: [
              const Icon(Icons.support_agent_rounded, size: 34, color: Fz.azul),
              const SizedBox(height: 6),
              Text('WhatsApp de soporte', textAlign: TextAlign.center, style: t.titleLarge),
              const SizedBox(height: 4),
              Text('¿Dudas con tu cuenta, un pago o una cita? Escríbenos.',
                  textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Fz.variante)),
              const SizedBox(height: 8),
              SelectableText('0414-625-0848', textAlign: TextAlign.center, style: Fz.display(22, color: Fz.azul900)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: PopButton.tonal(label: 'Copiar', icon: Icons.copy_rounded, onPressed: _copiarSoporte),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: PopButton(label: 'Abrir WhatsApp', icon: Icons.chat_rounded, onPressed: _abrirSoporte),
                ),
              ]),
            ]),
          )),

          const SizedBox(height: 22),
          anim(PopButton.danger(label: 'Cerrar sesión', icon: Icons.logout_rounded, onPressed: _cerrarSesion)),
          const SizedBox(height: 16),
          Text('FAUNAZULIA · Prototipo 0.3', textAlign: TextAlign.center, style: t.bodySmall),
        ],
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      );
}

/// Tarjeta que agrupa filas separadas por divisores.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => PopCard(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(children: [
          for (var k = 0; k < children.length; k++) ...[
            if (k > 0) const Divider(height: 1, indent: 16, endIndent: 16),
            children[k],
          ],
        ]),
      );
}

class _Item extends StatelessWidget {
  const _Item({required this.icon, required this.title, this.subtitle, this.onTap});
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        minTileHeight: 60,
        leading: Icon(icon, color: Fz.azul),
        title: Text(title, textAlign: TextAlign.center),
        subtitle: subtitle == null ? null : Text(subtitle!, textAlign: TextAlign.center),
        // Hueco simétrico al icono para que el texto quede centrado de verdad.
        trailing: onTap == null
            ? const SizedBox(width: 24)
            : const Icon(Icons.chevron_right_rounded, color: Fz.azul),
        onTap: onTap,
      );
}

class _Faq extends StatelessWidget {
  const _Faq({required this.icon, required this.q, required this.a});
  final IconData icon;
  final String q;
  final String a;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon, color: Fz.azul),
          iconColor: Fz.azul,
          collapsedIconColor: Fz.azul,
          title: Text(q, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          children: [Text(a, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium)],
        ),
      );
}
