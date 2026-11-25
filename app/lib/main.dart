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

/// Modo de la app: propietario o equipo (contador / administrador).
class AppMode extends InheritedWidget {
  const AppMode({super.key, required this.roles, required this.staff, required this.toggle, required super.child});

  final Set<String> roles;
  final bool staff;
  final VoidCallback toggle;

  bool get isAdmin => roles.contains('admin');
  bool get isContador => roles.contains('contador');
  bool get canStaff => isAdmin || isContador;

  static AppMode of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<AppMode>()!;

  @override
  bool updateShouldNotify(AppMode old) => old.staff != staff || old.roles != roles;
}

class RoleGate extends StatefulWidget {
  const RoleGate({super.key});

  @override
  State<RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<RoleGate> {
  Set<String>? _roles;
  Object? _error;
  bool _staff = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.misRoles();
      setState(() {
        _roles = r;
        _staff = r.contains('admin') || r.contains('contador');
      });
    } catch (e) {
      setState(() => _error = e);
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
          action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
        ),
      );
    }
    if (_roles == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AppMode(
      roles: _roles!,
      staff: _staff,
      toggle: () => setState(() => _staff = !_staff),
      child: _staff ? const StaffShell() : const OwnerShell(),
    );
  }
}
