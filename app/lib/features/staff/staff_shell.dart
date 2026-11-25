import 'package:flutter/material.dart';

import '../../main.dart';
import 'admin_jornadas_screen.dart';
import 'staff_more_screen.dart';
import 'tasa_screen.dart';
import 'verificar_screen.dart';

/// Navegación del equipo. Contador: Por verificar · Tasa · Más.
/// Administrador: además Jornadas (crear/editar, inscritos, precios por confirmar).
class StaffShell extends StatefulWidget {
  const StaffShell({super.key});

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  int _i = 0;

  @override
  Widget build(BuildContext context) {
    final admin = AppMode.of(context).isAdmin;
    final pages = <Widget>[
      const VerificarScreen(),
      const TasaScreen(),
      if (admin) const AdminJornadasScreen(),
      const StaffMoreScreen(),
    ];
    final dest = <NavigationDestination>[
      const NavigationDestination(icon: Icon(Icons.fact_check_outlined), selectedIcon: Icon(Icons.fact_check_rounded), label: 'Por verificar'),
      const NavigationDestination(icon: Icon(Icons.currency_exchange_rounded), label: 'Tasa'),
      if (admin) const NavigationDestination(icon: Icon(Icons.event_outlined), selectedIcon: Icon(Icons.event_rounded), label: 'Jornadas'),
      const NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: 'Más'),
    ];
    final i = _i.clamp(0, pages.length - 1);
    return Scaffold(
      body: IndexedStack(index: i, children: pages),
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(border: Border(top: BorderSide(width: 2.5))),
        child: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => _i = v), destinations: dest),
      ),
    );
  }
}
