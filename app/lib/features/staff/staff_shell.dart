import 'package:flutter/material.dart';

import '../scan/scan_screen.dart';
import '../settings/settings_screen.dart';
import 'admin_jornadas_screen.dart';
import 'admin_visitas_screen.dart';
import 'verificar_screen.dart';

/// Navegación del equipo (contador y administrador):
/// Pagos · Jornadas · Citas (visitas a domicilio) · Escanear · Ajustes.
/// La tasa se abre desde Pagos y Ajustes. Lo exclusivo del admin se muestra según AppMode.isAdmin.
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _i = 0;

  static const _pages = [VerificarScreen(), AdminJornadasScreen(), AdminVisitasScreen(), ScanScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check_rounded), label: 'Pagos'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event_rounded), label: 'Jornadas'),
          NavigationDestination(icon: Icon(Icons.home_work_outlined), selectedIcon: Icon(Icons.home_work_rounded), label: 'Citas'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Escanear'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
