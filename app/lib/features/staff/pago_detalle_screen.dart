import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import 'verificar_screen.dart';

/// Detalle de un pago: comprobante, montos reportado vs esperado y acciones.
class PagoDetalleScreen extends StatefulWidget {
  const PagoDetalleScreen({super.key, required this.pago});
  final Map<String, dynamic> pago;

  @override
  State<PagoDetalleScreen> createState() => _PagoDetalleScreenState();
}

class _PagoDetalleScreenState extends State<PagoDetalleScreen> {
  static const motivosRapidos = [
    'El monto no coincide',
    'No encontramos la referencia',
    'Comprobante ilegible',
    'Comprobante duplicado',
  ];

  late Future<String?> _url;
  bool _busy = false;

  Map<String, dynamic> get p => widget.pago;

  @override
  void initState() {
    super.initState();
    _url = Data.urlComprobante(staffStr(p['comprobante_path']));
  }

  Future<void> _resolver(String accion, {String? motivo}) async {
    final id = staffStr(p['id']);
    if (id == null) {
      showInfo(context, 'Este pago no tiene identificador. Recarga la lista e inténtalo de nuevo.');
      return;
    }
    setState(() => _busy = true);
    try {
      await Data.resolverPago(id, accion, motivo: motivo);
      if (!mounted) return;
      showInfo(context, switch (accion) {
        'verificar' => 'Pago verificado',
        'rechazar' => 'Pago rechazado. El propietario verá el motivo.',
        _ => 'Verificación anulada',
      });
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showError(context, e);
      }
    }
  }

  Future<void> _verificar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Verificar este pago?'),
        content: Text(
            'Confirma que recibiste ${Money.usd(staffNum(p['monto_usd']))} con la referencia ${p['referencia'] ?? '—'}. '
            'Las inscripciones quedarán confirmadas.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Verificar')),
        ],
      ),
    );
    if (ok == true) _resolver('verificar');
  }

  Future<void> _rechazar() async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MotivoSheet(
        titulo: 'Rechazar pago',
        texto: 'El propietario verá este motivo y podrá reportar el pago de nuevo.',
        rapidos: motivosRapidos,
        boton: 'Rechazar pago',
      ),
    );
    if (motivo != null) _resolver('rechazar', motivo: motivo);
  }

  Future<void> _anular() async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MotivoSheet(
        titulo: 'Anular verificación',
        texto: 'El pago volverá a quedar sin validez. Escribe por qué (obligatorio).',
        rapidos: [],
        boton: 'Anular verificación',
      ),
    );
    if (motivo != null) _resolver('anular', motivo: motivo);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final prof = (p['profiles'] as Map?) ?? const {};
    final jor = (p['jornadas'] as Map?) ?? const {};
    final ins = ((p['inscripciones'] as List?) ?? const []).whereType<Map>().toList();
    final reportado = staffNum(p['monto_usd']);
    final esperado = ins.fold<double>(0, (s, i) => s + (staffNum(i['precio_total_usd']) ?? 0));
    final tasa = staffNum(p['tasa_eur_bcv']);
    final bs = staffNum(p['monto_bs']) ?? Money.aBs(reportado, tasa);
    final tasaFecha = staffFecha(p['tasa_fecha']);
    final coincide = reportado != null && (reportado - esperado).abs() < 0.005;
    final estado = staffStr(p['estado']) ?? 'pendiente';
    final nombre = staffStr(prof['nombre']);
    final referencia = staffStr(p['referencia']);
    final banco = staffStr(p['banco_emisor']);
    final telEmisor = staffStr(p['telefono_emisor']);
    final fechaPago = staffFecha(p['fecha_pago']);
    final jorTitulo = staffStr(jor['titulo']);
    final jorFecha = staffFecha(jor['fecha_inicio']);
    final telefono = staffStr(prof['telefono']);
    final verificadoAt = staffFecha(p['verificado_at']);
    final motivo = staffStr(p['motivo_rechazo']);
    final admin = AppMode.of(context).isAdmin;
    final pm = p['metodo'] != 'efectivo_divisa';

    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pago')),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FadeSlideIn(
          child: FzHero(
            leading: FzAvatar(text: iniciales(nombre), size: 52, color: Fz.azul100),
            title: Money.usd(reportado),
            subtitle: '${nombre ?? 'Propietario'} · ${staffMetodo(staffStr(p['metodo']))} · '
                'reportado ${staffHace(staffStr(p['created_at']))}',
            child: Text(Money.bs(bs), style: t.titleMedium?.copyWith(color: Fz.tarjeta)),
          ),
        ),
        const SizedBox(height: 16),
        // ---- Comprobante ----
        PopCard(
          padding: const EdgeInsets.all(8),
          child: FutureBuilder<String?>(
            future: _url,
            builder: (_, s) {
              if (s.connectionState != ConnectionState.done) {
                return const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()));
              }
              if (s.hasError || s.data == null) {
                return SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.image_not_supported_rounded, size: 36, color: Fz.variante),
                      const SizedBox(height: 6),
                      Text(s.hasError ? 'No pudimos abrir el comprobante' : 'Sin comprobante', style: t.titleSmall),
                      if (!pm) Text('Pago en efectivo', style: t.bodySmall),
                    ]),
                  ),
                );
              }
              return Stack(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 5,
                      child: Image.network(
                        s.data!,
                        height: 360,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, prog) => prog == null
                            ? child
                            : const SizedBox(height: 360, child: Center(child: CircularProgressIndicator())),
                        errorBuilder: (_, _, _) => const SizedBox(
                            height: 120, child: Center(child: Text('No pudimos cargar la imagen'))),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 4,
                    top: 4,
                    child: IconButton.filledTonal(
                      tooltip: 'Ver en pantalla completa',
                      icon: const Icon(Icons.zoom_out_map_rounded),
                      onPressed: () => Navigator.of(context)
                          .push(MaterialPageRoute(builder: (_) => _ZoomScreen(url: s.data!))),
                    ),
                  ),
                ]);
            },
          ),
        ),
        const SizedBox(height: 16),

        // ---- Montos ----
        PopCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Text('Montos', style: t.titleLarge)),
            const SizedBox(height: 8),
            _fila(t, 'Reportado', Money.usd(reportado), bold: true),
            _fila(t, 'Esperado', Money.usd(esperado), sub: '${ins.length} ${ins.length == 1 ? 'inscripción' : 'inscripciones'}'),
            _fila(t, 'En Bs', Money.bs(bs),
                sub: tasa == null
                    ? 'Sin tasa registrada'
                    : 'Tasa euro BCV ${Money.tasa(tasa)}${tasaFecha != null ? ' del ${Money.fecha(tasaFecha)}' : ''} (congelada)'),
            const SizedBox(height: 8),
            coincide
                ? const StatusPill('El monto coincide', icon: Icons.check_circle_rounded, color: Fz.azul200)
                : StatusPill(
                    'Diferencia de ${Money.usd(((reportado ?? 0) - esperado).abs())}',
                    icon: Icons.warning_rounded,
                    color: Fz.frambuesaSuave,
                  ),
          ]),
        ),
        const SizedBox(height: 16),

        // ---- Datos del pago ----
        PopCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Text('Datos del pago', style: t.titleLarge)),
            const SizedBox(height: 8),
            _fila(t, 'Método', staffMetodo(staffStr(p['metodo']))),
            if (referencia != null) _copiable(t, 'Referencia', referencia),
            if (banco != null) _fila(t, 'Banco', banco),
            if (telEmisor != null) _copiable(t, 'Tel. emisor', telEmisor),
            if (fechaPago != null) _fila(t, 'Fecha', Money.fecha(fechaPago)),
            if (jorTitulo != null)
              _fila(t, 'Jornada', jorTitulo, sub: jorFecha != null ? Money.fechaLarga(jorFecha) : null),
          ]),
        ),
        const SizedBox(height: 16),

        // ---- Propietario ----
        PopCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Text('Propietario', style: t.titleLarge)),
            const SizedBox(height: 8),
            _fila(t, 'Nombre', nombre ?? '—'),
            _fila(t, 'Cédula', staffStr(prof['cedula']) ?? '—'),
            if (telefono != null) _copiable(t, 'Teléfono', telefono) else _fila(t, 'Teléfono', '—'),
            if (staffStr(prof['email']) != null) _fila(t, 'Correo', staffStr(prof['email'])!),
          ]),
        ),
        const SizedBox(height: 16),

        // ---- Mascotas ----
        PopCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Text('Mascotas', style: t.titleLarge)),
            const SizedBox(height: 4),
            for (final i in ins)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  const Icon(Icons.pets_rounded, color: Fz.azul),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(staffStr((i['pets'] as Map?)?['nombre']) ?? 'Mascota', style: t.titleMedium),
                      Text(
                        [
                          if (i['codigo'] != null) 'Cód. ${i['codigo']}',
                          i['incluye_kit'] == true ? 'Con kit' : 'Sin kit',
                        ].join(' · '),
                        style: t.bodySmall,
                      ),
                    ]),
                  ),
                  StatusPill(
                    i['incluye_kit'] == true ? 'Kit: sí' : 'Kit: no',
                    icon: i['incluye_kit'] == true ? Icons.medical_services_rounded : Icons.remove_rounded,
                    color: i['incluye_kit'] == true ? Fz.azul100 : Fz.tarjeta,
                    dashed: i['incluye_kit'] != true,
                  ),
                  const SizedBox(width: 8),
                  Text(Money.usd(staffNum(i['precio_total_usd'])), style: t.titleMedium),
                ]),
              ),
          ]),
        ),

        // ---- Estado resuelto ----
        if (estado != 'pendiente') ...[
          const SizedBox(height: 16),
          PopCard(
            color: estado == 'verificado' ? Fz.azul100 : Fz.frambuesaSuave,
            child: Row(children: [
              Icon(estado == 'verificado' ? Icons.check_circle_rounded : Icons.cancel_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${switch (estado) {
                      'verificado' => 'Verificado',
                      'rechazado' => 'Rechazado',
                      _ => 'Anulado',
                    }} por ${staffRol(staffStr(p['verificado_por_rol']))}',
                    style: t.titleMedium,
                  ),
                  if (verificadoAt != null) Text(Money.fechaLarga(verificadoAt), style: t.bodySmall),
                  if (motivo != null) Text('Motivo: $motivo', style: t.bodyMedium),
                ]),
              ),
            ]),
          ),
        ],

        // ---- Acciones ----
        if (estado == 'pendiente') ...[
          const SizedBox(height: 24),
          PopButton(
            label: 'Verificar pago',
            icon: Icons.check_rounded,
            loading: _busy,
            onPressed: _busy ? null : _verificar,
          ),
          const SizedBox(height: 14),
          PopButton.danger(label: 'Rechazar', icon: Icons.close_rounded, onPressed: _busy ? null : _rechazar),
        ] else if (estado == 'verificado' && admin) ...[
          const SizedBox(height: 24),
          PopButton.danger(
            label: 'Anular verificación',
            icon: Icons.undo_rounded,
            loading: _busy,
            onPressed: _busy ? null : _anular,
          ),
        ],
        if (estado == 'pendiente' || (estado == 'verificado' && admin)) ...[
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.verified_user_rounded, size: 16, color: Fz.variante),
            const SizedBox(width: 6),
            Text('Tu nombre y rol quedan registrados', style: t.bodySmall),
          ]),
        ],
      ])),
    );
  }

  Widget _fila(TextTheme t, String k, String v, {String? sub, bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(width: 96, child: Text(k, style: t.bodySmall)),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(v, style: bold ? Fz.display(20) : t.titleMedium),
              if (sub != null) Text(sub, style: t.bodySmall),
            ]),
          ),
        ]),
      );

  Widget _copiable(TextTheme t, String k, String v) => Row(children: [
        Expanded(child: _fila(t, k, v)),
        IconButton(
          tooltip: 'Copiar $k',
          icon: const Icon(Icons.copy_rounded),
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: v));
            if (mounted) showInfo(context, '$k copiado');
          },
        ),
      ]);
}

/// Hoja para escribir un motivo, con chips de motivos rápidos.
class _MotivoSheet extends StatefulWidget {
  const _MotivoSheet({required this.titulo, required this.texto, required this.rapidos, required this.boton});
  final String titulo;
  final String texto;
  final List<String> rapidos;
  final String boton;

  @override
  State<_MotivoSheet> createState() => _MotivoSheetState();
}

class _MotivoSheetState extends State<_MotivoSheet> {
  final _ctrl = TextEditingController();
  String? _chip;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _motivo => [?_chip, if (_ctrl.text.trim().isNotEmpty) _ctrl.text.trim()].join('. ');

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(widget.titulo, textAlign: TextAlign.center, style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(widget.texto, textAlign: TextAlign.center, style: t.bodyMedium),
          if (widget.rapidos.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
              for (final m in widget.rapidos)
                ChoiceChip(
                  label: Text(m),
                  selected: _chip == m,
                  onSelected: (s) => setState(() => _chip = s ? m : null),
                ),
            ]),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            minLines: 2,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: widget.rapidos.isEmpty ? 'Motivo' : 'Detalle (opcional)',
            ),
          ),
          const SizedBox(height: 8),
          PopButton.danger(
            label: widget.boton,
            onPressed: _motivo.length < 3 ? null : () => Navigator.of(context).pop(_motivo),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
          ),
        ]),
      ),
    );
  }
}

class _ZoomScreen extends StatelessWidget {
  const _ZoomScreen({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Fz.tinta,
        appBar: AppBar(
          backgroundColor: Fz.tinta,
          foregroundColor: Fz.tarjeta,
          title: Text('Comprobante', style: Fz.display(19, color: Fz.tarjeta)),
        ),
        body: InteractiveViewer(
          minScale: 1,
          maxScale: 6,
          child: Center(child: Image.network(url, fit: BoxFit.contain)),
        ),
      );
}
