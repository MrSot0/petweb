import 'package:flutter/material.dart';

import '../scan/scan_screen.dart';
import '../settings/settings_screen.dart';
import 'admin_jornadas_screen.dart';
import 'tasa_screen.dart';
import 'verificar_screen.dart';

/// Navegación del equipo (contador y administrador):
/// Pagos · Jornadas · Escanear QR · Tasa · Ajustes.
/// Las opciones solo de administración (crear jornadas, ingresos, usuarios, datos de cobro)
/// se muestran dentro de cada pantalla según AppMode.of(context).isAdmin.
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _i = 0;

  static const _pages = [VerificarScreen(), AdminJornadasScreen(), ScanScreen(), TasaScreen(), SettingsScreen()];

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
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: 'Escanear'),
          NavigationDestination(icon: Icon(Icons.currency_exchange_rounded), label: 'Tasa'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
