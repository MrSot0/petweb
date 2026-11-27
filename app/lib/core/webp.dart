import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

import 'config.dart';

/// Resultado de preparar un comprobante para la web.
class WebpResult {
  WebpResult(this.bytes, this.originalBytes, this.quality);
  final Uint8List bytes;
  final int originalBytes;
  final int quality;
}

/// Convierte la foto del comprobante a WebP en el teléfono:
/// - redimensiona a un lado mayor de 1600 px,
/// - re-codifica sin EXIF (se pierden ubicación GPS y datos de la cámara),
/// - baja la calidad por pasos hasta pesar ≤ 300 KB.
/// Nunca sube la imagen original.
class WebpPipeline {
  static final _picker = ImagePicker();

  static Future<XFile?> elegir({required bool camara}) => _picker.pickImage(
        source: camara ? ImageSource.camera : ImageSource.gallery,
        requestFullMetadata: false,
      );

  /// Comprobante de pago: 1600 px, ≤ 300 KB.
  static Future<WebpResult> convertir(XFile file) =>
      convertirFoto(file, lado: AppConfig.maxComprobanteLado, maxBytes: AppConfig.maxComprobanteBytes);

  /// Foto general: perfil/mascota (1024 px, ≤ 150 KB), portada de jornada (1600 px, ≤ 300 KB),
  /// cirugía (1280 px, ≤ 250 KB).
  static Future<WebpResult> convertirFoto(XFile file, {int lado = 1024, int maxBytes = 150 * 1024}) async {
    final original = await file.length();
    if (original > 15 * 1024 * 1024) {
      throw Exception('La foto es muy pesada (más de 15 MB). Prueba con otra.');
    }
    for (var intento = 0; intento < 6; intento++) {
      for (final q in const [80, 70, 60, 50]) {
        final out = await FlutterImageCompress.compressWithFile(
          file.path,
          format: CompressFormat.webp,
          quality: q,
          minWidth: lado,
          minHeight: lado,
          keepExif: false,
          autoCorrectionAngle: true,
        );
        if (out == null) {
          throw Exception('No pudimos preparar la foto. Prueba con otra.');
        }
        if (out.lengthInBytes <= maxBytes) {
          return WebpResult(out, original, q);
        }
      }
      lado = (lado * .8).round();
    }
    throw Exception('No pudimos reducir la foto lo suficiente. Recórtala e inténtalo de nuevo.');
  }

  static String kb(int bytes) =>
      bytes >= 1024 * 1024 ? '${(bytes / 1024 / 1024).toStringAsFixed(1).replaceAll('.', ',')} MB' : '${(bytes / 1024).round()} KB';
}
