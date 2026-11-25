import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Acceso: Entrar / Crear cuenta / Recuperar contraseña.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _registro = false;
  bool _enviado = false; // registro hecho, falta confirmar el correo
  String _correoEnviado = '';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [
            Row(children: [
              const FzLogo(size: 52),
              const SizedBox(width: 12),
              Text('FAUNAZULIA', style: Fz.display(26)),
            ]),
            const SizedBox(height: 24),
            Text(_registro ? 'Crear cuenta' : '¡Hola!', style: t.displaySmall),
            const SizedBox(height: 4),
            Text('El mismo cuidado para perros y gatos', style: t.titleLarge?.copyWith(color: Fz.azul)),
            const SizedBox(height: 6),
            Text(
              _registro
                  ? 'Con tu cuenta inscribes a tus mascotas y sigues tus pagos.'
                  : 'Jornadas de esterilización a bajo costo en Maracaibo y San Francisco.',
              style: t.bodyLarge?.copyWith(color: Fz.variante),
            ),
            const SizedBox(height: 20),
            if (!_enviado) ...[
              SegmentedButton<bool>(
                style: SegmentedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  side: const BorderSide(color: Fz.tinta, width: 2),
                  selectedBackgroundColor: Fz.rosa,
                  backgroundColor: Fz.cremaClaro,
                  foregroundColor: Fz.tinta,
                  selectedForegroundColor: Fz.tinta,
                  textStyle: Fz.display(16, w: FontWeight.w700),
                ),
                segments: const [
                  ButtonSegment(value: false, label: Text('Entrar'), icon: Icon(Icons.login_rounded)),
                  ButtonSegment(value: true, label: Text('Crear cuenta'), icon: Icon(Icons.person_add_rounded)),
                ],
                selected: {_registro},
                onSelectionChanged: (s) => setState(() => _registro = s.first),
              ),
              const SizedBox(height: 20),
            ],
            if (_enviado)
              _Confirmacion(
                correo: _correoEnviado,
                onVolver: () => setState(() {
                  _enviado = false;
                  _registro = false;
                }),
              )
            else if (_registro)
              _RegistroForm(onEnviado: (correo) => setState(() {
                    _enviado = true;
                    _correoEnviado = correo;
                  }))
            else
              const _EntrarForm(),
          ],
        ),
      ),
    );
  }
}

final _reCorreo = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]{2,}$');

String? _validarCorreo(String? v) {
  final s = (v ?? '').trim();
  if (s.isEmpty) return 'Escribe tu correo.';
  if (!s.contains('@')) return 'Falta la @. Escríbelo así: nombre@correo.com';
  if (!_reCorreo.hasMatch(s)) return 'Le falta el final. Escríbelo así: nombre@correo.com';
  return null;
}

class _EntrarForm extends StatefulWidget {
  const _EntrarForm();

  @override
  State<_EntrarForm> createState() => _EntrarFormState();
}

class _EntrarFormState extends State<_EntrarForm> {
  final _form = GlobalKey<FormState>();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  bool _ver = false;
  bool _cargando = false;

  @override
  void dispose() {
    _correo.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _cargando = true);
    try {
      await sb.auth.signInWithPassword(email: _correo.text.trim(), password: _clave.text);
      // AuthGate cambia de pantalla al detectar la sesión.
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _olvide() async {
    final ctrl = TextEditingController(text: _correo.text.trim());
    final key = GlobalKey<FormState>();
    final correo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recuperar contraseña'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Te enviaremos un enlace a tu correo para crear una contraseña nueva.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: ctrl,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_rounded)),
              validator: _validarCorreo,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(ctx, ctrl.text.trim());
            },
            child: const Text('Enviar enlace'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (correo == null || !mounted) return;
    try {
      await sb.auth.resetPasswordForEmail(correo);
      if (mounted) showInfo(context, 'Listo. Revisa tu correo $correo para cambiar la contraseña.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Tu correo', prefixIcon: Icon(Icons.mail_rounded)),
            validator: _validarCorreo,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _clave,
            obscureText: !_ver,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onFieldSubmitted: (_) => _entrar(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                icon: Icon(_ver ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _ver = !_ver),
              ),
            ),
            validator: (v) => (v ?? '').isEmpty ? 'Escribe tu contraseña.' : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _olvide, child: const Text('¿Olvidaste tu contraseña?')),
          ),
          const SizedBox(height: 8),
          PopButton(label: 'Entrar', icon: Icons.arrow_forward_rounded, loading: _cargando, onPressed: _entrar),
        ]),
      ),
    );
  }
}

class _RegistroForm extends StatefulWidget {
  const _RegistroForm({required this.onEnviado});
  final ValueChanged<String> onEnviado;

  @override
  State<_RegistroForm> createState() => _RegistroFormState();
}

class _RegistroFormState extends State<_RegistroForm> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController();
  final _cedula = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _clave = TextEditingController();
  String _nac = 'V';
  bool _terminos = false;
  bool _terminosError = false;
  bool _ver = false;
  bool _cargando = false;

  @override
  void dispose() {
    for (final c in [_nombre, _cedula, _telefono, _correo, _clave]) {
      c.dispose();
    }
    super.dispose();
  }

  String get _telefonoNormalizado {
    var d = _telefono.text.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('58') && d.length == 12) d = '0${d.substring(2)}';
    if (d.length == 10 && !d.startsWith('0')) d = '0$d';
    return d;
  }

  Future<void> _crear() async {
    final ok = _form.currentState!.validate();
    setState(() => _terminosError = !_terminos);
    if (!ok || !_terminos) return;
    setState(() => _cargando = true);
    final correo = _correo.text.trim();
    try {
      final res = await sb.auth.signUp(
        email: correo,
        password: _clave.text,
        data: {
          'nombre': _nombre.text.trim().replaceAll(RegExp(r'\s+'), ' '),
          'cedula': '$_nac-${_cedula.text.replaceAll(RegExp(r'\D'), '')}',
          'telefono': _telefonoNormalizado,
        },
      );
      if (res.session == null && mounted) widget.onEnviado(correo);
      // Si hay sesión, AuthGate entra a la app.
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Form(
      key: _form,
      child: AutofillGroup(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          TextFormField(
            controller: _nombre,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            decoration: const InputDecoration(labelText: 'Nombre y apellido', prefixIcon: Icon(Icons.person_rounded)),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return 'Escribe tu nombre y apellido.';
              if (s.split(RegExp(r'\s+')).length < 2) return 'Escribe también tu apellido.';
              return null;
            },
          ),
          const SizedBox(height: 14),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 92,
              child: DropdownButtonFormField<String>(
                initialValue: _nac,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: const [
                  DropdownMenuItem(value: 'V', child: Text('V')),
                  DropdownMenuItem(value: 'E', child: Text('E')),
                ],
                onChanged: (v) => setState(() => _nac = v ?? 'V'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _cedula,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)],
                decoration: const InputDecoration(labelText: 'Cédula', prefixIcon: Icon(Icons.badge_rounded)),
                validator: (v) {
                  final d = (v ?? '').trim();
                  if (d.isEmpty) return 'Escribe tu número de cédula.';
                  if (d.length < 6) return 'La cédula tiene de 6 a 9 números.';
                  return null;
                },
              ),
            ),
          ]),
          const SizedBox(height: 14),
          TextFormField(
            controller: _telefono,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')), LengthLimitingTextInputFormatter(16)],
            decoration: const InputDecoration(
              labelText: 'Teléfono',
              hintText: '0414 555 0123',
              prefixIcon: Icon(Icons.phone_rounded),
              helperText: 'Para avisos de tu cita.',
            ),
            validator: (_) {
              final d = _telefonoNormalizado;
              if (d.isEmpty) return 'Escribe tu teléfono.';
              if (!RegExp(r'^0\d{10}$').hasMatch(d)) return 'Escríbelo con 11 números, así: 0414 555 0123';
              return null;
            },
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Correo electrónico', prefixIcon: Icon(Icons.mail_rounded)),
            validator: _validarCorreo,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _clave,
            obscureText: !_ver,
            autofillHints: const [AutofillHints.newPassword],
            decoration: InputDecoration(
              labelText: 'Contraseña',
              helperText: 'Mínimo 8 caracteres.',
              prefixIcon: const Icon(Icons.lock_rounded),
              suffixIcon: IconButton(
                tooltip: _ver ? 'Ocultar contraseña' : 'Mostrar contraseña',
                icon: Icon(_ver ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _ver = !_ver),
              ),
            ),
            validator: (v) {
              final s = v ?? '';
              if (s.isEmpty) return 'Crea una contraseña.';
              if (s.length < 8) return 'Usa al menos 8 caracteres (llevas ${s.length}).';
              return null;
            },
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() {
              _terminos = !_terminos;
              if (_terminos) _terminosError = false;
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Checkbox(
                  value: _terminos,
                  onChanged: (v) => setState(() {
                    _terminos = v ?? false;
                    if (_terminos) _terminosError = false;
                  }),
                ),
                Expanded(child: Text('Acepto los términos y condiciones y la política de privacidad.', style: t.bodyMedium)),
              ]),
            ),
          ),
          if (_terminosError)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 6),
              child: Row(children: [
                const Icon(Icons.error_rounded, size: 18, color: Fz.frambuesa),
                const SizedBox(width: 6),
                Expanded(
                  child: Text('Para crear la cuenta debes aceptar los términos.',
                      style: t.bodySmall?.copyWith(color: Fz.frambuesa, fontWeight: FontWeight.w700)),
                ),
              ]),
            ),
          const SizedBox(height: 10),
          PopButton(label: 'Crear cuenta', icon: Icons.person_add_rounded, loading: _cargando, onPressed: _crear),
        ]),
      ),
    );
  }
}

class _Confirmacion extends StatelessWidget {
  const _Confirmacion({required this.correo, required this.onVolver});
  final String correo;
  final VoidCallback onVolver;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: Fz.azulPastel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.mark_email_read_rounded, size: 40, color: Fz.tinta),
        const SizedBox(height: 10),
        Text('Revisa tu correo', style: t.headlineSmall),
        const SizedBox(height: 6),
        Text('Te enviamos un enlace a tu correo para confirmar la cuenta.', style: t.bodyLarge),
        const SizedBox(height: 4),
        Text(correo, style: t.titleMedium),
        const SizedBox(height: 8),
        Text('Ábrelo desde este teléfono y luego entra con tu correo y contraseña. Si no lo ves, revisa la carpeta de spam.',
            style: t.bodyMedium),
        const SizedBox(height: 16),
        PopButton.tonal(label: 'Ya confirmé, entrar', icon: Icons.login_rounded, onPressed: onVolver),
      ]),
    );
  }
}
