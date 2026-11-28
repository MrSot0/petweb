import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'inscribir_screen.dart';
import 'jornadas_screen.dart';

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

  Future<void> _abrirWa(String url) async {
    var ok = false;
    try {
      ok = await abrirEnlace(url);
    } catch (_) {}
    if (!ok && mounted) showInfo(context, 'No encontramos una aplicación para abrir el enlace.');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final j = widget.jornada;
    final libres = j.cuposLibres ?? j.cuposTotal;
    final agotada = libres <= 0;
    final fecha = DateFormat("EEEE d 'de' MMMM yyyy · h:mm a", 'es').format(j.fecha);
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de jornada')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            FadeSlideIn(
              child: PopCard(
                padding: const EdgeInsets.all(10),
                child: Column(children: [
                  JornadaPortada(jornada: j, height: 170),
                  const SizedBox(height: 12),
                  Text(j.titulo, textAlign: TextAlign.center, style: t.headlineMedium),
                  const SizedBox(height: 4),
                  Text(fecha[0].toUpperCase() + fecha.substring(1), textAlign: TextAlign.center, style: t.bodyMedium),
                  const SizedBox(height: 10),
                  Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                    agotada
                        ? const StatusPill('Agotada', icon: Icons.block_rounded, color: Fz.frambuesaSuave)
                        : StatusPill('Quedan $libres de ${j.cuposTotal}', icon: Icons.check_circle_rounded, color: Fz.azul100),
                    const StatusPill('Perros y gatos', icon: Icons.pets_rounded, color: Fz.azul50),
                    if (j.limpiezaDental) const StatusPill('Limpieza dental', icon: Icons.add_circle_rounded, color: Fz.tarjeta),
                  ]),
                  if (j.descripcion != null && j.descripcion!.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(j.descripcion!, textAlign: TextAlign.center, style: t.bodyMedium),
                  ],
                  const SizedBox(height: 4),
                ]),
              ),
            ),
            const SizedBox(height: 16),
            FadeSlideIn(index: 1, child: _ubicacion(context, j)),
            const SizedBox(height: 16),
            FadeSlideIn(index: 2, child: _whatsapp(context)),
            const _Titulo('Precios por especie y sexo'),
            FadeSlideIn(index: 3, child: _resumenPrecios(context, j)),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: const BoxDecoration(
            color: Fz.tarjeta,
            border: Border(top: BorderSide(color: Fz.tinta, width: 2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (agotada)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Esta jornada no tiene cupos. Revisa las otras fechas.',
                    textAlign: TextAlign.center, style: t.bodyMedium),
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
    final enlace = j.enlaceMapa;
    final destino = lat != null && lng != null
        ? 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng'
        : enlace;
    Future<void> abrir(String url) async {
      var ok = false;
      try {
        ok = await abrirEnlace(url);
      } catch (_) {}
      if (!ok && context.mounted) showInfo(context, 'No encontramos una aplicación para abrir el mapa.');
    }

    return PopCard(
      color: Fz.azul50,
      child: Column(children: [
        const Icon(Icons.location_on_rounded, size: 30, color: Fz.azul),
        const SizedBox(height: 4),
        Text(j.sede, textAlign: TextAlign.center, style: t.titleLarge),
        if (j.direccion != null) Text(j.direccion!, textAlign: TextAlign.center, style: t.bodyMedium),
        Text(j.ciudad, textAlign: TextAlign.center, style: t.bodySmall),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 12),
          Semantics(
            button: enlace != null,
            label: 'Mapa de la sede. Toca para abrirlo.',
            child: MapaPreview(lat: lat, lng: lng, enlace: enlace, height: 170),
          ),
        ],
        const SizedBox(height: 12),
        if (enlace == null)
          Text('Pronto publicaremos la ubicación en el mapa.', textAlign: TextAlign.center, style: t.bodySmall)
        else
          Row(children: [
            Expanded(
              child: PopButton.tonal(label: 'Ver en el mapa', icon: Icons.map_rounded, onPressed: () => abrir(enlace)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: PopButton(
                label: 'Cómo llegar',
                icon: Icons.directions_rounded,
                onPressed: () => abrir(destino ?? enlace),
              ),
            ),
          ]),
      ]),
    );
  }

  Widget _whatsapp(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: Fz.tarjeta,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.forum_rounded, size: 28, color: Fz.azul),
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
                  color: Fz.azul50,
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
                  _abrirWa(url.startsWith('http') ? url : 'https://$url');
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
                Icon(ic, size: 20, color: Fz.azul),
                const SizedBox(width: 8),
                Expanded(child: Text(n, style: t.titleMedium)),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text('${desde ? 'desde ' : ''}${Money.usd(v)}', style: t.titleLarge),
                  if (tasa != null && v != null) Text(bs(v), style: t.bodySmall),
                ]),
              ]),
            );
        final kitG = p.extra('kit', 'gato'), kitP = p.extra('kit', 'perro');
        final conoG = p.extra('cono', 'gato'), conoP = p.extra('cono', 'perro');
        final dental = minimo('limpieza_dental', 'gato', null);
        return PopCard(
          color: Fz.azul50,
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

class _Titulo extends StatelessWidget {
  const _Titulo(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 10),
        child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      );
}
