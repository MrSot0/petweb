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

/// Deja solo dígitos (no rechaza lo pegado: lo limpia). En teléfonos convierte +58 414… en 0414….
class _SoloDigitos extends TextInputFormatter {
  _SoloDigitos(this.max, {this.telefono = false});
  final int max;
  final bool telefono;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var d = newValue.text.replaceAll(RegExp(r'\D'), '');
    if (telefono) d = _normalizarTel(d);
    if (d.length > max) d = d.substring(0, max);
    if (d == newValue.text) return newValue;
    return TextEditingValue(text: d, selection: TextSelection.collapsed(offset: d.length));
  }
}

String _normalizarTel(String d) {
  if (d.startsWith('58') && d.length == 12) return '0${d.substring(2)}';
  if (d.length == 10 && d.startsWith('4')) return '0$d';
  return d;
}

/// Monto en formato venezolano ("1.234,56", "1234.56", "1234,5") → double.
double? _parseMonto(String s) {
  var x = s.trim().replaceAll(RegExp(r'[^\d.,]'), '');
  if (x.isEmpty) return null;
  if (x.contains(',')) {
    x = x.replaceAll('.', '').replaceAll(',', '.');
  } else if (RegExp(r'\.\d{3}(\.|$)').hasMatch(x) && !RegExp(r'\.\d{1,2}$').hasMatch(x)) {
    x = x.replaceAll('.', '');
  }
  return double.tryParse(x);
}

String _montoTexto(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

/// Datos encontrados en el texto de un SMS o notificación del banco.
class DatosPagoPegados {
  DatosPagoPegados({this.referencia, this.telefono, this.monto, this.banco});
  final String? referencia;
  final String? telefono;
  final double? monto;
  final String? banco;
  bool get vacio => referencia == null && telefono == null && monto == null && banco == null;
}

const _aliasBancos = <String, List<String>>{
  '0102': ['banco de venezuela', 'bdv', '0102'],
  '0104': ['venezolano de credito', 'venezolano de crédito', '0104'],
  '0105': ['mercantil', '0105'],
  '0108': ['provincial', 'bbva', '0108'],
  '0114': ['bancaribe', '0114'],
  '0115': ['exterior', '0115'],
  '0128': ['caroni', 'caroní', '0128'],
  '0134': ['banesco', '0134'],
  '0138': ['banco plaza', '0138'],
  '0151': ['bfc', 'fondo comun', 'fondo común', '0151'],
  '0156': ['100% banco', '100 % banco', '0156'],
  '0163': ['tesoro', '0163'],
  '0171': ['banco activo', '0171'],
  '0172': ['bancamiga', '0172'],
  '0174': ['banplus', '0174'],
  '0175': ['bicentenario', '0175'],
  '0177': ['banfanb', '0177'],
  '0191': ['bnc', 'nacional de credito', 'nacional de crédito', '0191'],
};

/// Extrae referencia, teléfono, monto en Bs y banco del texto pegado.
DatosPagoPegados extraerDatosPago(String texto) {
  final tx = texto.replaceAll('\n', ' ');
  final low = tx.toLowerCase();

  // Teléfono 04xx… (o +58 4xx…), con o sin separadores.
  String? tel;
  final tm = RegExp(r'(?<!\d)(?:\+?58[\s.-]?|0)(4(?:12|14|16|22|24|26))[\s.-]?(\d{3})[\s.-]?(\d{4})(?!\d)').firstMatch(tx);
  if (tm != null) tel = '0${tm.group(1)}${tm.group(2)}${tm.group(3)}';

  // Referencia: 4–12 dígitos tras Ref / Referencia / Nro / Operación / Comprobante.
  String? ref;
  final rr = RegExp(
    r'(?:ref(?:erencia)?|nro|n[°º]|n[uú]m(?:ero)?|operaci[oó]n|comprobante|confirmaci[oó]n)\.?\s*'
    r'(?:de\s+)?(?:operaci[oó]n|ref(?:erencia)?)?\.?\s*[:#]?\s*(\d[\d\s-]{2,16}\d)',
    caseSensitive: false,
  );
  for (final m in rr.allMatches(tx)) {
    final d = m.group(1)!.replaceAll(RegExp(r'\D'), '');
    if (d.length < 4 || d.length > 12) continue;
    if (tel != null && (d == tel || d == tel.substring(1))) continue;
    if (_telRe.hasMatch(_normalizarTel(d))) continue;
    ref = d;
    break;
  }

  // Monto en Bs: "Bs 1.234,56", "Bs. 1234,56", "1.234,56 Bs", "monto: 1234,56".
  double? monto;
  final mm = RegExp(r'(?:bs\.?\s*s?\.?|ves|monto(?:\s+de)?)\s*[:]?\s*(\d[\d.,]*\d|\d)', caseSensitive: false).firstMatch(tx) ??
      RegExp(r'(\d[\d.,]*\d|\d)\s*(?:bs\b|bs\.|ves\b)', caseSensitive: false).firstMatch(tx);
  if (mm != null) monto = _parseMonto(mm.group(1)!);
  if (monto != null && monto <= 0) monto = null;

  // Banco por nombre o código.
  String? banco;
  for (final e in _aliasBancos.entries) {
    if (e.value.any((a) => a.length == 4 ? RegExp('(?<!\\d)$a(?!\\d)').hasMatch(low) : low.contains(a))) {
      banco = _bancos.firstWhere((b) => b.startsWith(e.key));
      break;
    }
  }
  return DatosPagoPegados(referencia: ref, telefono: tel, monto: monto, banco: banco);
}

/// Registrar el pago de inscripciones a una jornada o, con [visita], de una visita a domicilio.
class RegistrarPagoScreen extends StatefulWidget {
  const RegistrarPagoScreen({super.key, this.inscripcionIds = const [], this.visita});
  final List<String> inscripcionIds;

  /// Fila de `Data.misVisitas()` (id, codigo, precio_usd, servicios_domicilio{nombre}).
  final Map<String, dynamic>? visita;

  @override
  State<RegistrarPagoScreen> createState() => _RegistrarPagoScreenState();
}

class _RegistrarPagoScreenState extends State<RegistrarPagoScreen> {
  final _form = GlobalKey<FormState>();
  final _ref = TextEditingController();
  final _tel = TextEditingController();
  final _monto = TextEditingController();

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
    _monto.dispose();
    super.dispose();
  }

  bool get _modoVisita => widget.visita != null;

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final todas = _modoVisita ? <Map<String, dynamic>>[] : await Data.misInscripciones();
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

  double get _totalUsd => _modoVisita
      ? ((widget.visita!['precio_usd'] as num?)?.toDouble() ?? 0)
      : (_ins ?? []).fold<double>(0, (s, i) => s + ((i['precio_total_usd'] as num?)?.toDouble() ?? 0));

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

  Future<String?> _leerPortapapeles() async {
    try {
      final d = await Clipboard.getData(Clipboard.kTextPlain);
      final tx = d?.text?.trim();
      if (tx == null || tx.isEmpty) {
        if (mounted) showInfo(context, 'No hay texto copiado.');
        return null;
      }
      return tx;
    } catch (_) {
      if (mounted) showInfo(context, 'No pudimos leer lo que copiaste.');
      return null;
    }
  }

  Future<void> _pegarEn(TextEditingController c, {required bool telefono}) async {
    final tx = await _leerPortapapeles();
    if (tx == null) return;
    final datos = extraerDatosPago(tx);
    String v;
    if (telefono) {
      v = datos.telefono ?? _normalizarTel(tx.replaceAll(RegExp(r'\D'), ''));
      if (v.length > 11) v = v.substring(0, 11);
    } else {
      final solo = tx.replaceAll(RegExp(r'\D'), '');
      v = datos.referencia ?? (solo.length > 12 ? solo.substring(solo.length - 12) : solo);
    }
    setState(() => c.text = v);
    _form.currentState?.validate();
  }

  Future<void> _pegarMonto() async {
    final tx = await _leerPortapapeles();
    if (tx == null) return;
    final m = extraerDatosPago(tx).monto ?? _parseMonto(tx);
    if (m == null) {
      if (mounted) showInfo(context, 'No encontramos un monto en lo que copiaste.');
      return;
    }
    setState(() => _monto.text = _montoTexto(m));
  }

  Future<void> _pegarDatos() async {
    final tx = await _leerPortapapeles();
    if (tx == null || !mounted) return;
    final d = extraerDatosPago(tx);
    if (d.vacio) {
      showInfo(context, 'No encontramos datos del pago en lo que copiaste. Escríbelos a mano.');
      return;
    }
    final t = Theme.of(context).textTheme;
    Widget fila(IconData ic, String l, String? v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(children: [
            Icon(v == null ? Icons.remove_circle_outline_rounded : ic, size: 20, color: v == null ? Fz.variante : Fz.azul),
            const SizedBox(width: 8),
            Expanded(child: Text(l, style: t.bodySmall)),
            Text(v ?? 'No encontrado', style: v == null ? t.bodySmall : t.titleSmall),
          ]),
        );
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.content_paste_search_rounded, size: 40, color: Fz.azul),
        title: const Text('Datos encontrados'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Revisa que coincidan con tu comprobante.', textAlign: TextAlign.center, style: t.bodyMedium),
          const SizedBox(height: 10),
          fila(Icons.tag_rounded, 'Referencia', d.referencia),
          fila(Icons.phone_android_rounded, 'Teléfono', d.telefono),
          fila(Icons.payments_rounded, 'Monto', d.monto == null ? null : 'Bs ${_montoTexto(d.monto!)}'),
          fila(Icons.account_balance_rounded, 'Banco', d.banco),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Usar estos datos')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      if (d.referencia != null) _ref.text = d.referencia!;
      if (d.telefono != null) _tel.text = d.telefono!;
      if (d.monto != null) _monto.text = _montoTexto(d.monto!);
      if (d.banco != null) _banco = d.banco;
    });
    _form.currentState?.validate();
  }

  Widget _botonPegar(VoidCallback onTap, String que) => IconButton(
        tooltip: 'Pegar $que',
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.content_paste_rounded),
        onPressed: onTap,
      );

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
    if (pm && !_form.currentState!.validate()) return;
    if (_webp == null) {
      showInfo(context, pm ? 'Adjunta el comprobante del Pago Móvil.' : 'Adjunta la foto del recibo o de los billetes.');
      return;
    }
    setState(() => _enviando = true);
    try {
      final path = await Data.subirComprobante(Uint8List.fromList(_webp!.bytes));
      if (_modoVisita) {
        await Data.registrarPagoVisita(
          visitaId: widget.visita!['id'] as String,
          metodo: _metodo,
          referencia: pm ? _ref.text.trim() : null,
          telefono: pm ? _tel.text.trim() : null,
          banco: pm ? _banco : null,
          fecha: pm ? _fecha : DateTime.now(),
          comprobantePath: path,
        );
      } else {
        await Data.registrarPago(
          inscripciones: widget.inscripcionIds,
          metodo: _metodo,
          referencia: pm ? _ref.text.trim() : null,
          telefono: pm ? _tel.text.trim() : null,
          banco: pm ? _banco : null,
          fecha: pm ? _fecha : DateTime.now(),
          comprobantePath: path,
        );
      }
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
    if (!_modoVisita && _ins!.isEmpty) {
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
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _resumen(t),
          const _Titulo('Método de pago'),
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
          if (_webp == null) ...[
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.lock_rounded, size: 18, color: Fz.variante),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  pm
                      ? 'Adjunta el comprobante del Pago Móvil para poder enviar.'
                      : 'Adjunta la foto del recibo o de los billetes para poder enviar.',
                  textAlign: TextAlign.center,
                  style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ]),
            const SizedBox(height: 10),
          ],
          PopButton(
            label: 'Enviar pago',
            icon: Icons.send_rounded,
            loading: _enviando,
            onPressed: _convirtiendo || _webp == null ? null : _enviar,
          ),
        ]),
      ),
    );
  }

  /// Compara el monto escrito con el total esperado en Bs (solo como ayuda).
  String _ayudaMonto() {
    final tasa = _tasa;
    final esperado = tasa == null ? null : Money.aBs(_totalUsd, tasa.valor);
    if (esperado == null) return 'Para que compares con tu comprobante.';
    final m = _parseMonto(_monto.text);
    if (m == null) return 'Total esperado: ${Money.bs(esperado)}';
    if ((m - esperado).abs() <= 1) return 'Coincide con el total esperado (${Money.bs(esperado)}).';
    return 'Ojo: el total esperado es ${Money.bs(esperado)}.';
  }

  Widget _resumen(TextTheme t) {
    final v = widget.visita;
    final mascotas = v != null
        ? ((v['servicios_domicilio'] as Map?)?['nombre'] as String? ?? 'Visita a domicilio')
        : _ins!.map((i) => (i['pets'] as Map?)?['nombre'] ?? 'Mascota').join(', ');
    final j = v != null
        ? (v['codigo'] == null ? null : {'titulo': 'Visita ${v['codigo']}'})
        : _ins!.first['jornadas'] as Map?;
    final tasa = _tasa;
    return FzHero(
      title: Money.usd(_totalUsd),
      subtitle: 'Total a pagar',
      leading: const Icon(Icons.payments_rounded, size: 32, color: Fz.tarjeta),
      child: Column(children: [
        if (tasa != null)
          Text(Money.bs(Money.aBs(_totalUsd, tasa.valor)),
              textAlign: TextAlign.center, style: t.titleLarge?.copyWith(color: Fz.tarjeta)),
        const SizedBox(height: 4),
        Text(
          textAlign: TextAlign.center,
          tasa == null
              ? 'Tasa no disponible; el monto en Bs se confirma al pagar.'
              : tasa.vieja
                  ? 'Tasa del ${Money.fecha(tasa.fechaValor).substring(0, 5)}, puede variar.'
                  : 'Tasa BCV del euro ${Money.tasa(tasa.valor)} · fecha valor ${Money.fecha(tasa.fechaValor)}',
          style: t.bodySmall?.copyWith(color: Fz.azul50),
        ),
        const SizedBox(height: 10),
        Text(mascotas, textAlign: TextAlign.center, style: t.titleSmall?.copyWith(color: Fz.tarjeta)),
        if (j != null)
          Text(j['titulo'] as String? ?? '', textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: Fz.azul50)),
      ]),
    );
  }

  List<Widget> _pagoMovil(TextTheme t) {
    final datos = _cobro.where((d) => d['tipo'] == 'pago_movil').toList();
    return [
      const _Titulo('Paga a la organización'),
      if (datos.isEmpty)
        PopCard(
          color: Fz.azul50,
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
            color: Fz.azul50,
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
      const _Titulo('Datos de tu pago'),
      PopButton.tonal(
        label: 'Pegar datos del pago',
        icon: Icons.content_paste_go_rounded,
        onPressed: _enviando ? null : _pegarDatos,
      ),
      const SizedBox(height: 6),
      Text('Copia el SMS o la notificación de tu banco y tócalo: llenamos referencia, teléfono, monto y banco.',
          textAlign: TextAlign.center, style: t.bodySmall),
      const SizedBox(height: 14),
      TextFormField(
        controller: _ref,
        keyboardType: TextInputType.number,
        enableInteractiveSelection: true,
        inputFormatters: [_SoloDigitos(12)],
        decoration: InputDecoration(
          labelText: 'Número de referencia',
          helperText: 'Entre 4 y 12 dígitos',
          suffixIcon: _botonPegar(() => _pegarEn(_ref, telefono: false), 'referencia'),
        ),
        validator: (v) => _refRe.hasMatch((v ?? '').trim()) ? null : 'La referencia debe tener de 4 a 12 dígitos',
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _tel,
        keyboardType: TextInputType.phone,
        enableInteractiveSelection: true,
        inputFormatters: [_SoloDigitos(11, telefono: true)],
        decoration: InputDecoration(
          labelText: 'Teléfono desde el que pagaste',
          hintText: '04141234567',
          suffixIcon: _botonPegar(() => _pegarEn(_tel, telefono: true), 'teléfono'),
        ),
        validator: (v) =>
            _telRe.hasMatch((v ?? '').trim()) ? null : 'Escribe un teléfono válido, por ejemplo 04141234567',
      ),
      const SizedBox(height: 14),
      TextFormField(
        controller: _monto,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        enableInteractiveSelection: true,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: 'Monto pagado en Bs (opcional)',
          prefixText: 'Bs ',
          helperText: _ayudaMonto(),
          helperMaxLines: 2,
          suffixIcon: _botonPegar(_pegarMonto, 'monto'),
        ),
        validator: (v) {
          final s = (v ?? '').trim();
          if (s.isEmpty) return null;
          final m = _parseMonto(s);
          return m == null || m <= 0 ? 'Escribe el monto, por ejemplo 1.234,56' : null;
        },
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
      const _Titulo('Comprobante'),
      Text('Captura o foto del comprobante del Pago Móvil. Es obligatoria.',
          textAlign: TextAlign.center, style: t.bodySmall),
      const SizedBox(height: 10),
      ..._comprobante(t),
    ];
  }

  List<Widget> _efectivo(TextTheme t) {
    final datos = _cobro.where((d) => d['tipo'] == 'efectivo_divisa').toList();
    final textos = datos.map((d) => d['instrucciones'] as String?).whereType<String>().where((s) => s.isNotEmpty);
    return [
      const _Titulo('Cómo pagar'),
      PopCard(
        shadow: false,
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.payments_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              textos.isEmpty
                  ? (_modoVisita
                      ? 'Entrega el monto exacto en dólares al veterinario o a la administración.'
                      : 'Entrega el monto exacto en dólares el día de la jornada.')
                  : textos.join('\n'),
              style: t.bodyMedium,
            ),
          ),
        ]),
      ),
      const _Titulo('Comprobante'),
      Text('Toma una foto del recibo o de los billetes que entregaste. Es obligatoria.',
          textAlign: TextAlign.center, style: t.bodySmall),
      const SizedBox(height: 10),
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
          color: selected ? Fz.azul : Fz.tarjeta,
          shadow: selected,
          child: SizedBox(
            height: 80,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(selected ? Icons.check_circle_rounded : icon, size: 26, color: selected ? Fz.tarjeta : Fz.tinta),
              const SizedBox(height: 4),
              Text(label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: selected ? Fz.tarjeta : Fz.tinta)),
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

class _Titulo extends StatelessWidget {
  const _Titulo(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Text(text, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      );
}
