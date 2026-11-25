import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Convierte "1.008,65", "1008,65" o "1008.65" en número. Devuelve null si no es válido.
double? parseBs(String raw) {
  var s = raw.trim().replaceAll(' ', '').replaceAll('Bs', '');
  if (s.isEmpty) return null;
  if (s.contains(',')) {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  } else if ('.'.allMatches(s).length == 1 && s.split('.').last.length != 3) {
    // "1008.65": punto decimal
  } else {
    s = s.replaceAll('.', '');
  }
  return double.tryParse(s);
}

/// Tasa del euro BCV: vigente, carga manual e historial.
class TasaScreen extends StatefulWidget {
  const TasaScreen({super.key});

  @override
  State<TasaScreen> createState() => _TasaScreenState();
}

class _TasaScreenState extends State<TasaScreen> {
  Tasa? _tasa;
  List<Map<String, dynamic>>? _hist;
  Object? _error;
  bool _loading = true;

  final _form = GlobalKey<FormState>();
  final _valor = TextEditingController();
  final _motivo = TextEditingController();
  DateTime _fecha = _hoy();
  bool _saving = false;

  static DateTime _hoy() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _valor.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final r = await Future.wait([Data.tasaVigente(), Data.historialTasas()]);
      if (!mounted) return;
      setState(() {
        _tasa = r[0] as Tasa?;
        _hist = r[1] as List<Map<String, dynamic>>;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _loading = false;
        });
      }
    }
  }

  Future<void> _elegirFecha() async {
    final hoy = _hoy();
    final d = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: hoy.subtract(const Duration(days: 30)),
      lastDate: hoy.add(const Duration(days: 7)),
      helpText: 'Fecha valor de la tasa',
    );
    if (d != null) setState(() => _fecha = d);
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    final v = parseBs(_valor.text)!;
    setState(() => _saving = true);
    try {
      await Data.setTasaManual(v, _fecha, motivo: _motivo.text.trim().isEmpty ? null : _motivo.text.trim());
      if (!mounted) return;
      showInfo(context, 'Tasa guardada: ${Money.tasa(v)} por euro');
      _valor.clear();
      _motivo.clear();
      setState(() => _fecha = _hoy());
      FocusScope.of(context).unfocus();
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasa euro BCV')),
      body: _error != null && _hist == null
          ? EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar la tasa',
              message: friendlyError(_error!),
              action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
            )
          : _hist == null && _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(onRefresh: _load, child: _content()),
    );
  }

  Widget _content() {
    final t = Theme.of(context).textTheme;
    final tasa = _tasa;
    final preview = parseBs(_valor.text);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
      PopCard(
        color: Fz.azul,
        child: tasa == null
            ? Row(children: [
                const Icon(Icons.info_rounded, color: Fz.cremaClaro),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Aún no hay tasa cargada. Carga una abajo.',
                      style: t.titleMedium?.copyWith(color: Fz.cremaClaro)),
                ),
              ])
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('TASA VIGENTE · 1 EURO', style: t.titleSmall?.copyWith(color: Fz.cremaClaro, letterSpacing: .6)),
                const SizedBox(height: 4),
                Text(Money.tasa(tasa.valor), style: Fz.display(40, color: Fz.cremaClaro)),
                const SizedBox(height: 6),
                Text('Fecha valor ${Money.fecha(tasa.fechaValor)}',
                    style: t.bodyMedium?.copyWith(color: Fz.cremaClaro)),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  StatusPill(
                    tasa.manual ? 'Cargada a mano' : 'Automática (API)',
                    icon: tasa.manual ? Icons.edit_rounded : Icons.sync_rounded,
                    color: Fz.cremaClaro,
                  ),
                  if (tasa.vieja)
                    const StatusPill('Más de 36 h: puede variar', icon: Icons.warning_rounded, color: Fz.rosa),
                ]),
              ]),
      ),
      const SizedBox(height: 12),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.info_outline_rounded, size: 18, color: Fz.variante),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Mientras no esté activa la API, la tasa se carga a mano. Contador y administración pueden cargarla.',
            style: t.bodySmall,
          ),
        ),
      ]),
      const SectionTitle('Cargar tasa manual'),
      PopCard(
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _valor,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Bs por euro',
                hintText: '1.008,65',
                suffixText: 'Bs',
                helperText: 'Usa coma para los decimales.',
              ),
              onChanged: (_) => setState(() {}),
              validator: (v) {
                final n = parseBs(v ?? '');
                if (n == null) return 'Escribe un número, por ejemplo 1.008,65';
                if (n <= 0) return 'Debe ser mayor que cero';
                if (n > 1000000) return 'El valor parece demasiado alto';
                return null;
              },
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _elegirFecha,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Fecha valor',
                  suffixIcon: Icon(Icons.calendar_month_rounded),
                ),
                child: Text(Money.fecha(_fecha), style: t.bodyLarge),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _motivo,
              maxLength: 200,
              decoration: const InputDecoration(labelText: 'Motivo (opcional)', hintText: 'Publicada por el BCV hoy'),
            ),
            if (preview != null && preview > 0) ...[
              PopCard(
                color: Fz.azulPastel,
                shadow: false,
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Icon(Icons.calculate_rounded),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(r'$20 = ' '${Money.bs(Money.aBs(20, preview))}', style: t.titleMedium),
                  ),
                ]),
              ),
              const SizedBox(height: 14),
            ],
            PopButton(
              label: 'Guardar tasa',
              icon: Icons.save_rounded,
              loading: _saving,
              onPressed: _saving ? null : _guardar,
            ),
          ]),
        ),
      ),
      const SectionTitle('Historial'),
      if ((_hist ?? const []).isEmpty)
        Text('Sin registros todavía.', style: t.bodyMedium)
      else
        PopCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Column(children: [
            for (final (i, h) in _hist!.indexed) ...[
              if (i > 0) const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(Money.fecha(DateTime.parse(h['fecha_valor'] as String)), style: t.titleMedium),
                      if ((h['motivo'] as String?)?.isNotEmpty == true) Text(h['motivo'] as String, style: t.bodySmall),
                    ]),
                  ),
                  Text(Money.tasa((h['valor'] as num)), style: t.titleMedium),
                  const SizedBox(width: 10),
                  StatusPill(
                    h['manual'] == true ? 'Manual' : 'API',
                    icon: h['manual'] == true ? Icons.edit_rounded : Icons.sync_rounded,
                    dashed: h['manual'] == true,
                  ),
                ]),
              ),
            ],
          ]),
        ),
    ]);
  }
}
