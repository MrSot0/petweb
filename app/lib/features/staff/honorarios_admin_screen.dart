import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import 'tasa_screen.dart' show parseBs;
import 'verificar_screen.dart' show CodigoCopiable, staffFecha, staffNum, staffStr;

String _tarifaTitulo(Map<String, dynamic> r) {
  final servicio = r['servicio'] == 'limpieza_dental' ? 'Limpieza dental' : 'Esterilización';
  final perro = r['especie'] == 'perro';
  final sexo = staffStr(r['sexo']);
  final animal = sexo == null
      ? (perro ? 'Perro' : 'Gato')
      : '${perro ? 'Perro' : 'Gato'} ${sexo == 'hembra' ? 'hembra' : 'macho'}';
  return '$servicio · $animal';
}

String _especieSexo(Map<String, dynamic> c) {
  final perro = c['especie'] == 'perro';
  final macho = c['sexo'] == 'macho';
  if (c['especie'] == null) return '';
  return perro ? (macho ? 'Perro' : 'Perra') : (macho ? 'Gato' : 'Gata');
}

/// Honorarios de cirujanos (administración y contador): tarifas por cirugía y resumen por cirujano.
/// Solo administración edita tarifas y marca honorarios como pagados.
class HonorariosAdminScreen extends StatefulWidget {
  const HonorariosAdminScreen({super.key});

  @override
  State<HonorariosAdminScreen> createState() => _HonorariosAdminScreenState();
}

class _HonorariosAdminScreenState extends State<HonorariosAdminScreen> {
  List<Map<String, dynamic>>? _tarifas;
  List<Map<String, dynamic>>? _resumen;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([Data.tarifasHonorarios(), Data.honorariosResumen()]);
      if (!mounted) return;
      setState(() {
        _tarifas = r[0];
        _resumen = r[1]..sort((a, b) => (staffNum(b['pendiente_usd']) ?? 0).compareTo(staffNum(a['pendiente_usd']) ?? 0));
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _editarTarifa(Map<String, dynamic> r) async {
    final id = r['id'];
    if (id is! int) return;
    final ctrl = TextEditingController(text: staffNum(r['monto_usd'])?.toString() ?? '');
    final key = GlobalKey<FormState>();
    final monto = await showDialog<double>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Tarifa por cirugía', textAlign: TextAlign.center),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(_tarifaTitulo(r), textAlign: TextAlign.center, style: Theme.of(c).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: r'Honorario en $', prefixText: r'$ '),
              validator: (v) {
                final n = parseBs(v ?? '');
                if (n == null || n < 0) return 'Escribe un monto válido';
                if (n > 1000) return 'El monto parece demasiado alto';
                return null;
              },
            ),
            const SizedBox(height: 6),
            Text('Aplica a las cirugías que se registren desde ahora.',
                textAlign: TextAlign.center, style: Theme.of(c).textTheme.bodySmall),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              if (key.currentState?.validate() == true) Navigator.pop(c, parseBs(ctrl.text));
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (monto == null || !mounted) return;
    try {
      await Data.guardarTarifaHonorario(id, monto);
      if (mounted) showInfo(context, 'Tarifa actualizada');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _abrir(Map<String, dynamic> c) async {
    final id = staffStr(c['cirujano_id']);
    if (id == null) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => HonorariosCirujanoScreen(
        cirujanoId: id,
        nombre: staffStr(c['nombre']) ?? 'Cirujano',
        avatarPath: staffStr(c['avatar_path']),
      ),
    ));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Honorarios de cirujanos')), body: _body());
  }

  Widget _body() {
    if (_error != null && _resumen == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los honorarios',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final tarifas = _tarifas;
    final resumen = _resumen;
    if (tarifas == null || resumen == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final admin = AppMode.of(context).isAdmin;
    final pendiente = resumen.fold<double>(0, (s, c) => s + (staffNum(c['pendiente_usd']) ?? 0));
    final pagado = resumen.fold<double>(0, (s, c) => s + (staffNum(c['pagado_usd']) ?? 0));

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FadeSlideIn(
            child: FzHero(
              leading: const Icon(Icons.medical_services_rounded, color: Fz.tarjeta, size: 34),
              title: '${Money.usd(pendiente)} por pagar',
              subtitle: 'Pagado hasta hoy: ${Money.usd(pagado)}',
            ),
          ),
          const SectionTitle('Resumen por cirujano'),
          if (resumen.isEmpty)
            const EmptyState(
              icon: Icons.person_search_rounded,
              title: 'Sin honorarios todavía',
              message: 'Aparecerán cuando los cirujanos registren cirugías.',
            )
          else
            for (final (i, c) in resumen.indexed) ...[
              FadeSlideIn(
                index: i + 1,
                child: PopCard(
                  color: i.isOdd ? Fz.azul50 : Fz.tarjeta,
                  padding: const EdgeInsets.all(14),
                  onTap: () => _abrir(c),
                  child: Row(children: [
                    FzAvatar(
                      url: Data.fotoUrl(staffStr(c['avatar_path'])),
                      text: iniciales(staffStr(c['nombre'])),
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(staffStr(c['nombre']) ?? 'Cirujano',
                            style: t.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          '${(staffNum(c['cantidad']) ?? 0).round()} cirugías · pagado ${Money.usd(staffNum(c['pagado_usd']) ?? 0)}',
                          style: t.bodySmall,
                        ),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(Money.usd(staffNum(c['pendiente_usd']) ?? 0), style: Fz.display(19)),
                      Text('pendiente', style: t.bodySmall),
                    ]),
                    const Icon(Icons.chevron_right_rounded, color: Fz.azul),
                  ]),
                ),
              ),
              const SizedBox(height: 12),
            ],
          SectionTitle(admin ? 'Tarifas por cirugía' : 'Tarifas por cirugía (solo lectura)'),
          if (tarifas.isEmpty)
            Text('No hay tarifas cargadas.', textAlign: TextAlign.center, style: t.bodyMedium)
          else
            PopCard(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Column(children: [
                for (final (i, r) in tarifas.indexed) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    minTileHeight: 56,
                    leading: Icon(r['servicio'] == 'limpieza_dental' ? Icons.clean_hands_rounded : Icons.content_cut_rounded),
                    title: Text(_tarifaTitulo(r), style: t.titleSmall),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(Money.usd(staffNum(r['monto_usd']) ?? 0), style: t.titleMedium),
                      if (admin) ...[const SizedBox(width: 6), const Icon(Icons.edit_rounded, size: 20, color: Fz.azul)],
                    ]),
                    onTap: admin ? () => _editarTarifa(r) : null,
                  ),
                ],
              ]),
            ),
          if (admin) ...[
            const SizedBox(height: 8),
            Text('Toca una tarifa para cambiarla.', textAlign: TextAlign.center, style: t.bodySmall),
          ],
        ]),
      ),
    );
  }
}

/// Detalle de honorarios de un cirujano: cirugías y pago (admin).
class HonorariosCirujanoScreen extends StatefulWidget {
  const HonorariosCirujanoScreen({super.key, required this.cirujanoId, required this.nombre, this.avatarPath});
  final String cirujanoId;
  final String nombre;
  final String? avatarPath;

  @override
  State<HonorariosCirujanoScreen> createState() => _HonorariosCirujanoScreenState();
}

class _HonorariosCirujanoScreenState extends State<HonorariosCirujanoScreen> {
  Map<String, dynamic>? _d;
  Object? _error;
  bool _pagando = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.misHonorarios(widget.cirujanoId);
      if (mounted) setState(() => _d = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _pagar(double pendiente) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('¿Marcar como pagado?', textAlign: TextAlign.center),
        content: Text(
          'Se marcarán como pagados ${Money.usd(pendiente)} en honorarios pendientes de ${widget.nombre}. '
          'Hazlo solo cuando ya le hayas pagado.',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Marcar como pagado')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _pagando = true);
    try {
      final n = await Data.pagarHonorarios(widget.cirujanoId);
      if (mounted) showInfo(context, n == 1 ? '1 cirugía marcada como pagada' : '$n cirugías marcadas como pagadas');
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _pagando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: Text(widget.nombre, maxLines: 1, overflow: TextOverflow.ellipsis)), body: _body());
  }

  Widget _body() {
    if (_error != null && _d == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los honorarios',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final d = _d;
    if (d == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    final admin = AppMode.of(context).isAdmin;
    final pendiente = staffNum(d['pendiente_usd']) ?? 0;
    final pagado = staffNum(d['pagado_usd']) ?? 0;
    final cantidad = (staffNum(d['cantidad']) ?? 0).round();
    final cirugias = ((d['cirugias'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    Widget dato(String k, String v) => Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: Fz.azul700,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Fz.azul900, width: 1.5),
            ),
            child: Column(children: [
              FittedBox(child: Text(v, style: Fz.display(19, color: Fz.tarjeta))),
              Text(k, style: t.labelMedium?.copyWith(color: Fz.azul50)),
            ]),
          ),
        );

    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          FadeSlideIn(
            child: FzHero(
              leading: FzAvatar(url: Data.fotoUrl(widget.avatarPath), text: iniciales(widget.nombre), size: 56),
              title: Money.usd(staffNum(d['total_usd']) ?? (pendiente + pagado)),
              subtitle: 'Honorarios totales',
              child: Row(children: [
                dato('Cirugías', '$cantidad'),
                dato('Pendiente', Money.usd(pendiente)),
                dato('Pagado', Money.usd(pagado)),
              ]),
            ),
          ),
          if (admin && pendiente > 0) ...[
            const SizedBox(height: 16),
            PopButton(
              label: 'Marcar como pagado',
              icon: Icons.price_check_rounded,
              loading: _pagando,
              onPressed: _pagando ? null : () => _pagar(pendiente),
            ),
          ],
          const SectionTitle('Cirugías'),
          if (cirugias.isEmpty)
            const EmptyState(icon: Icons.medical_services_rounded, title: 'Sin cirugías registradas')
          else
            for (final (i, c) in cirugias.indexed) ...[
              FadeSlideIn(
                index: i,
                child: PopCard(
                  color: i.isOdd ? Fz.azul50 : Fz.tarjeta,
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    const FzAvatar(icon: Icons.pets_rounded, size: 42),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(
                          [staffStr(c['mascota']) ?? 'Mascota', if (_especieSexo(c).isNotEmpty) _especieSexo(c)].join(' · '),
                          style: t.titleSmall,
                        ),
                        Text(
                          [
                            if (staffFecha(c['fecha']) != null) Money.fecha(staffFecha(c['fecha'])!),
                            ?staffStr(c['jornada']),
                            if (c['patologia'] == true) 'con patología',
                          ].join(' · '),
                          style: t.bodySmall,
                        ),
                        if (staffStr(c['codigo']) != null) CodigoCopiable(staffStr(c['codigo'])!, compacto: true),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(Money.usd(staffNum(c['honorario_usd']) ?? 0), style: t.titleMedium),
                      const SizedBox(height: 4),
                      c['pagado_at'] != null
                          ? const StatusPill('Pagado', icon: Icons.check_circle_rounded, color: Fz.azul200)
                          : const StatusPill('Pendiente', icon: Icons.hourglass_top_rounded, color: Fz.tarjeta, dashed: true),
                    ]),
                  ]),
                ),
              ),
              const SizedBox(height: 10),
            ],
        ]),
      ),
    );
  }
}
