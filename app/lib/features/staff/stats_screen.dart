import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

double _n(dynamic v) => v is num ? v.toDouble() : (double.tryParse(v?.toString() ?? '') ?? 0);
Map<String, dynamic> _m(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

String _entero(double v) => v.round().toString();

/// Estadísticas de una jornada (jornadaId) o globales (null), con gráficos en la escala azul.
/// Admin y contador ven además los ingresos; el cirujano solo ve mascotas.
class EstadisticasScreen extends StatefulWidget {
  const EstadisticasScreen({super.key, this.jornadaId, this.embebida = false});

  /// Jornada fija. Si es null se muestra la vista global con selector de jornada.
  final String? jornadaId;

  /// true cuando se muestra dentro de otra pantalla (pestaña): sin AppBar propia.
  final bool embebida;

  @override
  State<EstadisticasScreen> createState() => _EstadisticasScreenState();
}

class _EstadisticasScreenState extends State<EstadisticasScreen> with AutomaticKeepAliveClientMixin {
  String? _sel; // jornada elegida en la vista global (null = todas)
  List<Jornada>? _jornadas;
  Map<String, dynamic>? _data;
  Object? _error;
  int _seq = 0;

  bool get _global => widget.jornadaId == null;
  String? get _jornadaActual => widget.jornadaId ?? _sel;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    if (_global) _cargarJornadas();
  }

  Future<void> _cargarJornadas() async {
    try {
      final r = await Data.jornadas(todas: true);
      r.sort((a, b) => b.fecha.compareTo(a.fecha));
      if (mounted) setState(() => _jornadas = r);
    } catch (_) {
      if (mounted) setState(() => _jornadas = const []);
    }
  }

  Future<void> _load() async {
    final seq = ++_seq;
    setState(() => _error = null);
    try {
      final r = await Data.estadisticas(_jornadaActual);
      if (mounted && seq == _seq) setState(() => _data = r);
    } catch (e) {
      if (mounted && seq == _seq) setState(() => _error = e);
    }
  }

  void _elegir(String? id) {
    if (id == _sel) return;
    setState(() {
      _sel = id;
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final body = _body();
    if (widget.embebida) return body;
    return Scaffold(appBar: AppBar(title: const Text('Estadísticas')), body: body);
  }

  Widget _body() {
    if (_error != null && _data == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar las estadísticas',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final d = _data;
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        if (_global) ...[_selector(), const SizedBox(height: 14)],
        if (d == null)
          const Padding(padding: EdgeInsets.only(top: 80), child: Center(child: CircularProgressIndicator()))
        else
          ..._contenido(d, t),
      ]),
    );
  }

  Widget _selector() {
    final js = _jornadas;
    return DropdownButtonFormField<String?>(
      key: ValueKey('sel-${js?.length}'),
      initialValue: _sel,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Jornada', prefixIcon: Icon(Icons.event_rounded)),
      items: [
        const DropdownMenuItem<String?>(value: null, child: Text('Todas las jornadas')),
        for (final j in js ?? const <Jornada>[])
          DropdownMenuItem<String?>(
            value: j.id,
            child: Text('${Money.fecha(j.fecha)} · ${j.titulo}', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: _elegir,
    );
  }

  List<Widget> _contenido(Map<String, dynamic> d, TextTheme t) {
    final total = _n(d['total']);
    final presentes = _n(d['presentes']);
    final atendidas = _n(d['atendidas']);
    final retiradas = _n(d['retiradas']);
    final esp = _m(d['por_especie']);
    final sexo = _m(d['por_sexo']);
    final ingresos = d['ingresos'] is Map ? _m(d['ingresos']) : null;
    final porJornada = (d['por_jornada'] is List ? d['por_jornada'] as List : const [])
        .map(_m)
        .toList();
    var i = 0;
    Widget anim(Widget w) => FadeSlideIn(index: i++, child: w);

    return [
      anim(FzHero(
        title: '${_entero(total)} ${total == 1 ? 'mascota inscrita' : 'mascotas inscritas'}',
        subtitle: _jornadaActual == null ? 'Todas las jornadas' : 'En esta jornada',
        leading: const Icon(Icons.insights_rounded, color: Fz.tarjeta, size: 34),
        child: Row(children: [
          _heroDato(t, 'Presentes', presentes),
          _heroDato(t, 'Atendidas', atendidas),
          _heroDato(t, 'Retiradas', retiradas),
        ]),
      )),
      const SizedBox(height: 16),
      if (total == 0 && porJornada.isEmpty && ingresos == null)
        const EmptyState(
          icon: Icons.bar_chart_rounded,
          title: 'Aún no hay datos',
          message: 'Cuando haya mascotas inscritas verás aquí los gráficos.',
        )
      else ...[
        anim(_Tarjeta(
          titulo: 'Por especie',
          child: _Anillo(
            total: total,
            partes: [
              ('Perros', _n(esp['perro']), Fz.azul900),
              ('Gatos', _n(esp['gato']), Fz.azul400),
            ],
          ),
        )),
        const SizedBox(height: 14),
        anim(_Tarjeta(
          titulo: 'Por sexo y especie',
          leyenda: const [('Machos', Fz.azul900), ('Hembras', Fz.azul400)],
          child: _Barras(grupos: [
            ('Perros', [(_n(sexo['perro_macho']), Fz.azul900), (_n(sexo['perro_hembra']), Fz.azul400)]),
            ('Gatos', [(_n(sexo['gato_macho']), Fz.azul900), (_n(sexo['gato_hembra']), Fz.azul400)]),
          ]),
        )),
        const SizedBox(height: 14),
        anim(_Tarjeta(
          titulo: 'Estado de las inscripciones',
          child: _Barras(grupos: [
            ('Inscritas', [(total, Fz.azul900)]),
            ('Presentes', [(presentes, Fz.azul700)]),
            ('Atendidas', [(atendidas, Fz.azul)]),
            ('Retiradas', [(retiradas, Fz.azul200)]),
          ], ancho: 30),
        )),
        if (ingresos != null) ...[
          const SizedBox(height: 14),
          anim(_ingresos(t, ingresos)),
        ],
        if (_jornadaActual == null && porJornada.isNotEmpty) ...[
          const SizedBox(height: 14),
          if (ingresos != null) ...[
            anim(_Tarjeta(
              titulo: r'Ingresos por jornada ($)',
              child: _Barras(
                grupos: [
                  for (final j in porJornada) (_etiquetaJornada(j), [(_n(j['ingresos_usd']), Fz.azul700)]),
                ],
                formato: (v) => Money.usd(v),
                ancho: 22,
              ),
            )),
            const SizedBox(height: 14),
          ],
          anim(_Tarjeta(
            titulo: 'Mascotas por jornada',
            child: _Barras(
              grupos: [
                for (final j in porJornada) (_etiquetaJornada(j), [(_n(j['mascotas']), Fz.azul400)]),
              ],
              ancho: 22,
            ),
          )),
        ],
      ],
    ];
  }

  String _etiquetaJornada(Map<String, dynamic> j) {
    final f = DateTime.tryParse(j['fecha']?.toString() ?? '');
    if (f != null) return '${f.toLocal().day.toString().padLeft(2, '0')}/${f.toLocal().month.toString().padLeft(2, '0')}';
    final s = j['titulo']?.toString() ?? '';
    return s.length > 8 ? '${s.substring(0, 8)}…' : s;
  }

  Widget _heroDato(TextTheme t, String k, double v) => Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: Fz.azul700,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Fz.azul900, width: 1.5),
          ),
          child: Column(children: [
            Text(_entero(v), style: Fz.display(22, color: Fz.tarjeta)),
            Text(k, style: t.labelMedium?.copyWith(color: Fz.azul50)),
          ]),
        ),
      );

  Widget _ingresos(TextTheme t, Map<String, dynamic> ing) {
    final verUsd = _n(ing['verificado_usd']);
    final penUsd = _n(ing['pendiente_usd']);
    final verBs = _n(ing['verificado_bs']);
    final esperado = ing['esperado_usd'] == null ? null : _n(ing['esperado_usd']);
    final ajustes = ing['ajustes_usd'] == null ? null : _n(ing['ajustes_usd']);
    final met = _m(ing['por_metodo']);
    final pm = _n(met['pago_movil']);
    final ef = _n(met['efectivo_divisa']);

    Widget tile(String k, String v, {String? sub, Color color = Fz.tarjeta, Color fg = Fz.tinta}) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Fz.tinta, width: Fz.borde),
            ),
            child: Column(children: [
              Text(k, textAlign: TextAlign.center, style: t.labelMedium?.copyWith(color: fg)),
              const SizedBox(height: 2),
              FittedBox(child: Text(v, style: Fz.display(22, color: fg))),
              if (sub != null) Text(sub, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: fg)),
            ]),
          ),
        );

    final metTotal = pm + ef;
    return _Tarjeta(
      titulo: 'Ingresos',
      child: Column(children: [
        Row(children: [
          tile('Verificados', Money.usd(verUsd), sub: Money.bs(verBs), color: Fz.azul, fg: Fz.tarjeta),
          const SizedBox(width: 10),
          tile('Por verificar', Money.usd(penUsd), color: Fz.azul100),
        ]),
        if (esperado != null || ajustes != null) ...[
          const SizedBox(height: 10),
          Row(children: [
            if (esperado != null) tile('Esperado', Money.usd(esperado), color: Fz.azul50),
            if (esperado != null && ajustes != null) const SizedBox(width: 10),
            if (ajustes != null) tile('Ajustes', Money.usd(ajustes), color: Fz.azul50),
          ]),
        ],
        const SizedBox(height: 16),
        Text('Por método de pago', textAlign: TextAlign.center, style: t.titleSmall),
        const SizedBox(height: 8),
        if (metTotal <= 0)
          Text('Sin pagos verificados todavía.', textAlign: TextAlign.center, style: t.bodySmall)
        else ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: SizedBox(
              height: 16,
              child: Row(children: [
                if (pm > 0) Expanded(flex: (pm * 100).round().clamp(1, 1 << 30), child: const ColoredBox(color: Fz.azul900)),
                if (ef > 0) Expanded(flex: (ef * 100).round().clamp(1, 1 << 30), child: const ColoredBox(color: Fz.azul400)),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          Row(children: [
            tile('Pago Móvil', Money.usd(pm), sub: '${(pm / metTotal * 100).round()} %'),
            const SizedBox(width: 10),
            tile('Efectivo', Money.usd(ef), sub: '${(ef / metTotal * 100).round()} %'),
          ]),
          const SizedBox(height: 8),
          const _Leyenda(items: [('Pago Móvil', Fz.azul900), ('Efectivo en divisas', Fz.azul400)]),
        ],
      ]),
    );
  }
}

/// Tarjeta de gráfico: título centrado, contenido y leyenda opcional.
class _Tarjeta extends StatelessWidget {
  const _Tarjeta({required this.titulo, required this.child, this.leyenda});
  final String titulo;
  final Widget child;
  final List<(String, Color)>? leyenda;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(titulo, textAlign: TextAlign.center, style: t.titleLarge),
        const SizedBox(height: 14),
        child,
        if (leyenda != null) ...[const SizedBox(height: 10), _Leyenda(items: leyenda!)],
      ]),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda({required this.items});
  final List<(String, Color)> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 6, children: [
      for (final (k, c) in items)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: c,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Fz.tinta, width: 1.2),
            ),
          ),
          const SizedBox(width: 6),
          Text(k, style: t.labelMedium),
        ]),
    ]);
  }
}

/// Anillo (torta con hueco) con el total grande en el centro.
class _Anillo extends StatelessWidget {
  const _Anillo({required this.total, required this.partes});
  final double total;
  final List<(String, double, Color)> partes;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final suma = partes.fold<double>(0, (s, p) => s + p.$2);
    return Column(children: [
      SizedBox(
        height: 190,
        child: Stack(alignment: Alignment.center, children: [
          PieChart(
            PieChartData(
              sectionsSpace: suma > 0 ? 3 : 0,
              centerSpaceRadius: 56,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(enabled: false),
              sections: suma <= 0
                  ? [PieChartSectionData(value: 1, color: Fz.azul100, radius: 30, showTitle: false)]
                  : [
                      for (final p in partes)
                        if (p.$2 > 0)
                          PieChartSectionData(
                            value: p.$2,
                            color: p.$3,
                            radius: 32,
                            title: '${(p.$2 / suma * 100).round()} %',
                            titleStyle: Fz.body(12, w: FontWeight.w700, color: Fz.tarjeta),
                            borderSide: const BorderSide(color: Fz.tinta, width: 1.5),
                          ),
                    ],
            ),
          ),
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_entero(suma > 0 ? suma : total), style: Fz.display(30)),
            Text('total', style: t.bodySmall),
          ]),
        ]),
      ),
      const SizedBox(height: 10),
      Wrap(alignment: WrapAlignment.center, spacing: 16, runSpacing: 6, children: [
        for (final p in partes)
          Row(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: p.$3,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Fz.tinta, width: 1.2),
              ),
            ),
            const SizedBox(width: 6),
            Text('${p.$1}: ${_entero(p.$2)}', style: t.labelMedium),
          ]),
      ]),
    ]);
  }
}

/// Barras verticales (simples o agrupadas) con el valor encima de cada barra.
/// Si hay muchas categorías se puede desplazar horizontalmente.
class _Barras extends StatelessWidget {
  const _Barras({required this.grupos, this.formato, this.ancho = 26});
  final List<(String, List<(double, Color)>)> grupos;
  final String Function(double)? formato;
  final double ancho;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final fmt = formato ?? _entero;
    final maxV = grupos.expand((g) => g.$2).fold<double>(0, (m, r) => math.max(m, r.$1));
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.28;
    final porGrupo = grupos.isEmpty ? 1 : grupos.map((g) => g.$2.length).reduce(math.max);
    final anchoGrupo = porGrupo * (ancho + 4) + 28;
    final labelStyle = Fz.body(11, w: FontWeight.w700);

    final chart = BarChart(
      BarChartData(
        maxY: maxY,
        minY: 0,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(enabled: false),
        borderData: FlBorderData(show: true, border: const Border(bottom: BorderSide(color: Fz.tinta, width: 1.5))),
        gridData: FlGridData(
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) => const FlLine(color: Fz.azul100, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (v, meta) {
                final k = v.toInt();
                if (k < 0 || k >= grupos.length) return const SizedBox.shrink();
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(grupos[k].$1, style: t.labelMedium),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (final (k, g) in grupos.indexed)
            BarChartGroupData(
              x: k,
              barsSpace: 4,
              barRods: [
                for (final (v, c) in g.$2)
                  BarChartRodData(
                    toY: v,
                    color: c,
                    width: ancho,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    borderSide: const BorderSide(color: Fz.tinta, width: 1.2),
                    label: BarChartRodLabel(show: true, text: fmt(v), style: labelStyle, offset: const Offset(0, 4)),
                  ),
              ],
            ),
        ],
      ),
    );

    return LayoutBuilder(builder: (context, c) {
      final necesario = grupos.length * anchoGrupo;
      if (necesario <= c.maxWidth) return SizedBox(height: 210, child: chart);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: necesario, height: 210, child: chart),
      );
    });
  }
}
