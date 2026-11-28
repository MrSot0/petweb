import 'package:flutter/material.dart';

import '../settings/settings_screen.dart';
import 'soporte_usuarios_screen.dart';

/// Navegación de soporte: Usuarios (buscar, reiniciar contraseñas, confirmar correos, ver cuenta) · Ajustes.
class SupportShell extends StatefulWidget {
  const SupportShell({super.key});

  @override
  State<SupportShell> createState() => _SupportShellState();
}

class _SupportShellState extends State<SupportShell> {
  int _i = 0;

  static const _pages = [SoporteUsuariosScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.support_agent_outlined), selectedIcon: Icon(Icons.support_agent_rounded), label: 'Usuarios'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
