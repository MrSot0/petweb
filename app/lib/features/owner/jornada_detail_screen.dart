import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'inscribir_screen.dart';

/// Detalle de una jornada: fecha, sede, mapa, WhatsApp, precios e inscripción.
class JornadaDetailScreen extends StatefulWidget {
  const JornadaDetailScreen({super.key, required this.jornada});
  final Jornada jornada;

  @override
  State<JornadaDetailScreen> createState() => _JornadaDetailScreenState();
}

class _JornadaDetailScreenState extends State<JornadaDetailScreen> {
  late Future<String?> _wa = Data.whatsappJornada(widget.jornada.id);
  late Future<(Precios, Tasa?)> _precios = _loadPrecios();

  Future<(Precios, Tasa?)> _loadPrecios() async {
    final p = await Data.precios();
    Tasa? tasa;
    try {
      tasa = await Data.tasaVigente();
    } catch (_) {}
    return (p, tasa);
  }

  Future<void> _refresh() async {
    final wa = Data.whatsappJornada(widget.jornada.id);
    final pr = _loadPrecios();
    setState(() {
      _wa = wa;
      _precios = pr;
    });
    try {
      await Future.wait([wa, pr]);
    } catch (_) {}
  }

  Future<void> _abrir(Uri uri, {Uri? fallback}) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (fallback != null) {
      try {
        if (await launchUrl(fallback, mode: LaunchMode.externalApplication)) return;
      } catch (_) {}
    }
    if (mounted) showInfo(context, 'No encontramos una aplicación para abrir el enlace.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final j = widget.jornada;
    final libres = j.cuposLibres ?? j.cuposTotal;
    final agotada = libres <= 0;
    final fecha = DateFormat("EEE d 'de' MMM yyyy · h:mm a", 'es').format(j.fecha);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de jornada')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Row(children: [
              const Icon(Icons.calendar_month_rounded, size: 20, color: Fz.variante),
              const SizedBox(width: 6),
              Expanded(child: Text(fecha[0].toUpperCase() + fecha.substring(1), style: t.titleMedium)),
            ]),
            const SizedBox(height: 6),
            Text(j.titulo, style: t.headlineMedium),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              agotada
                  ? const StatusPill('Agotada', icon: Icons.block_rounded, color: Fz.frambuesaSuave)
                  : StatusPill('Quedan $libres de ${j.cuposTotal}', icon: Icons.check_circle_rounded),
              const StatusPill('Perros y gatos', icon: Icons.pets_rounded, color: Fz.rosaSuave),
              if (j.limpiezaDental) const StatusPill('Limpieza dental', icon: Icons.add_circle_rounded, color: Fz.cremaClaro),
            ]),
            if (j.descripcion != null && j.descripcion!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(j.descripcion!, style: t.bodyLarge),
            ],
            const SizedBox(height: 16),
            _ubicacion(context, j),
            const SizedBox(height: 16),
            _whatsapp(context),
            const SectionTitle('Precios por especie y sexo'),
            _resumenPrecios(context, j),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Fz.crema,
            border: Border(top: BorderSide(color: Fz.tinta, width: 2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (agotada)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Esta jornada no tiene cupos. Revisa las otras fechas.', style: t.bodyMedium),
              ),
            PopButton(
              label: 'Inscribir mis mascotas',
              icon: Icons.pets_rounded,
              onPressed: agotada
                  ? null
                  : () => Navigator.push(context, MaterialPageRoute(builder: (_) => InscribirScreen(jornada: j))),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _ubicacion(BuildContext context, Jornada j) {
    final t = Theme.of(context).textTheme;
    final lat = j.lat, lng = j.lng;
    final tiene = lat != null && lng != null;
    final coords = tiene ? '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}' : null;
    return PopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.location_on_rounded, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(j.sede, style: t.titleLarge),
              if (j.direccion != null) Text(j.direccion!, style: t.bodyMedium),
              Text(j.ciudad, style: t.bodySmall),
            ]),
          ),
        ]),
        if (tiene) ...[
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.my_location_rounded, size: 18, color: Fz.variante),
            const SizedBox(width: 6),
            Expanded(child: Text(coords!, style: t.bodyMedium)),
            IconButton(
              tooltip: 'Copiar coordenadas',
              icon: const Icon(Icons.content_copy_rounded),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: coords));
                if (context.mounted) showInfo(context, 'Coordenadas copiadas');
              },
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: PopButton.tonal(
                label: 'Abrir en mapas',
                icon: Icons.map_rounded,
                onPressed: () => _abrir(
                  Uri.parse('geo:$lat,$lng?q=$lat,$lng(${Uri.encodeComponent(j.sede)})'),
                  fallback: Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng'),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PopButton(
                label: 'Cómo llegar',
                icon: Icons.directions_rounded,
                onPressed: () => _abrir(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=$lat,$lng')),
              ),
            ),
          ]),
        ] else ...[
          const SizedBox(height: 8),
          Text('Pronto publicaremos la ubicación exacta en el mapa.', style: t.bodySmall),
        ],
      ]),
    );
  }

  Widget _whatsapp(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: Fz.azulPastel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.forum_rounded, size: 28),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Grupo de WhatsApp de esta jornada', style: t.titleMedium),
              Text('Avisos de horario, ayuno y cuidados después de la operación.', style: t.bodyMedium),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        FutureBuilder<String?>(
          future: _wa,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const LinearProgressIndicator();
            }
            if (snap.hasError) {
              return Row(children: [
                Expanded(child: Text('No pudimos cargar el enlace del grupo.', style: t.bodyMedium)),
                TextButton(
                  onPressed: () => setState(() => _wa = Data.whatsappJornada(widget.jornada.id)),
                  child: const Text('Reintentar'),
                ),
              ]);
            }
            final url = snap.data;
            if (url == null || url.trim().isEmpty) {
              return Row(children: [
                const Icon(Icons.lock_clock_rounded, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Te mostramos el enlace cuando inscribas a tu mascota.', style: t.bodyMedium)),
              ]);
            }
            final visible = url.replaceFirst(RegExp(r'^https?://'), '');
            return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Container(
                padding: const EdgeInsets.only(left: 12),
                decoration: BoxDecoration(
                  color: Fz.cremaClaro,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Fz.tinta, width: 2),
                ),
                child: Row(children: [
                  Expanded(child: SelectableText(visible, style: t.titleSmall)),
                  IconButton(
                    tooltip: 'Copiar enlace',
                    icon: const Icon(Icons.content_copy_rounded),
                    onPressed: () async {
                      await Clipboard.setData(ClipboardData(text: url));
                      if (context.mounted) showInfo(context, 'Enlace copiado');
                    },
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              PopButton(
                label: 'Abrir',
                icon: Icons.chat_rounded,
                onPressed: () {
                  final u = Uri.tryParse(url.startsWith('http') ? url : 'https://$url');
                  if (u != null) _abrir(u);
                },
              ),
            ]);
          },
        ),
      ]),
    );
  }

  Widget _resumenPrecios(BuildContext context, Jornada j) {
    final t = Theme.of(context).textTheme;
    return FutureBuilder<(Precios, Tasa?)>(
      future: _precios,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError) {
          return PopCard(
            child: Row(children: [
              Expanded(child: Text('No pudimos cargar los precios. ${friendlyError(snap.error!)}', style: t.bodyMedium)),
              TextButton(onPressed: () => setState(() => _precios = _loadPrecios()), child: const Text('Reintentar')),
            ]),
          );
        }
        final (p, tasa) = snap.data!;
        double? minimo(String servicio, String especie, String? sexo) {
          final vals = p.filas
              .where((f) => f['servicio'] == servicio && f['especie'] == especie && (sexo == null || f['sexo'] == null || f['sexo'] == sexo))
              .map((f) => (f['precio_usd'] as num).toDouble())
              .toList();
          if (vals.isEmpty) return null;
          vals.sort();
          return vals.first;
        }

        String bs(double? v) => tasa == null ? '' : Money.bs(Money.aBs(v, tasa.valor));
        Widget fila(IconData ic, String n, double? v, {bool desde = false}) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(children: [
                Icon(ic, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(n, style: t.titleMedium)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${desde ? 'desde ' : ''}${Money.usd(v)}', style: Fz.display(18, w: FontWeight.w700)),
                  if (tasa != null && v != null) Text(bs(v), style: t.bodySmall),
                ]),
              ]),
            );
        final kitG = p.extra('kit', 'gato'), kitP = p.extra('kit', 'perro');
        final conoG = p.extra('cono', 'gato'), conoP = p.extra('cono', 'perro');
        final dental = minimo('limpieza_dental', 'gato', null);
        return PopCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            fila(Icons.male_rounded, 'Gato', minimo('esterilizacion', 'gato', 'macho')),
            fila(Icons.female_rounded, 'Gata', minimo('esterilizacion', 'gato', 'hembra')),
            fila(Icons.male_rounded, 'Perro', minimo('esterilizacion', 'perro', 'macho'), desde: true),
            fila(Icons.female_rounded, 'Perra', minimo('esterilizacion', 'perro', 'hembra'), desde: true),
            const SizedBox(height: 4),
            Text('Precio base de la cirugía. En perros sube según el peso.', style: t.bodySmall),
            const Divider(height: 24),
            _nota(context, Icons.medical_services_rounded,
                'Kit post-operatorio recomendado: +${Money.usd(kitG)} gato / +${Money.usd(kitP)} perro'),
            _nota(context, Icons.add_circle_rounded, 'Cono opcional: +${Money.usd(conoG)} gato / +${Money.usd(conoP)} perro'),
            _nota(context, Icons.info_rounded, 'Más de 30 kg y braquiocefálicos: precio a convenir'),
            if (j.limpiezaDental && dental != null)
              _nota(context, Icons.add_circle_outline_rounded,
                  'Limpieza dental desde ${Money.usd(dental)} · con pulitura de esmalte'),
            const SizedBox(height: 8),
            Text(
              tasa == null
                  ? 'Tasa no disponible; el monto en Bs se confirma al pagar.'
                  : 'Tasa euro BCV ${Money.tasa(tasa.valor)} · ${Money.fecha(tasa.fechaValor)}'
                      '${tasa.vieja ? ' (tasa del ${DateFormat('dd/MM').format(tasa.fechaValor)}, puede variar)' : ''}. '
                      'Pagas por Pago Móvil o en efectivo en divisas.',
              style: t.bodySmall,
            ),
          ]),
        );
      },
    );
  }

  Widget _nota(BuildContext context, IconData ic, String tx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 18, color: Fz.variante),
          const SizedBox(width: 8),
          Expanded(child: Text(tx, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}
