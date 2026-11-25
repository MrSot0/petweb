import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Lista oficial de precios, consideraciones, métodos de pago y calculadora.
class PreciosScreen extends StatefulWidget {
  const PreciosScreen({super.key});

  @override
  State<PreciosScreen> createState() => _PreciosScreenState();
}

class _PreciosScreenState extends State<PreciosScreen> with SingleTickerProviderStateMixin {
  late Future<(Precios, Tasa?, bool)> _f = _load();
  late final TabController _tabs = TabController(length: 3, vsync: this)..addListener(_onTab);

  // Calculadora
  String _especie = 'perro';
  String _sexo = 'hembra';
  final _peso = TextEditingController(text: '12');
  bool _kit = true;
  bool _cono = false;
  bool _braqui = false;

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  @override
  void dispose() {
    _tabs.dispose();
    _peso.dispose();
    super.dispose();
  }

  Future<(Precios, Tasa?, bool)> _load() async {
    final pF = Data.precios();
    Tasa? tasa;
    var tasaError = false;
    try {
      tasa = await Data.tasaVigente();
    } catch (_) {
      tasaError = true;
    }
    return (await pF, tasa, tasaError);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Precios')),
      body: FutureBuilder<(Precios, Tasa?, bool)>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar los precios',
              message: friendlyError(snap.error!),
              action: PopButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: _refresh, expand: false),
            );
          }
          final (p, tasa, tasaError) = snap.data!;
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                _tasaCard(context, tasa, tasaError),
                const SectionTitle('Calcula tu precio'),
                _calculadora(context, p, tasa),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: Fz.cremaClaro,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Fz.tinta, width: 2),
                  ),
                  child: TabBar(
                    controller: _tabs,
                    indicator: BoxDecoration(
                      color: Fz.rosa,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Fz.tinta, width: 2),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelColor: Fz.tinta,
                    unselectedLabelColor: Fz.variante,
                    labelStyle: Fz.display(15, w: FontWeight.w700),
                    tabs: const [Tab(text: 'Gatos'), Tab(text: 'Perros'), Tab(text: 'Limpieza dental')],
                  ),
                ),
                const SizedBox(height: 14),
                switch (_tabs.index) {
                  0 => _gatos(context, p, tasa),
                  1 => _perros(context, p, tasa),
                  _ => _dental(context, p, tasa),
                },
                const SectionTitle('Antes de inscribir'),
                _consideraciones(context),
                const SectionTitle('Cómo pagar'),
                _metodos(context),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---------- Tasa ----------
  Widget _tasaCard(BuildContext context, Tasa? tasa, bool error) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: Fz.azulPastel,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.currency_exchange_rounded, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tasa euro BCV', style: t.titleMedium),
            if (tasa != null) ...[
              Text('${Money.tasa(tasa.valor)} · fecha valor ${Money.fecha(tasa.fechaValor)}', style: t.bodyLarge),
              if (tasa.vieja)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: StatusPill('Tasa del ${DateFormat('dd/MM').format(tasa.fechaValor)}, puede variar',
                      icon: Icons.warning_amber_rounded, color: Fz.rosaSuave, dashed: true),
                ),
            ] else
              Text(
                error
                    ? 'No pudimos actualizar la tasa. Los precios en \$ no cambian; el monto en Bs se confirma al pagar.'
                    : 'Tasa no disponible; el monto en Bs se confirma al pagar.',
                style: t.bodyMedium,
              ),
          ]),
        ),
        if (error) IconButton(tooltip: 'Reintentar', onPressed: _refresh, icon: const Icon(Icons.refresh_rounded)),
      ]),
    );
  }

  String _bs(Tasa? tasa, double? usd) => tasa == null || usd == null ? '' : Money.bs(Money.aBs(usd, tasa.valor));

  // ---------- Calculadora ----------
  Widget _calculadora(BuildContext context, Precios p, Tasa? tasa) {
    final t = Theme.of(context).textTheme;
    final perro = _especie == 'perro';
    final peso = double.tryParse(_peso.text.replaceAll(',', '.'));
    final pet = Pet({
      'id': '',
      'nombre': '',
      'especie': _especie,
      'sexo': _sexo,
      'peso_kg': perro ? peso : null,
      'braquiocefalico': _braqui,
    });
    final faltaPeso = perro && (peso == null || peso <= 0);
    final base = faltaPeso ? null : p.base('esterilizacion', pet);
    final kit = p.extra('kit', _especie);
    final cono = p.extra('cono', _especie);
    final total = base == null ? null : base + (_kit ? kit : 0) + (_cono ? cono : 0);

    Widget chips<T>(List<(T, String)> ops, T sel, ValueChanged<T> on) => Wrap(spacing: 8, children: [
          for (final (v, l) in ops)
            ChoiceChip(label: Text(l), selected: sel == v, onSelected: (_) => setState(() => on(v))),
        ]);

    return PopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        chips<String>([('gato', 'Gato'), ('perro', 'Perro')], _especie, (v) => _especie = v),
        const SizedBox(height: 8),
        chips<String>([('macho', 'Macho'), ('hembra', 'Hembra')], _sexo, (v) => _sexo = v),
        if (perro) ...[
          const SizedBox(height: 14),
          TextField(
            controller: _peso,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), LengthLimitingTextInputFormatter(5)],
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Peso en kg',
              suffixText: 'kg',
              prefixIcon: const Icon(Icons.monitor_weight_rounded),
              errorText: faltaPeso ? 'Escribe el peso de tu perro.' : null,
            ),
          ),
        ],
        CheckboxListTile(
          value: _braqui,
          onChanged: (v) => setState(() => _braqui = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text('Hocico corto (pug, bulldog, persa…)', style: t.titleSmall),
        ),
        CheckboxListTile(
          value: _kit,
          onChanged: (v) => setState(() => _kit = v ?? true),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text('Kit post-operatorio +${Money.usd(kit)}', style: t.titleSmall),
          subtitle: Text(
            _kit
                ? 'Recomendado. Trae los medicamentos de los primeros días.'
                : 'Sin el kit tendrás que comprar los medicamentos por tu cuenta.',
            style: t.bodySmall?.copyWith(fontWeight: _kit ? null : FontWeight.w700, color: _kit ? null : Fz.tinta),
          ),
          secondary: const StatusPill('Recomendado', icon: Icons.thumb_up_rounded, color: Fz.rosa),
        ),
        CheckboxListTile(
          value: _cono,
          onChanged: (v) => setState(() => _cono = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: Text('Agregar cono +${Money.usd(cono)} (opcional)', style: t.titleSmall),
        ),
        const Divider(height: 20),
        if (faltaPeso)
          Text('Escribe el peso para calcular el precio.', style: t.bodyMedium)
        else if (total == null)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.hourglass_top_rounded),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'A convenir: la administración te confirma el precio antes de pagar.',
                style: t.titleMedium,
              ),
            ),
          ])
        else ...[
          Text(_kit ? 'Con kit recomendado' : 'Sin kit', style: t.bodySmall),
          Text(Money.usd(total), style: Fz.display(36)),
          Text(tasa == null ? 'Bs por confirmar al pagar' : _bs(tasa, total), style: t.titleMedium),
          const SizedBox(height: 4),
          Text('Precio base ${Money.usd(base)} · Con kit recomendado ${Money.usd(base! + kit)}', style: t.bodySmall),
        ],
      ]),
    );
  }

  // ---------- Tablas ----------
  List<Map<String, dynamic>> _filas(Precios p, String servicio, String especie, {String? sexo}) => p.filas
      .where((f) => f['servicio'] == servicio && f['especie'] == especie && (sexo == null || f['sexo'] == sexo))
      .toList()
    ..sort((a, b) => ((a['peso_hasta'] as num?) ?? 9999).compareTo((b['peso_hasta'] as num?) ?? 9999));

  String _rango(List<Map<String, dynamic>> filas, int i) {
    final hasta = (filas[i]['peso_hasta'] as num?)?.toDouble();
    String kg(double v) => '${NumberFormat('#,##0.#', 'es').format(v)} kg';
    if (hasta == null) return 'Cualquier peso';
    if (i == 0) return 'Hasta ${kg(hasta)}';
    final prev = (filas[i - 1]['peso_hasta'] as num).toDouble();
    return '${kg(prev + .1).replaceAll(' kg', '')} a ${kg(hasta)}';
  }

  Widget _precio(BuildContext context, Tasa? tasa, double v, {String? pre, bool fuerte = true}) {
    final t = Theme.of(context).textTheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text('${pre ?? ''}${Money.usd(v)}', style: fuerte ? Fz.display(18, w: FontWeight.w700) : t.titleSmall),
      if (tasa != null) Text(_bs(tasa, v), style: t.bodySmall),
    ]);
  }

  Widget _gatos(BuildContext context, Precios p, Tasa? tasa) {
    final t = Theme.of(context).textTheme;
    final kit = p.extra('kit', 'gato');
    final cono = p.extra('cono', 'gato');
    Widget fila(String sexo, String nombre) {
      final f = _filas(p, 'esterilizacion', 'gato', sexo: sexo);
      if (f.isEmpty) return const SizedBox.shrink();
      final b = (f.first['precio_usd'] as num).toDouble();
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          Icon(sexo == 'macho' ? Icons.male_rounded : Icons.female_rounded),
          const SizedBox(width: 6),
          Expanded(child: Text(nombre, style: t.titleMedium)),
          Expanded(child: Align(alignment: Alignment.centerRight, child: _precio(context, tasa, b))),
          const SizedBox(width: 12),
          Expanded(child: Align(alignment: Alignment.centerRight, child: _precio(context, tasa, b + kit))),
        ]),
      );
    }

    return PopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Esterilización · Gatos', style: t.titleLarge),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Gato', style: t.bodySmall)),
          Expanded(child: Text('Precio base', textAlign: TextAlign.right, style: t.bodySmall)),
          const SizedBox(width: 12),
          Expanded(child: Text('Con kit recomendado', textAlign: TextAlign.right, style: t.bodySmall)),
        ]),
        const Divider(),
        fila('macho', 'Macho'),
        fila('hembra', 'Hembra'),
        const Divider(),
        _nota(context, Icons.add_circle_rounded,
            'Kit post-operatorio recomendado: +${Money.usd(kit)}. Cono para gato: +${Money.usd(cono)}${tasa != null ? ' (${_bs(tasa, cono)})' : ''}, opcional.'),
      ]),
    );
  }

  Widget _perros(BuildContext context, Precios p, Tasa? tasa) {
    final t = Theme.of(context).textTheme;
    final kit = p.extra('kit', 'perro');
    final cono = p.extra('cono', 'perro');
    final machos = _filas(p, 'esterilizacion', 'perro', sexo: 'macho');
    final hembras = _filas(p, 'esterilizacion', 'perro', sexo: 'hembra');
    final ref = machos.length >= hembras.length ? machos : hembras;
    double? valor(List<Map<String, dynamic>> l, num? hasta) {
      for (final f in l) {
        if (f['peso_hasta'] == hasta) return (f['precio_usd'] as num).toDouble();
      }
      return null;
    }

    Widget celda(double? v) => v == null
        ? Text('—', textAlign: TextAlign.right, style: t.bodyMedium)
        : Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            _precio(context, tasa, v),
            const SizedBox(height: 2),
            _precio(context, tasa, v + kit, pre: 'Con kit ', fuerte: false),
          ]);

    return PopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Esterilización · Perros', style: t.titleLarge),
        Text('Precio base según peso y, debajo, con kit post-operatorio recomendado (+${Money.usd(kit)})', style: t.bodySmall),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Peso', style: t.bodySmall)),
          Expanded(child: Text('Macho', textAlign: TextAlign.right, style: t.bodySmall)),
          const SizedBox(width: 12),
          Expanded(child: Text('Hembra', textAlign: TextAlign.right, style: t.bodySmall)),
        ]),
        const Divider(),
        for (var i = 0; i < ref.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Text(_rango(ref, i), style: t.titleSmall)),
              Expanded(child: celda(valor(machos, ref[i]['peso_hasta'] as num?))),
              const SizedBox(width: 12),
              Expanded(child: celda(valor(hembras, ref[i]['peso_hasta'] as num?))),
            ]),
          ),
          if (i < ref.length - 1) const Divider(height: 4),
        ],
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text('Más de 30 kg', style: t.titleSmall)),
            const StatusPill('A convenir', icon: Icons.hourglass_top_rounded, color: Fz.rosaSuave, dashed: true),
          ]),
        ),
        const SizedBox(height: 6),
        _nota(context, Icons.add_circle_rounded,
            'Cono para perro: +${Money.usd(cono)}${tasa != null ? ' (${_bs(tasa, cono)})' : ''}, opcional.'),
      ]),
    );
  }

  Widget _dental(BuildContext context, Precios p, Tasa? tasa) {
    final t = Theme.of(context).textTheme;
    final gatos = _filas(p, 'limpieza_dental', 'gato');
    final perros = _filas(p, 'limpieza_dental', 'perro');
    Widget fila(String n, double v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text(n, style: t.titleSmall)),
            _precio(context, tasa, v),
          ]),
        );
    return PopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Limpieza dental', style: t.titleLarge),
        Text('Con pulitura de esmalte', style: t.bodySmall),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: Text('Paciente', style: t.bodySmall)),
          Text('Precio', style: t.bodySmall),
        ]),
        const Divider(),
        for (final g in gatos) fila('Gatos', (g['precio_usd'] as num).toDouble()),
        for (var i = 0; i < perros.length; i++)
          fila(i == 0 ? 'Perros ${_rango(perros, i).toLowerCase()}' : _rango(perros, i), (perros[i]['precio_usd'] as num).toDouble()),
        const Divider(),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            Expanded(child: Text('Perros de más de 30 kg', style: t.titleSmall)),
            const StatusPill('A convenir', icon: Icons.hourglass_top_rounded, color: Fz.rosaSuave, dashed: true),
          ]),
        ),
        const SizedBox(height: 4),
        Text('Solo en las jornadas que la incluyen.', style: t.bodySmall),
      ]),
    );
  }

  // ---------- Consideraciones y pago ----------
  Widget _consideraciones(BuildContext context) => PopCard(
        color: Fz.rosaSuave,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _nota(context, Icons.pets_rounded,
              'Braquiocefálicos (hocico corto: pug, bulldog, persa…): precio a acordar según peso y raza.'),
          _nota(context, Icons.health_and_safety_rounded, 'Precios válidos solo para animales sanos.'),
          _nota(context, Icons.priority_high_rounded,
              'Patologías reproductivas (piometra, parto difícil, TVT, testículo ectópico): se paga el doble según especie y peso. Lo decide el cirujano.'),
          _nota(context, Icons.medical_services_rounded, 'Prolapsos: no entran en la regla del doble; requieren evaluación especial.'),
          const SizedBox(height: 6),
          Text('En los casos a convenir, el administrador te confirma el precio antes de pagar.',
              style: Theme.of(context).textTheme.bodySmall),
        ]),
      );

  Widget _metodos(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget m(IconData ic, String titulo, String tx) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Fz.azulPastel,
                shape: BoxShape.circle,
                border: Border.all(color: Fz.tinta, width: 2),
              ),
              child: Icon(ic),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(titulo, style: t.titleMedium),
                Text(tx, style: t.bodyMedium),
              ]),
            ),
          ]),
        );
    return PopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        m(Icons.payments_rounded, 'Divisas', 'En efectivo, el día de la jornada en la sede.'),
        m(Icons.smartphone_rounded, 'Pago Móvil', 'En Bs con la tasa euro BCV. Subes el comprobante.'),
        const Divider(height: 20),
        _nota(context, Icons.verified_user_rounded,
            'El contador o el administrador verifica tu pago y te avisamos cuando tu cupo esté confirmado.'),
      ]),
    );
  }

  Widget _nota(BuildContext context, IconData ic, String tx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(tx, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}
