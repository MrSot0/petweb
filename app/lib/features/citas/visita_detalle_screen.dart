import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../owner/pets_screen.dart';
import '../owner/registrar_pago_screen.dart';
import 'visita_comun.dart';

/// Detalle y seguimiento de una visita a domicilio del propietario.
class VisitaDetalleScreen extends StatefulWidget {
  const VisitaDetalleScreen({super.key, required this.visita});

  /// Fila de `Data.misVisitas()`.
  final Map<String, dynamic> visita;

  @override
  State<VisitaDetalleScreen> createState() => _VisitaDetalleScreenState();
}

class _VisitaDetalleScreenState extends State<VisitaDetalleScreen> {
  late Map<String, dynamic> _v = widget.visita;
  List<Pet>? _pets;
  bool _cancelando = false;

  String get _id => _v['id'] as String;

  @override
  void initState() {
    super.initState();
    _cargarMascotas();
  }

  Future<void> _cargarMascotas() async {
    try {
      final ids = [for (final id in (_v['pet_ids'] as List? ?? const [])) '$id'];
      final p = await Data.mascotasPorIds(ids);
      if (mounted) setState(() => _pets = p);
    } catch (_) {
      if (mounted) setState(() => _pets = const []);
    }
  }

  Future<void> _refresh() async {
    try {
      final todas = await Data.misVisitas();
      final v = todas.where((x) => x['id'] == _id).firstOrNull;
      if (!mounted) return;
      if (v != null) setState(() => _v = v);
      await _cargarMascotas();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _abrir(String url, String falla) async {
    var ok = false;
    try {
      ok = await abrirEnlace(url);
    } catch (_) {}
    if (!ok && mounted) showInfo(context, falla);
  }

  String _waUrl(String tel) {
    var d = tel.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = '58${d.substring(1)}';
    return 'https://wa.me/$d';
  }

  Future<void> _pagar() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => RegistrarPagoScreen(visita: _v)));
    if (mounted) _refresh();
  }

  Future<void> _cancelar() async {
    final ctrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setD) => AlertDialog(
          title: const Text('¿Cancelar la visita?'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Cuéntanos por qué, así la administración puede reorganizar la agenda.'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              minLines: 2,
              maxLines: 4,
              maxLength: 300,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) => setD(() {}),
              decoration: const InputDecoration(labelText: 'Motivo'),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: const Text('No, volver')),
            TextButton(
              onPressed: ctrl.text.trim().length < 3 ? null : () => Navigator.pop(c, ctrl.text.trim()),
              style: TextButton.styleFrom(foregroundColor: Fz.frambuesa),
              child: const Text('Sí, cancelar'),
            ),
          ],
        ),
      ),
    );
    ctrl.dispose();
    if (motivo == null || !mounted) return;
    setState(() => _cancelando = true);
    try {
      await Data.cancelarVisita(_id, motivo);
      if (!mounted) return;
      showInfo(context, 'Visita cancelada');
      await _refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _cancelando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = _v;
    final estado = v['estado'] as String?;
    final precio = precioVisita(v);
    var n = 0;
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle de la visita')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FadeSlideIn(
              child: FzHero(
                title: nombreServicioVisita(v),
                subtitle: fechaVisitaTexto(v),
                leading: Icon(iconoEstadoVisita(estado), size: 36, color: Fz.tarjeta),
                child: Column(children: [
                  pillEstadoVisita(estado),
                  if (v['codigo'] != null) CodigoCopiable('${v['codigo']}', color: Fz.tarjeta),
                ]),
              ),
            ),
            if (estado == 'cancelada') ...[
              const SizedBox(height: 16),
              FadeSlideIn(
                index: ++n,
                child: PopCard(
                  color: Fz.frambuesaSuave,
                  shadow: false,
                  child: Column(children: [
                    const Icon(Icons.cancel_rounded, color: Fz.frambuesa, size: 30),
                    Text('Visita cancelada', textAlign: TextAlign.center, style: t.titleMedium),
                    if (v['motivo_cancelacion'] != null)
                      Text('Motivo: ${v['motivo_cancelacion']}', textAlign: TextAlign.center, style: t.bodyMedium),
                  ]),
                ),
              ),
            ] else ...[
              const _Titulo('Seguimiento'),
              FadeSlideIn(index: ++n, child: _LineaTiempo(estado: estado, v: v)),
            ],
            const _Titulo('Datos de la visita'),
            FadeSlideIn(index: ++n, child: _datos(t, v, precio)),
            const _Titulo('Veterinario'),
            FadeSlideIn(index: ++n, child: _veterinario(t, v)),
            const _Titulo('Dirección'),
            FadeSlideIn(index: ++n, child: _direccion(t, v)),
            if (estado == 'finalizada') ...[
              const _Titulo('Informe'),
              FadeSlideIn(
                index: ++n,
                child: PopCard(
                  color: Fz.azul50,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    const Icon(Icons.description_rounded, color: Fz.azul, size: 28),
                    const SizedBox(height: 6),
                    (v['informe'] as String?)?.trim().isNotEmpty == true
                        ? SelectableText('${v['informe']}', style: t.bodyMedium)
                        : Text('El veterinario aún no ha cargado el informe.', textAlign: TextAlign.center, style: t.bodyMedium),
                  ]),
                ),
              ),
            ],
            const _Titulo('Pago'),
            FadeSlideIn(index: ++n, child: _pago(t, v, precio)),
            if (puedeCancelarVisita(v)) ...[
              const SizedBox(height: 20),
              PopButton.danger(
                label: 'Cancelar visita',
                icon: Icons.event_busy_rounded,
                loading: _cancelando,
                onPressed: _cancelar,
              ),
            ],
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: () => _abrir(Data.whatsappSoporteUrl, 'No encontramos WhatsApp en tu teléfono.'),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('¿Dudas? Escríbenos por WhatsApp'),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _fila(TextTheme t, IconData ic, String l, String val) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 20, color: Fz.azul),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l, style: t.bodySmall),
              Text(val, style: t.titleSmall),
            ]),
          ),
        ]),
      );

  Widget _datos(TextTheme t, Map<String, dynamic> v, double? precio) {
    final pets = _pets;
    final fp = fechaPreferidaVisita(v);
    final fh = fechaHoraVisita(v);
    final dur = (v['servicios_domicilio'] as Map?)?['duracion_min'] as num?;
    return PopCard(
      color: Fz.tarjeta,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (pets == null)
          const Padding(padding: EdgeInsets.all(8), child: LinearProgressIndicator())
        else if (pets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(alignment: WrapAlignment.center, spacing: 12, runSpacing: 8, children: [
              for (final p in pets)
                Column(mainAxisSize: MainAxisSize.min, children: [
                  PetAvatar(esPerro: p.esPerro, url: p.fotoUrl, size: 48),
                  const SizedBox(height: 4),
                  Text(p.nombre, style: t.titleSmall),
                  Text(p.descripcion, style: t.labelSmall),
                ]),
            ]),
          ),
        _fila(t, Icons.medical_services_rounded, 'Servicio',
            '${nombreServicioVisita(v)}${dur != null ? ' · ${duracionTexto(dur.toInt())}' : ''}'),
        if ((v['motivo'] as String?)?.trim().isNotEmpty == true)
          _fila(t, Icons.notes_rounded, 'Motivo o síntomas', '${v['motivo']}'),
        if (fp != null)
          _fila(t, Icons.event_note_rounded, 'Fecha preferida',
              '${Money.fecha(fp)} · ${franjaTexto(v['franja'] as String?)}'),
        _fila(t, Icons.event_available_rounded, 'Fecha y hora confirmadas',
            fh == null ? 'Por confirmar' : Money.fechaLarga(fh)),
        _fila(t, Icons.sell_rounded, 'Precio', precio == null ? 'Por confirmar' : Money.usd(precio)),
      ]),
    );
  }

  Widget _veterinario(TextTheme t, Map<String, dynamic> v) {
    final vet = v['veterinario'] as Map?;
    if (vet == null) {
      return PopCard(
        color: Fz.azul50,
        shadow: false,
        child: Column(children: [
          const Icon(Icons.person_search_rounded, color: Fz.azul, size: 30),
          const SizedBox(height: 4),
          Text('Te asignaremos un veterinario al confirmar la visita.', textAlign: TextAlign.center, style: t.bodyMedium),
        ]),
      );
    }
    final nombre = vet['nombre'] as String? ?? 'Veterinario';
    final tel = (vet['telefono'] as String?)?.trim();
    return PopCard(
      color: Fz.azul50,
      child: Column(children: [
        FzAvatar(url: Data.fotoUrl(vet['avatar_path'] as String?), text: iniciales(nombre), size: 64),
        const SizedBox(height: 8),
        Text(nombre, textAlign: TextAlign.center, style: t.titleLarge),
        if (tel != null && tel.isNotEmpty) ...[
          Text(tel, textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 10),
          PopButton(
            label: 'Escribir por WhatsApp',
            icon: Icons.chat_rounded,
            onPressed: () => _abrir(_waUrl(tel), 'No encontramos WhatsApp en tu teléfono.'),
          ),
        ],
      ]),
    );
  }

  Widget _direccion(TextTheme t, Map<String, dynamic> v) {
    final lat = (v['lat'] as num?)?.toDouble(), lng = (v['lng'] as num?)?.toDouble();
    final maps = (v['maps_url'] as String?)?.trim();
    final enlace = maps != null && maps.isNotEmpty
        ? maps
        : (lat != null && lng != null ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng' : null);
    return PopCard(
      color: Fz.tarjeta,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.home_rounded, size: 28, color: Fz.azul),
        const SizedBox(height: 4),
        Text('${v['direccion'] ?? ''}', textAlign: TextAlign.center, style: t.titleMedium),
        if ((v['referencia_lugar'] as String?)?.trim().isNotEmpty == true)
          Text('Referencia: ${v['referencia_lugar']}', textAlign: TextAlign.center, style: t.bodySmall),
        if (lat != null && lng != null) ...[
          const SizedBox(height: 12),
          MapaPreview(lat: lat, lng: lng, enlace: enlace, height: 170),
        ],
        if (enlace != null) ...[
          const SizedBox(height: 12),
          PopButton.tonal(
            label: 'Ver en el mapa',
            icon: Icons.map_rounded,
            onPressed: () => _abrir(enlace, 'No encontramos una aplicación para abrir el mapa.'),
          ),
        ],
      ]),
    );
  }

  Widget _pago(TextTheme t, Map<String, dynamic> v, double? precio) {
    final pill = pillPagoVisita(v);
    final estadoPago = (v['pago'] as Map?)?['estado'];
    return PopCard(
      color: Fz.azul50,
      child: Column(children: [
        Text(precio == null ? 'Precio por confirmar' : Money.usd(precio),
            textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(color: Fz.azul700)),
        if (pill != null) ...[const SizedBox(height: 8), pill],
        const SizedBox(height: 8),
        Text(
          precio == null
              ? 'La administración te confirmará el precio; luego podrás pagar aquí.'
              : estadoPago == 'pendiente'
                  ? 'Tu pago está en revisión. Te avisaremos cuando lo verifiquen.'
                  : estadoPago == 'verificado'
                      ? 'Pago verificado. ¡Gracias!'
                      : v['estado'] == 'cancelada'
                          ? 'Esta visita fue cancelada.'
                          : 'Paga por Pago Móvil o en efectivo en divisas.',
          textAlign: TextAlign.center,
          style: t.bodySmall,
        ),
        if (puedePagarVisita(v)) ...[
          const SizedBox(height: 12),
          PopButton(
            label: estadoPago == 'rechazado' ? 'Volver a pagar' : 'Pagar ${Money.usd(precio)}',
            icon: Icons.payments_rounded,
            onPressed: _pagar,
          ),
        ],
      ]),
    );
  }
}

/// Línea de tiempo vertical: Solicitada → Confirmada → En camino → En atención → Finalizada.
class _LineaTiempo extends StatelessWidget {
  const _LineaTiempo({required this.estado, required this.v});
  final String? estado;
  final Map<String, dynamic> v;

  static const _textos = {
    'solicitada': 'Recibimos tu solicitud.',
    'confirmada': 'Fecha, hora y veterinario confirmados.',
    'en_camino': 'El veterinario va hacia tu casa.',
    'en_atencion': 'El veterinario está atendiendo a tu mascota.',
    'finalizada': 'Visita terminada. Revisa el informe.',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final actual = estadosVisita.indexOf(estado ?? '');
    return PopCard(
      color: Fz.tarjeta,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Column(children: [
        for (var k = 0; k < estadosVisita.length; k++)
          IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(
                width: 40,
                child: Column(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: k < actual ? Fz.azul : (k == actual ? Fz.azul : Fz.tarjeta),
                      shape: BoxShape.circle,
                      border: Border.all(color: k <= actual ? Fz.tinta : Fz.azul200, width: k == actual ? 3 : 2),
                      boxShadow: k == actual ? const [BoxShadow(color: Fz.tinta, offset: Offset(2, 2))] : null,
                    ),
                    child: Icon(
                      k < actual ? Icons.check_rounded : iconoEstadoVisita(estadosVisita[k]),
                      size: 18,
                      color: k <= actual ? Fz.tarjeta : Fz.azul200,
                    ),
                  ),
                  if (k < estadosVisita.length - 1)
                    Expanded(
                      child: Container(
                        width: 3,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: k < actual ? Fz.azul : Fz.azul100,
                      ),
                    ),
                ]),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 14),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      etiquetaEstadoVisita(estadosVisita[k]) + (k == actual ? ' · ahora' : ''),
                      style: t.titleSmall?.copyWith(color: k <= actual ? Fz.tinta : Fz.variante),
                    ),
                    if (k <= actual) Text(_textos[estadosVisita[k]]!, style: t.bodySmall),
                    if (k == 1 && k <= actual && fechaHoraVisita(v) != null)
                      Text(Money.fechaLarga(fechaHoraVisita(v)!), style: t.labelMedium?.copyWith(color: Fz.azul700)),
                  ]),
                ),
              ),
            ]),
          ),
      ]),
    );
  }
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
