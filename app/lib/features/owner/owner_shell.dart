import 'package:flutter/material.dart';

import '../citas/citas_screen.dart';
import '../settings/settings_screen.dart';
import 'home_screen.dart';
import 'jornadas_screen.dart';
import 'pets_screen.dart';

/// Navegación del propietario: Inicio · Jornadas · Citas · Mascotas · Ajustes.
/// "Mis pagos" se abre desde Inicio, Citas y Ajustes.
class OwnerShell extends StatefulWidget {
  const OwnerShell({super.key});

  /// Permite que una pantalla hija cambie de pestaña (0 Inicio, 1 Jornadas, 2 Citas, 3 Mascotas, 4 Ajustes).
  static void irA(BuildContext context, int index) =>
      context.findAncestorStateOfType<_OwnerShellState>()?._go(index);

  @override
  State<OwnerShell> createState() => _OwnerShellState();
}

class _OwnerShellState extends State<OwnerShell> {
  int _i = 0;
  void _go(int i) => setState(() => _i = i);

  static const _pages = [HomeScreen(), JornadasScreen(), CitasScreen(), PetsScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _i, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: _go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event_rounded), label: 'Jornadas'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month_rounded), label: 'Citas'),
          NavigationDestination(icon: Icon(Icons.pets_outlined), selectedIcon: Icon(Icons.pets_rounded), label: 'Mascotas'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
