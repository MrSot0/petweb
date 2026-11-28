import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'data.dart';

/// Notificaciones de FAUNAZULIA.
///
/// El servidor crea filas en `notificaciones` (pago verificado/rechazado, mascota atendida o retirada,
/// visita confirmada/en camino, nuevo pago por verificar, visita asignada...). Mientras la app está
/// abierta o en segundo plano, este servicio las recibe en tiempo real (Supabase Realtime) y las muestra
/// como notificación del teléfono. Con la app cerrada del todo, las ve al abrirla (bandeja).
/// Notificaciones con la app cerrada requieren Firebase Cloud Messaging (pendiente).
class Notificaciones {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static RealtimeChannel? _canal;
  static bool _listo = false;

  /// Cantidad de no leídas (para la campana).
  static final noLeidas = ValueNotifier<int>(0);

  static const _clave = 'notificaciones_activas';

  static Future<bool> activas() async {
    try {
      return (await SharedPreferences.getInstance()).getBool(_clave) ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> setActivas(bool v) async {
    try {
      await (await SharedPreferences.getInstance()).setBool(_clave, v);
    } catch (_) {}
    if (v) await pedirPermiso();
  }

  static Future<void> _init() async {
    if (_listo || kIsWeb) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    _listo = true;
  }

  /// Pide permiso de notificaciones (Android 13+).
  static Future<void> pedirPermiso() async {
    if (kIsWeb) return;
    await _init();
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Empieza a escuchar las notificaciones del usuario actual.
  static Future<void> iniciar() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return;
    await detener();
    try {
      await _init();
      if (await activas()) await pedirPermiso();
    } catch (_) {}
    await refrescarContador();
    _canal = sb
        .channel('notif-$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notificaciones',
          filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'user_id', value: uid),
          callback: (payload) async {
            final r = payload.newRecord;
            noLeidas.value = noLeidas.value + 1;
            if (await activas()) {
              await mostrar(r['titulo'] as String? ?? 'FAUNAZULIA', r['cuerpo'] as String?);
            }
          },
        )
        .subscribe();
  }

  static Future<void> detener() async {
    if (_canal != null) {
      await sb.removeChannel(_canal!);
      _canal = null;
    }
  }

  static Future<void> refrescarContador() async {
    try {
      final rows = await sb
          .from('notificaciones')
          .select('id')
          .eq('user_id', sb.auth.currentUser!.id)
          .eq('leida', false);
      noLeidas.value = rows.length;
    } catch (_) {}
  }

  static Future<void> marcarLeidas() async {
    try {
      await Data.marcarNotificacionesLeidas();
      noLeidas.value = 0;
    } catch (_) {}
  }

  static Future<void> mostrar(String titulo, String? cuerpo) async {
    if (kIsWeb) return;
    try {
      await _init();
      await _plugin.show(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000 % 100000,
        title: titulo,
        body: cuerpo,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'faunazulia_general',
            'Avisos de FAUNAZULIA',
            channelDescription: 'Pagos, citas, jornadas y visitas',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }
}
