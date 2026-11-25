/// Configuración pública del proyecto Supabase de FAUNAZULIA.
///
/// La clave `sb_publishable_` está hecha para ir dentro de la app: solo permite
/// lo que dejan las reglas RLS de la base de datos. Nunca pongas aquí la clave
/// secreta (`sb_secret_` / `service_role`).
class AppConfig {
  static const supabaseUrl = 'https://hrwnqdyvaxiwxobwhyjz.supabase.co';
  static const supabasePublishableKey = 'sb_publishable_fm18BY-2l_SA16TRerM5Fw_BBNnYW4n';

  /// Bucket privado de comprobantes (solo acepta image/webp, máx. 500 KB).
  static const bucketComprobantes = 'comprobantes';

  /// Límite de peso del comprobante ya convertido a WebP.
  static const maxComprobanteBytes = 300 * 1024;

  /// Lado mayor máximo del comprobante.
  static const maxComprobanteLado = 1600;
}
