import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'theme.dart';

/// Vista previa del mapa (OpenStreetMap, sin clave de API) con el pin de la sede.
/// Tocarla abre el enlace en Google Maps / la app de mapas.
class MapaPreview extends StatelessWidget {
  const MapaPreview({super.key, required this.lat, required this.lng, this.enlace, this.height = 180});
  final double lat;
  final double lng;
  final String? enlace;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = LatLng(lat, lng);
    return Container(
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Fz.azul50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Fz.tinta, width: Fz.borde),
      ),
      child: Stack(children: [
        FlutterMap(
          options: MapOptions(
            initialCenter: p,
            initialZoom: 15.5,
            interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
            onTap: enlace == null ? null : (_, _) => abrirEnlace(enlace!),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.faunazulia.faunazulia',
            ),
            MarkerLayer(markers: [
              Marker(
                point: p,
                width: 44,
                height: 44,
                alignment: Alignment.topCenter,
                child: const Icon(Icons.location_on_rounded, size: 44, color: Fz.azul, shadows: [
                  Shadow(color: Fz.tinta, offset: Offset(1.5, 1.5)),
                ]),
              ),
            ]),
          ],
        ),
        Positioned(
          right: 6,
          bottom: 4,
          child: Text('© OpenStreetMap', style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 9)),
        ),
      ]),
    );
  }
}

/// Abre un enlace (Google Maps, WhatsApp) en la app externa correspondiente.
Future<bool> abrirEnlace(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
