import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'config.dart';
import 'webp.dart';
import 'package:image_picker/image_picker.dart';

SupabaseClient get sb => Supabase.instance.client;

/// Modelos simples (mapas tipados). Los nombres de campo son los de la base de datos.
class Tasa {
  Tasa(this.valor, this.fechaValor, this.manual);
  final double valor;
  final DateTime fechaValor;
  final bool manual;

  /// Más de un día de antigüedad: se avisa "puede variar".
  bool get vieja => DateTime.now().difference(fechaValor).inHours > 36;

  static Tasa? fromRow(Map<String, dynamic>? r) => r == null
      ? null
      : Tasa((r['valor'] as num).toDouble(), DateTime.parse(r['fecha_valor'] as String), r['manual'] == true);
}

class Pet {
  Pet(this.m);
  final Map<String, dynamic> m;
  String get id => m['id'] as String;
  String get nombre => m['nombre'] as String;
  String get especie => m['especie'] as String; // perro | gato
  String get sexo => m['sexo'] as String; // macho | hembra
  int? get edadMeses => m['edad_meses'] as int?;
  double? get pesoKg => (m['peso_kg'] as num?)?.toDouble();
  bool get braqui => m['braquiocefalico'] == true;
  bool get esterilizada => m['esterilizada'] == true;
  bool get esPerro => especie == 'perro';
  String? get fotoUrl => Data.fotoUrl(m['foto_path'] as String?);
  String get descripcion =>
      '${esPerro ? (sexo == 'macho' ? 'Perro' : 'Perra') : (sexo == 'macho' ? 'Gato' : 'Gata')}'
      '${pesoKg != null ? ' · ${pesoKg!.toStringAsFixed(pesoKg! % 1 == 0 ? 0 : 1)} kg' : ''}';
}

class Jornada {
  Jornada(this.m, {this.cuposLibres});
  final Map<String, dynamic> m;
  final int? cuposLibres;
  String get id => m['id'] as String;
  String get titulo => m['titulo'] as String;
  String? get descripcion => m['descripcion'] as String?;
  DateTime get fecha => DateTime.parse(m['fecha_inicio'] as String).toLocal();
  String get sede => m['sede_nombre'] as String;
  String? get direccion => m['direccion'] as String?;
  String get ciudad => (m['ciudad'] as String?) ?? 'Maracaibo';
  double? get lat => (m['lat'] as num?)?.toDouble();
  double? get lng => (m['lng'] as num?)?.toDouble();
  int get cuposTotal => m['cupos_total'] as int;
  bool get limpiezaDental => m['incluye_limpieza_dental'] == true;
  String get estado => m['estado'] as String;
  String? get mapsUrl => m['maps_url'] as String?;
  String? get imagenUrl => Data.fotoUrl(m['imagen_path'] as String?);

  /// Enlace para abrir la ubicación: el de Google Maps cargado por el admin, o las coordenadas.
  String? get enlaceMapa => mapsUrl ??
      (lat != null && lng != null ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : null);
}

/// Precio calculado en el cliente solo para mostrar; el servidor recalcula al inscribir.
class Precios {
  Precios(this.filas, this.extras);
  final List<Map<String, dynamic>> filas;
  final Map<String, double> extras; // 'kit:perro' -> 7

  double? base(String servicio, Pet p) {
    if (p.braqui) return null;
    final cands = filas.where((f) =>
        f['servicio'] == servicio &&
        f['especie'] == p.especie &&
        (f['sexo'] == null || f['sexo'] == p.sexo) &&
        (f['peso_hasta'] == null || (p.pesoKg ?? 0) <= (f['peso_hasta'] as num)));
    if (cands.isEmpty) return null;
    final list = cands.toList()
      ..sort((a, b) => ((a['peso_hasta'] as num?) ?? 9999).compareTo((b['peso_hasta'] as num?) ?? 9999));
    return (list.first['precio_usd'] as num).toDouble();
  }

  double extra(String extra, String especie) => extras['$extra:$especie'] ?? 0;
}

class Data {
  // ---------- Sesión y roles ----------
  static Future<Set<String>> misRoles() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await sb.from('user_roles').select('rol').eq('user_id', uid);
    return rows.map((r) => r['rol'] as String).toSet();
  }

  static Future<Map<String, dynamic>?> miPerfil() async {
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return null;
    return sb.from('profiles').select().eq('id', uid).maybeSingle();
  }

  static Future<void> actualizarPerfil(Map<String, dynamic> cambios) async {
    await sb.from('profiles').update(cambios).eq('id', sb.auth.currentUser!.id);
  }

  // ---------- Tasa euro BCV ----------
  static Future<Tasa?> tasaVigente() async {
    final r = await sb.from('tasa_vigente').select().eq('moneda', 'EUR').eq('tipo', 'buy').maybeSingle();
    return Tasa.fromRow(r);
  }

  static Future<List<Map<String, dynamic>>> historialTasas() async =>
      sb.from('tasas_cambio').select().eq('moneda', 'EUR').order('fecha_valor', ascending: false).limit(15);

  static Future<void> setTasaManual(double valor, DateTime fechaValor, {String? motivo}) => sb.rpc(
        'rpc_set_tasa_manual',
        params: {'p_valor': valor, 'p_fecha_valor': _d(fechaValor), 'p_motivo': motivo},
      );

  // ---------- Precios ----------
  static Future<Precios> precios() async {
    final f = await sb.from('precios').select().order('servicio').order('especie').order('peso_hasta');
    final e = await sb.from('precios_extras').select();
    return Precios(
      List<Map<String, dynamic>>.from(f),
      {for (final r in e) '${r['extra']}:${r['especie']}': (r['precio_usd'] as num).toDouble()},
    );
  }

  // ---------- Jornadas ----------
  static Future<List<Jornada>> jornadas({bool todas = false}) async {
    var q = sb.from('jornadas').select(
        'id,titulo,descripcion,fecha_inicio,sede_nombre,direccion,ciudad,lat,lng,maps_url,imagen_path,cupos_total,incluye_limpieza_dental,estado');
    if (!todas) {
      q = q.eq('estado', 'publicada').gte('fecha_inicio', DateTime.now().subtract(const Duration(days: 1)).toIso8601String());
    }
    final rows = await q.order('fecha_inicio');
    final cupos = await sb.from('jornadas_cupos').select();
    final map = {for (final c in cupos) c['jornada_id'] as String: c['cupos_libres'] as int};
    return rows.map((r) => Jornada(r, cuposLibres: map[r['id']])).toList();
  }

  static Future<String?> whatsappJornada(String jornadaId) async =>
      await sb.rpc('rpc_whatsapp_jornada', params: {'p_jornada': jornadaId}) as String?;

  /// Solo admin: incluye whatsapp_url (el admin la puede leer porque es dueño de la fila via RPC/política).
  static Future<void> guardarJornada(Map<String, dynamic> datos, {String? id}) async {
    if (id == null) {
      await sb.from('jornadas').insert(datos);
    } else {
      await sb.from('jornadas').update(datos).eq('id', id);
    }
  }

  // ---------- Mascotas ----------
  static Future<List<Pet>> misMascotas() async {
    final rows = await sb.from('pets').select().eq('owner_id', sb.auth.currentUser!.id).order('created_at');
    return rows.map(Pet.new).toList();
  }

  static Future<void> guardarMascota(Map<String, dynamic> datos, {String? id}) async {
    if (id == null) {
      await sb.from('pets').insert(datos);
    } else {
      await sb.from('pets').update(datos).eq('id', id);
    }
  }

  static Future<void> borrarMascota(String id) => sb.from('pets').delete().eq('id', id);

  // ---------- Inscripciones ----------
  /// items: [{pet_id, servicio, kit, cono}]
  static Future<List<Map<String, dynamic>>> inscribir(String jornadaId, List<Map<String, dynamic>> items) async {
    final r = await sb.rpc('rpc_inscribir', params: {'p_jornada': jornadaId, 'p_items': items});
    return List<Map<String, dynamic>>.from(r as List);
  }

  static Future<List<Map<String, dynamic>>> misInscripciones() async => List<Map<String, dynamic>>.from(await sb
      .from('inscripciones')
      .select('*, pets(nombre,especie,sexo,peso_kg), jornadas(titulo,fecha_inicio,sede_nombre)')
      .eq('owner_id', sb.auth.currentUser!.id)
      .order('created_at', ascending: false));

  static Future<void> cancelarInscripcion(String id) => sb.rpc('rpc_cancelar_inscripcion', params: {'p_id': id});

  // ---------- Pagos ----------
  static Future<List<Map<String, dynamic>>> datosCobro() async =>
      List<Map<String, dynamic>>.from(await sb.from('datos_pago').select().order('orden'));

  static Future<void> guardarDatoCobro(Map<String, dynamic> datos, {int? id}) async {
    if (id == null) {
      await sb.from('datos_pago').insert(datos);
    } else {
      await sb.from('datos_pago').update(datos).eq('id', id);
    }
  }

  /// Sube el comprobante ya convertido a WebP a {uid}/{timestamp}.webp y devuelve la ruta.
  static Future<String> subirComprobante(Uint8List webp) async {
    final uid = sb.auth.currentUser!.id;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.webp';
    await sb.storage.from(AppConfig.bucketComprobantes).uploadBinary(
          path,
          webp,
          fileOptions: const FileOptions(contentType: 'image/webp', upsert: false),
        );
    return path;
  }

  static Future<Map<String, dynamic>> registrarPago({
    required List<String> inscripciones,
    required String metodo, // pago_movil | efectivo_divisa
    String? referencia,
    String? telefono,
    String? banco,
    DateTime? fecha,
    String? comprobantePath,
  }) async {
    final r = await sb.rpc('rpc_registrar_pago', params: {
      'p_inscripciones': inscripciones,
      'p_metodo': metodo,
      'p_referencia': referencia,
      'p_telefono': telefono,
      'p_banco': banco,
      'p_fecha': _d(fecha ?? DateTime.now()),
      'p_comprobante': comprobantePath,
    });
    return Map<String, dynamic>.from(r as Map);
  }

  static Future<List<Map<String, dynamic>>> misPagos() async => List<Map<String, dynamic>>.from(await sb
      .from('pagos')
      .select('*, jornadas(titulo,fecha_inicio), inscripciones(id, pets(nombre))')
      .eq('owner_id', sb.auth.currentUser!.id)
      .order('created_at', ascending: false));

  // ---------- Staff (contador / admin) ----------
  static Future<List<Map<String, dynamic>>> pagos({String? estado}) async {
    var q = sb.from('pagos').select(
        '*, profiles!pagos_owner_id_fkey(nombre,cedula,telefono,email), jornadas(titulo,fecha_inicio), inscripciones(id,codigo,precio_total_usd,incluye_kit, pets(nombre,especie,sexo,peso_kg))');
    if (estado != null) q = q.eq('estado', estado);
    return List<Map<String, dynamic>>.from(await q.order('created_at', ascending: estado == 'pendiente'));
  }

  static Future<String?> urlComprobante(String? path) async {
    if (path == null) return null;
    return sb.storage.from(AppConfig.bucketComprobantes).createSignedUrl(path, 300);
  }

  /// accion: verificar | rechazar | anular
  static Future<void> resolverPago(String pagoId, String accion, {String? motivo}) =>
      sb.rpc('rpc_resolver_pago', params: {'p_pago': pagoId, 'p_accion': accion, 'p_motivo': motivo});

  static Future<List<Map<String, dynamic>>> inscripcionesPorConfirmarPrecio() async => List<Map<String, dynamic>>.from(
      await sb
          .from('inscripciones')
          .select('*, pets(nombre,especie,sexo,peso_kg,braquiocefalico), jornadas(titulo), profiles!inscripciones_owner_id_fkey(nombre,telefono)')
          .eq('estado', 'precio_por_confirmar')
          .order('created_at'));

  static Future<void> fijarPrecio(String inscripcionId, double total) =>
      sb.rpc('rpc_fijar_precio', params: {'p_id': inscripcionId, 'p_total': total});

  static Future<List<Map<String, dynamic>>> usuarios() async =>
      List<Map<String, dynamic>>.from(await sb.from('profiles').select('*, user_roles!user_roles_user_id_fkey(rol)').order('created_at', ascending: false));

  static Future<void> asignarRol(String email, String rol, {bool quitar = false}) =>
      sb.rpc('rpc_asignar_rol', params: {'p_email': email, 'p_rol': rol, 'p_quitar': quitar});

  static Future<List<Map<String, dynamic>>> inscritosJornada(String jornadaId) async => List<Map<String, dynamic>>.from(
      await sb
          .from('inscripciones')
          .select('*, pets(nombre,especie,sexo,peso_kg), profiles!inscripciones_owner_id_fkey(nombre,telefono)')
          .eq('jornada_id', jornadaId)
          .neq('estado', 'cancelada')
          .order('created_at'));


  // ======================= v0.2 =======================

  /// URL pública de una foto del bucket 'fotos' (perfil, mascota, portada de jornada).
  static String? fotoUrl(String? path) => path == null ? null : sb.storage.from('fotos').getPublicUrl(path);

  /// Convierte a WebP y sube a 'fotos/{carpeta}/{uid}/{timestamp}.webp' (carpeta: avatares | mascotas)
  /// o a 'fotos/jornadas/{timestamp}.webp' (solo admin). Devuelve la ruta.
  static Future<String> subirFoto(XFile file, {required String carpeta}) async {
    final portada = carpeta == 'jornadas';
    final r = await WebpPipeline.convertirFoto(file,
        lado: portada ? 1600 : 1024, maxBytes: portada ? 300 * 1024 : 150 * 1024);
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = portada ? 'jornadas/$ts.webp' : '$carpeta/${sb.auth.currentUser!.id}/$ts.webp';
    await sb.storage.from('fotos').uploadBinary(path, r.bytes,
        fileOptions: const FileOptions(contentType: 'image/webp', upsert: false));
    return path;
  }

  /// Foto de la cirugía (bucket privado 'cirugias').
  static Future<String> subirFotoCirugia(XFile file, String inscripcionId) async {
    final r = await WebpPipeline.convertirFoto(file, lado: 1280, maxBytes: 250 * 1024);
    final path = '$inscripcionId/${DateTime.now().millisecondsSinceEpoch}.webp';
    await sb.storage.from('cirugias').uploadBinary(path, r.bytes,
        fileOptions: const FileOptions(contentType: 'image/webp', upsert: false));
    return path;
  }

  static Future<String?> urlFotoCirugia(String? path) async =>
      path == null ? null : sb.storage.from('cirugias').createSignedUrl(path, 300);

  /// Rol de equipo del usuario actual: admin | contador | cirujano | null.
  static Future<String?> miRolEquipo() async => await sb.rpc('mi_rol_equipo') as String?;

  /// Un solo rol de equipo por usuario: propietario (ninguno) | cirujano | contador | admin.
  static Future<void> setRol(String userId, String rol) =>
      sb.rpc('rpc_set_rol', params: {'p_user': userId, 'p_rol': rol});

  /// Retira una mascota de la jornada (admin o contador), con motivo.
  static Future<void> retirarInscripcion(String id, String motivo) =>
      sb.rpc('rpc_retirar_inscripcion', params: {'p_id': id, 'p_motivo': motivo});

  /// Busca por código de QR (FZ-AAMM-NNNN). Devuelve la ficha: pet, propietario, pago, jornada, cirugía.
  static Future<Map<String, dynamic>> buscarCodigo(String codigo) async =>
      Map<String, dynamic>.from(await sb.rpc('rpc_buscar_codigo', params: {'p_codigo': codigo}) as Map);

  /// Participantes de una jornada con datos del propietario y del pago (ficha por inscripción).
  static Future<List<Map<String, dynamic>>> participantes(String jornadaId) async =>
      List<Map<String, dynamic>>.from(
          (await sb.rpc('rpc_participantes_jornada', params: {'p_jornada': jornadaId}) as List)
              .map((e) => Map<String, dynamic>.from(e as Map)));

  static Future<void> marcarPresente(String inscripcionId) =>
      sb.rpc('rpc_marcar_presente', params: {'p_id': inscripcionId});

  static Future<Map<String, dynamic>> registrarCirugia({
    required String inscripcionId,
    required String especie,
    required String sexo,
    required String fotoPath,
    bool patologia = false,
    bool prolapso = false,
    String? observaciones,
  }) async =>
      Map<String, dynamic>.from(await sb.rpc('rpc_registrar_cirugia', params: {
        'p_inscripcion': inscripcionId,
        'p_especie': especie,
        'p_sexo': sexo,
        'p_foto': fotoPath,
        'p_patologia': patologia,
        'p_prolapso': prolapso,
        'p_obs': observaciones,
      }) as Map);

  /// Estadísticas de una jornada (o globales si jornadaId es null). 'ingresos' solo llega a admin/contador.
  static Future<Map<String, dynamic>> estadisticas([String? jornadaId]) async =>
      Map<String, dynamic>.from(await sb.rpc('rpc_estadisticas', params: {'p_jornada': jornadaId}) as Map);

  /// Convierte un enlace de Google Maps (incluso maps.app.goo.gl) en {url, lat, lng}.
  static Future<Map<String, dynamic>> resolverMapa(String url) async {
    final r = await sb.functions.invoke('resolver-mapa', body: {'url': url});
    final d = Map<String, dynamic>.from(r.data as Map);
    if (d['error'] != null) throw Exception(d['error']);
    return d;
  }

  static Future<void> actualizarFotoPerfil(String path) => actualizarPerfil({'avatar_path': path});

  static String _d(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
