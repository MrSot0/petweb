import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/webp.dart';
import '../../core/widgets.dart';

/// Bancos emisores de Pago Móvil.
// TODO(por validar): lista y códigos de bancos tomados de memoria; confirmar con la organización / SUDEBAN.
const _bancos = <String>[
  '0102 Banco de Venezuela',
  '0104 Venezolano de Crédito',
  '0105 Mercantil',
  '0108 Provincial',
  '0114 Bancaribe',
  '0115 Exterior',
  '0128 Caroní',
  '0134 Banesco',
  '0138 Plaza',
  '0151 BFC',
  '0156 100% Banco',
  '0163 Banco del Tesoro',
  '0171 Activo',
  '0172 Bancamiga',
  '0174 Banplus',
  '0175 Bicentenario',
  '0177 Banfanb',
  '0191 BNC',
];

final _telRe = RegExp(r'^0(412|414|416|422|424|426)\d{7}$');
final _refRe = RegExp(r'^\d{4,12}$');

class RegistrarPagoScreen extends StatefulWidget {
  const RegistrarPagoScreen({super.key, required this.inscripcionIds});
  final List<String> inscripcionIds;

  @override
  State<RegistrarPagoScreen> createState() => _RegistrarPagoScreenState();
}

class _RegistrarPagoScreenState extends State<RegistrarPagoScreen> {
  final _form = GlobalKey<FormState>();
  final _ref = TextEditingController();
  final _tel = TextEditingController();

  List<Map<String, dynamic>>? _ins;
  List<Map<String, dynamic>> _cobro = [];
  Tasa? _tasa;
  Object? _error;

  String _metodo = 'pago_movil';
  String? _banco;
  DateTime _fecha = DateTime.now();

  WebpResult? _webp;
  bool _convirtiendo = false;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ref.dispose();
    _tel.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final todas = await Data.misInscripciones();
      final ids = widget.inscripcionIds.toSet();
      List<Map<String, dynamic>> cobro = [];
      try {
        cobro = (await Data.datosCobro()).where((d) => d['activo'] != false).toList();
      } catch (_) {}
      Tasa? tasa;
      try {
        tasa = await Data.tasaVigente();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _ins = todas.where((i) => ids.contains(i['id'])).toList();
        _cobro = cobro;
        _tasa = tasa;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  double get _totalUsd =>
      (_ins ?? []).fold<double>(0, (s, i) => s + ((i['precio_total_usd'] as num?)?.toDouble() ?? 0));

  Future<void> _foto(bool camara) async {
    try {
      final x = await WebpPipeline.elegir(camara: camara);
      if (x == null) return;
      setState(() {
        _convirtiendo = true;
        _webp = null;
      });
      final r = await WebpPipeline.convertir(x);
      if (mounted) setState(() => _webp = r);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _convirtiendo = false);
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime(hoy.year, hoy.month, hoy.day).subtract(const Duration(days: 7)),
      lastDate: hoy,
      helpText: 'Fecha del pago',
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _enviar() async {
    final pm = _metodo == 'pago_movil';
    if (pm) {
      if (!_form.currentState!.validate()) return;
      if (_webp == null) {
        showInfo(context, 'Adjunta el comprobante del Pago Móvil.');
        return;
      }
    }
    setState(() => _enviando = true);
    try {
      String? path;
      if (_webp != null) path = await Data.subirComprobante(Uint8List.fromList(_webp!.bytes));
      await Data.registrarPago(
        inscripciones: widget.inscripcionIds,
        metodo: _metodo,
        referencia: pm ? _ref.text.trim() : null,
        telefono: pm ? _tel.text.trim() : null,
        banco: pm ? _banco : null,
        fecha: pm ? _fecha : DateTime.now(),
        comprobantePath: path,
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const _PagoEnviado()));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Registrar pago')), body: _body(context));
  }

  Widget _body(BuildContext context) {
    if (_error != null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar el pago',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (_ins == null) return const Center(child: CircularProgressIndicator());
    if (_ins!.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No hay nada por pagar',
        message: 'Estas inscripciones ya no están pendientes de pago.',
        action: PopButton(label: 'Volver', onPressed: () => Navigator.pop(context), expand: false),
      );
    }
    final t = Theme.of(context).textTheme;
    final pm = _metodo == 'pago_movil';
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          _resumen(t),
          const SectionTitle('Método de pago'),
          Row(children: [
            Expanded(
              child: _MetodoCard(
                label: 'Pago Móvil',
                icon: Icons.phone_android_rounded,
                selected: pm,
                onTap: () => setState(() => _metodo = 'pago_movil'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetodoCard(
                label: 'Efectivo en divisas',
                icon: Icons.payments_rounded,
                selected: !pm,
                onTap: () => setState(() => _metodo = 'efectivo_divisa'),
              ),
            ),
          ]),
          if (pm) ..._pagoMovil(t) else ..._efectivo(t),
          const SizedBox(height: 24),
          PopButton(
            label: 'Enviar pago',
            icon: Icons.send_rounded,
            loading: _enviando,
            onPressed: _convirtiendo ? null : _enviar,
          ),
        ],
      ),
    );
  }

  Widget _resumen(TextTheme t) {
    final mascotas = _ins!.map((i) => (i['pets'] as Map?)?['nombre'] ?? 'Mascota').join(', ');
    final j = _ins!.first['jornadas'] as Map?;
    final tasa = _tasa;
    return PopCard(
      color: Fz.azulPastel,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Total a pagar', style: t.titleSmall),
        Text(Money.usd(_totalUsd), style: Fz.display(36)),
        if (tasa != null) Text(Money.bs(Money.aBs(_totalUsd, tasa.valor)), style: t.titleMedium),
        const SizedBox(height: 4),
        Text(
          tasa == null
              ? 'Tasa no disponible; el monto en Bs se confirma al pagar.'
              : tasa.vieja
                  ? 'Tasa del ${Money.fecha(tasa.fechaValor).substring(0, 5)}, puede variar.'
                  : 'Tasa BCV del euro ${Money.tasa(tasa.valor)} · fecha valor ${Money.fecha(tasa.fechaValor)}',
          style: t.bodySmall,
        ),
        const Divider(height: 20),
        Text(mascotas, style: t.bodyMedium),
        if (j != null) Text(j['titulo'] as String? ?? '', style: t.bodySmall),
      ]),
    );
  }

  List<Widget> _pagoMovil(TextTheme t) {
    final datos = _cobro.where((d) => d['tipo'] == 'pago_movil').toList();
    return [
      const SectionTitle('Paga a la organización'),
      if (datos.isEmpty)
        PopCard(
          color: Fz.rosaSuave,
          shadow: false,
          child: Row(children: [
            const Icon(Icons.info_outline_rounded),
            const SizedBox(width: 10),
            Expanded(child: Text('La organización aún no cargó sus datos de Pago Móvil', style: t.bodyMedium)),
          ]),
        )
      else
        for (final d in datos) ...[
          PopCard(
            shadow: false,
            padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
            child: Column(children: [
              for (final e in [
                ('Banco', d['banco']),
                ('Teléfono', d['telefono']),
                ('Cédula / RIF', d['cedula_rif']),
                ('Titular', d['titular']),
              ])
                if (e.$2 != null && '${e.$2}'.isNotEmpty) _CopyRow(label: e.$1, value: '${e.$2}'),
              if (d['instrucciones'] != null) Text('${d['instrucciones']}', style: t.bodySmall),
            ]),
          ),
          const SizedBox(height: 10),
        ],
      const SectionTitle('Datos de tu pago'),
      TextFormField(
        controller: _ref,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
        decoration: const InputDecoration(labelText: 'Número de referencia', helperText: 'Entre 4 y 12 dígitos'),
        validator: (v) => _refRe.hasMatch((v ?? '').trim()) ? null : 'La referencia debe tener de 4 a 12 dígitos',
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _tel,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
        decoration: const InputDecoration(labelText: 'Teléfono desde el que pagaste', hintText: '04141234567'),
        validator: (v) =>
            _telRe.hasMatch((v ?? '').trim()) ? null : 'Escribe un teléfono válido, por ejemplo 04141234567',
      ),
      const SizedBox(height: 14),
      DropdownButtonFormField<String>(
        initialValue: _banco,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Banco desde el que pagaste'),
        items: [for (final b in _bancos) DropdownMenuItem(value: b, child: Text(b))],
        onChanged: (v) => setState(() => _banco = v),
        validator: (v) => v == null ? 'Elige tu banco' : null,
      ),
      const SizedBox(height: 14),
      PopCard(
        shadow: false,
        onTap: _elegirFecha,
        child: Row(children: [
          const Icon(Icons.event_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Fecha del pago', style: t.bodySmall),
              Text(Money.fecha(_fecha), style: t.titleMedium),
            ]),
          ),
          const Icon(Icons.edit_calendar_rounded),
        ]),
      ),
      const SectionTitle('Comprobante'),
      ..._comprobante(t),
    ];
  }

  List<Widget> _efectivo(TextTheme t) {
    final datos = _cobro.where((d) => d['tipo'] == 'efectivo_divisa').toList();
    final textos = datos.map((d) => d['instrucciones'] as String?).whereType<String>().where((s) => s.isNotEmpty);
    return [
      const SectionTitle('Cómo pagar'),
      PopCard(
        shadow: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.payments_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              textos.isEmpty ? 'Entrega el monto exacto en dólares el día de la jornada.' : textos.join('\n'),
              style: t.bodyMedium,
            ),
          ),
        ]),
      ),
      const SectionTitle('Comprobante (opcional)'),
      ..._comprobante(t),
    ];
  }

  List<Widget> _comprobante(TextTheme t) => [
        Row(children: [
          Expanded(
            child: PopButton.tonal(
              label: 'Tomar foto',
              icon: Icons.photo_camera_rounded,
              onPressed: _convirtiendo || _enviando ? null : () => _foto(true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: PopButton.tonal(
              label: 'Galería',
              icon: Icons.photo_library_rounded,
              onPressed: _convirtiendo || _enviando ? null : () => _foto(false),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        if (_convirtiendo)
          Row(children: [
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: 10),
            Text('Optimizando para web (WebP)…', style: t.bodyMedium),
          ]),
        if (_webp != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(_webp!.bytes, height: 220, width: double.infinity, fit: BoxFit.cover),
          ),
          const SizedBox(height: 8),
          Row(children: [
            const Icon(Icons.check_circle_rounded, size: 20),
            const SizedBox(width: 6),
            Text(
              '${WebpPipeline.kb(_webp!.originalBytes)} → ${WebpPipeline.kb(_webp!.bytes.lengthInBytes)}',
              style: t.titleMedium,
            ),
          ]),
        ],
        const SizedBox(height: 6),
        Row(children: [
          const Icon(Icons.shield_outlined, size: 18, color: Fz.variante),
          const SizedBox(width: 6),
          Expanded(child: Text('Quitamos la ubicación y los datos de la cámara de la foto', style: t.bodySmall)),
        ]),
      ];
}

class _MetodoCard extends StatelessWidget {
  const _MetodoCard({required this.label, required this.icon, required this.selected, required this.onTap});
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: PopCard(
          onTap: onTap,
          color: selected ? Fz.rosa : Fz.cremaClaro,
          shadow: selected,
          child: SizedBox(
            height: 84,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(selected ? Icons.check_circle_rounded : icon, size: 28),
              const SizedBox(height: 4),
              Text(label, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
        ),
      );
}

class _CopyRow extends StatelessWidget {
  const _CopyRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Row(children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: t.bodySmall),
          Text(value, style: t.titleMedium),
        ]),
      ),
      IconButton(
        tooltip: 'Copiar $label',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.copy_rounded),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          if (context.mounted) showInfo(context, '$label copiado');
        },
      ),
    ]);
  }
}

class _PagoEnviado extends StatelessWidget {
  const _PagoEnviado();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).popUntil((r) => r.isFirst);
      },
      child: Scaffold(
        body: SafeArea(
          child: EmptyState(
            icon: Icons.check_circle_rounded,
            title: 'Pago enviado',
            message: 'Lo verificará el contador o la administración. Te avisaremos cuando esté listo.',
            action: PopButton(
              label: 'Listo',
              expand: false,
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            ),
          ),
        ),
      ),
    );
  }
}
