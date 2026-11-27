import 'package:flutter/material.dart';

import '../scan/scan_screen.dart';
import '../settings/settings_screen.dart';
import '../staff/stats_screen.dart';
import 'surgeon_jornadas_screen.dart';

/// Navegación del cirujano: Jornadas · Escanear QR · Estadísticas · Ajustes.
class SurgeonShell extends StatefulWidget {
  const SurgeonShell({super.key});

  @override
  State<SurgeonShell> createState() => _SurgeonShellState();
}

class _SurgeonShellState extends State<SurgeonShell> {
  int _i = 0;

  static const _pages = [SurgeonJornadasScreen(), ScanScreen(), EstadisticasScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.medical_services_outlined), selectedIcon: Icon(Icons.medical_services_rounded), label: 'Jornadas'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Escanear'),
          NavigationDestination(icon: Icon(Icons.bar_chart_rounded), label: 'Estadísticas'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
