import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/data.dart';
import 'core/theme.dart';
import 'core/widgets.dart';
import 'features/auth/login_screen.dart';
import 'features/owner/owner_shell.dart';
import 'features/staff/staff_shell.dart';
import 'features/surgeon/surgeon_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await Supabase.initialize(url: AppConfig.supabaseUrl, anonKey: AppConfig.supabasePublishableKey);
  runApp(const FaunazuliaApp());
}

class FaunazuliaApp extends StatelessWidget {
  const FaunazuliaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FAUNAZULIA',
      debugShowCheckedModeBanner: false,
      theme: Fz.theme(),
      locale: const Locale('es', 'VE'),
      supportedLocales: const [Locale('es', 'VE'), Locale('es')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: const AuthGate(),
    );
  }
}

/// Muestra el acceso o la app según la sesión.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: sb.auth.onAuthStateChange,
      builder: (context, _) {
        final session = sb.auth.currentSession;
        if (session == null) return const LoginScreen();
        return RoleGate(key: ValueKey(session.user.id));
      },
    );
  }
}

/// Modo de la app y rol de equipo del usuario.
/// Rol de equipo: 'admin' | 'contador' | 'cirujano' | null (solo propietario).
/// Modo: el propietario siempre está disponible; el equipo puede alternar.
class AppMode extends InheritedWidget {
  const AppMode({super.key, required this.rol, required this.staff, required this.toggle, required this.reload,
      required super.child});

  final String? rol;
  final bool staff; // true = modo equipo (admin/contador/cirujano); false = modo propietario
  final VoidCallback toggle;
  final Future<void> Function() reload;

  bool get isAdmin => rol == 'admin';
  bool get isContador => rol == 'contador';
  bool get isCirujano => rol == 'cirujano';
  bool get canStaff => rol != null;
  Set<String> get roles => {'propietario', ?rol};

  /// Último modo construido. Las pantallas abiertas con Navigator.push quedan fuera del
  /// árbol de RoleGate; este respaldo evita el error que dejaba la pantalla en gris.
  static AppMode? _current;

  static AppMode of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppMode>() ?? _current!;

  @override
  bool updateShouldNotify(AppMode old) => old.staff != staff || old.rol != rol;
}

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> with WidgetsBindingObserver {
  bool _loaded = false;
  String? _rol;
  Object? _error;
  bool _staff = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(first: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Si un admin cambió el rol, se aplica al volver a la app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  Future<void> _load({bool first = false}) async {
    if (first) setState(() => _error = null);
    try {
      final r = await Data.miRolEquipo();
      if (!mounted) return;
      setState(() {
        final changed = r != _rol || first;
        _rol = r;
        _loaded = true;
        _error = null;
        if (changed) _staff = r != null;
      });
    } catch (e) {
      if (mounted && first) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        body: EmptyState(
          icon: Icons.wifi_off_rounded,
          title: 'No pudimos cargar tu cuenta',
          message: friendlyError(_error!),
          action: PopButton(label: 'Reintentar', onPressed: () => _load(first: true), expand: false),
        ),
      );
    }
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final Widget shell;
    if (!_staff || _rol == null) {
      shell = const OwnerShell();
    } else if (_rol == 'cirujano') {
      shell = const SurgeonShell();
    } else {
      shell = const StaffShell();
    }
    final mode = AppMode(
      rol: _rol,
      staff: _staff && _rol != null,
      toggle: () => setState(() => _staff = !_staff),
      reload: _load,
      child: KeyedSubtree(key: ValueKey('$_rol-$_staff'), child: shell),
    );
    AppMode._current = mode;
    return mode;
  }
}
