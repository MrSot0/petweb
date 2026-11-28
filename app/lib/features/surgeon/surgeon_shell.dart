import 'package:flutter/material.dart';

import '../scan/scan_screen.dart';
import '../settings/settings_screen.dart';
import 'honorarios_screen.dart';
import 'surgeon_jornadas_screen.dart';
import 'surgeon_visitas_screen.dart';

/// Navegación del cirujano / veterinario: Jornadas · Escanear · Visitas · Honorarios · Ajustes.
/// Las estadísticas se abren desde Jornadas.
class SurgeonShell extends StatefulWidget {
  const SurgeonShell({super.key});

  @override
  State<SurgeonShell> createState() => _SurgeonShellState();
}

class _SurgeonShellState extends State<SurgeonShell> {
  int _i = 0;

  static const _pages = [SurgeonJornadasScreen(), ScanScreen(), SurgeonVisitasScreen(), HonorariosScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.vaccines_outlined), selectedIcon: Icon(Icons.vaccines_rounded), label: 'Jornadas'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Escanear'),
          NavigationDestination(icon: Icon(Icons.home_work_outlined), selectedIcon: Icon(Icons.home_work_rounded), label: 'Visitas'),
          NavigationDestination(icon: Icon(Icons.payments_outlined), selectedIcon: Icon(Icons.payments_rounded), label: 'Honorarios'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
