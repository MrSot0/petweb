import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'theme.dart';

/// QR de una inscripción. Contiene solo el código (FZ-AAMM-NNNN): el equipo lo escanea
/// y la app consulta la ficha con permisos (rpc_buscar_codigo). No lleva datos personales.
class CodigoQr extends StatelessWidget {
  const CodigoQr({super.key, required this.codigo, this.size = 200});
  final String codigo;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Fz.tarjeta,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Fz.tinta, width: Fz.borde),
        ),
        child: QrImageView(
          data: codigo,
          size: size,
          backgroundColor: Fz.tarjeta,
          eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.circle, color: Fz.tinta),
          dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.circle, color: Fz.tinta),
          semanticsLabel: 'Código QR $codigo',
        ),
      ),
      const SizedBox(height: 8),
      SelectableText(codigo, style: Fz.display(18, color: Fz.tinta)),
    ]);
  }
}
