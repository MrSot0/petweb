import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import 'admin_jornadas_screen.dart'
    show JornadaPortada, estadoJornadaPill, estadoInscripcionTexto, estadoInscripcionIcono, mostrarFijarPrecio;
import 'jornada_form_screen.dart';
import 'stats_screen.dart';
import 'verificar_screen.dart' show CodigoCopiable;

/// Número de WhatsApp en formato internacional (Venezuela) a partir de "0414-1234567".
String? waNumero(String? tel) {
  if (tel == null) return null;
  var d = tel.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('58') && d.length >= 12) return d;
  if (d.startsWith('0')) d = d.substring(1);
  return '58$d';
}

String servicioTexto(String? s) => s == 'limpieza_dental' ? 'Limpieza dental' : 'Esterilización';

String estadoPagoTexto(String? e) => switch (e) {
      'pendiente' => 'Pago por verificar',
      'verificado' => 'Pago verificado',
      'rechazado' => 'Pago rechazado',
      'anulado' => 'Pago anulado',
      _ => 'Sin pago reportado',
    };

String _str(dynamic v) => v?.toString() ?? '';
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Detalle de una jornada para administración y contador: participantes y estadísticas.
class JornadaDetalleScreen extends StatefulWidget {
  const JornadaDetalleScreen({super.key, required this.jornada});
  final Jornada jornada;

  @override
  State<JornadaDetalleScreen> createState() => _JornadaDetalleScreenState();
}

class _JornadaDetalleScreenState extends State<JornadaDetalleScreen> {
  late Jornada _j = widget.jornada;
  bool _changed = false;

  Future<void> _editar() async {
    final r = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => JornadaFormScreen(jornada: _j)));
    if (r == true && mounted) {
      _changed = true;
      // Recarga la jornada editada para reflejar portada, fecha, etc.
      try {
        final todas = await Data.jornadas(todas: true);
        final nueva = todas.where((x) => x.id == _j.id).firstOrNull;
        if (nueva != null && mounted) setState(() => _j = nueva);
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppMode.of(context).isAdmin;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text(_j.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
            actions: [
              if (admin) IconButton(tooltip: 'Editar jornada', icon: const Icon(Icons.edit_rounded), onPressed: _editar),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(62),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Fz.tarjeta,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Fz.tinta, width: Fz.borde),
                  ),
                  child: const TabBar(tabs: [
                    Tab(height: 36, text: 'Participantes'),
                    Tab(height: 36, text: 'Estadísticas'),
                  ]),
                ),
              ),
            ),
          ),
          body: TabBarView(children: [
            _ParticipantesTab(jornada: _j, onChanged: () => _changed = true),
            EstadisticasScreen(jornadaId: _j.id, embebida: true),
          ]),
        ),
      ),
    );
  }
}

class _ParticipantesTab extends StatefulWidget {
  const _ParticipantesTab({required this.jornada, required this.onChanged});
  final Jornada jornada;
  final VoidCallback onChanged;

  @override
  State<_ParticipantesTab> createState() => _ParticipantesTabState();
}

class _ParticipantesTabState extends State<_ParticipantesTab> with AutomaticKeepAliveClientMixin {
  static const _filtros = [
    ('todas', 'Todas'),
    ('precio_por_confirmar', 'Precio por confirmar'),
    ('pendiente_pago', 'Pendiente de pago'),
    ('pago_en_revision', 'En revisión'),
    ('confirmada', 'Confirmadas'),
    ('presentes', 'Presentes'),
    ('atendida', 'Atendidas'),
    ('retiradas', 'Retiradas'),
  ];

  List<Map<String, dynamic>>? _items;
  Object? _error;
  String _filtro = 'todas';
  final _buscar = TextEditingController();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.participantes(widget.jornada.id);
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  static bool _retirada(Map<String, dynamic> i) =>
      i['estado'] == 'cancelada' || i['estado'] == 'retirada' || i['motivo_retiro'] != null;

  bool _pasa(Map<String, dynamic> i) {
    final ok = switch (_filtro) {
      'todas' => true,
      'presentes' => i['presente_at'] != null && !_retirada(i),
      'retiradas' => _retirada(i),
      final e => i['estado'] == e,
    };
    if (!ok) return false;
    final q = _buscar.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    final pet = _map(i['pet']);
    final prop = _map(i['propietario']);
    return [_str(pet['nombre']), _str(prop['nombre']), _str(i['codigo']), _str(prop['telefono'])]
        .any((s) => s.toLowerCase().contains(q));
  }

  int _cuenta(String f) {
    final items = _items ?? const [];
    return switch (f) {
      'todas' => items.length,
      'presentes' => items.where((i) => i['presente_at'] != null && !_retirada(i)).length,
      'retiradas' => items.where(_retirada).length,
      final e => items.where((i) => i['estado'] == e).length,
    };
  }

  Future<void> _retirar(Map<String, dynamic> i) async {
    final motivo = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RetirarSheet(nombre: _str(_map(i['pet'])['nombre'])),
    );
    if (motivo == null || !mounted) return;
    try {
      await Data.retirarInscripcion(_str(i['id']), motivo);
      widget.onChanged();
      if (mounted) showInfo(context, 'Mascota retirada de la jornada');
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _fijarPrecio(Map<String, dynamic> i) async {
    if (await mostrarFijarPrecio(context, i)) {
      widget.onChanged();
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final t = Theme.of(context).textTheme;
    if (_error != null && _items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los participantes',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    final items = _items;
    if (items == null) return const Center(child: CircularProgressIndicator());
    final j = widget.jornada;
    final mode = AppMode.of(context);
    final visibles = items.where(_pasa).toList();
    final activos = items.where((i) => !_retirada(i)).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // ---- Cabecera de la jornada ----
        FadeSlideIn(
          child: PopCard(
            padding: EdgeInsets.zero,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Stack(children: [
                JornadaPortada(jornada: j, height: 120, radius: Fz.radioTarjeta - 2),
                Positioned(top: 10, right: 10, child: estadoJornadaPill(j.estado)),
              ]),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(children: [
                  Text(Money.fechaLarga(j.fecha), textAlign: TextAlign.center, style: t.titleMedium),
                  Text('${j.sede} · ${j.ciudad}', textAlign: TextAlign.center, style: t.bodyMedium),
                  if (j.direccion != null) Text(j.direccion!, textAlign: TextAlign.center, style: t.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    '$activos de ${j.cuposTotal} cupos · ${items.length} fichas'
                    '${j.limpiezaDental ? ' · con limpieza dental' : ''}',
                    textAlign: TextAlign.center,
                    style: t.titleSmall,
                  ),
                  if (j.enlaceMapa != null)
                    TextButton.icon(
                      onPressed: () => abrirEnlace(j.enlaceMapa!),
                      icon: const Icon(Icons.map_rounded),
                      label: const Text('Abrir en Maps'),
                    ),
                ]),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _buscar,
          onChanged: (_) => setState(() {}),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Buscar por mascota, propietario o código',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _buscar.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Borrar búsqueda',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(_buscar.clear),
                  ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (final f in _filtros)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text('${f.$2} · ${_cuenta(f.$1)}'),
                    selected: _filtro == f.$1,
                    onSelected: (_) => setState(() => _filtro = f.$1),
                  ),
                ),
            ]),
          ),
        ),
        const SizedBox(height: 8),
        if (visibles.isEmpty)
          EmptyState(
            icon: items.isEmpty ? Icons.pets_rounded : Icons.filter_alt_off_rounded,
            title: items.isEmpty ? 'Nadie se ha inscrito todavía' : 'Sin resultados',
            message: items.isEmpty ? null : 'Prueba con otro filtro o búsqueda.',
          )
        else
          for (final (k, i) in visibles.indexed) ...[
            FadeSlideIn(
              key: ValueKey(i['id']),
              index: k,
              child: _ParticipanteCard(
                ficha: i,
                alt: k.isOdd,
                retirada: _retirada(i),
                onRetirar: mode.isAdmin || mode.isContador ? () => _retirar(i) : null,
                onFijarPrecio: mode.isAdmin && i['estado'] == 'precio_por_confirmar' ? () => _fijarPrecio(i) : null,
              ),
            ),
            const SizedBox(height: 12),
          ],
      ])),
    );
  }
}

class _ParticipanteCard extends StatelessWidget {
  const _ParticipanteCard({
    required this.ficha,
    required this.retirada,
    this.alt = false,
    this.onRetirar,
    this.onFijarPrecio,
  });
  final Map<String, dynamic> ficha;
  final bool retirada;
  final bool alt;
  final VoidCallback? onRetirar;
  final VoidCallback? onFijarPrecio;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final i = ficha;
    final pet = _map(i['pet']);
    final prop = _map(i['propietario']);
    final pago = i['pago'] is Map ? _map(i['pago']) : null;
    final cirugia = i['cirugia'] is Map ? _map(i['cirugia']) : null;
    final estado = i['estado']?.toString();
    final perro = pet['especie'] == 'perro';
    final macho = pet['sexo'] == 'macho';
    final peso = (pet['peso_kg'] as num?)?.toDouble();
    final especieTxt = perro ? (macho ? 'Perro' : 'Perra') : (macho ? 'Gato' : 'Gata');
    final tel = prop['telefono']?.toString();
    final wa = waNumero(tel);
    final presente = i['presente_at'] != null;
    final atendida = estado == 'atendida' || cirugia != null;
    final precio = (i['precio_total_usd'] as num?)?.toDouble();

    Widget dato(IconData ic, String k, String v, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(children: [
            Icon(ic, size: 17, color: Fz.azul),
            const SizedBox(width: 8),
            SizedBox(width: 74, child: Text(k, style: t.bodySmall)),
            Expanded(child: Text(v, style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w700))),
            ?trailing,
          ]),
        );

    return Opacity(
      opacity: retirada ? .7 : 1,
      child: PopCard(
        color: alt ? Fz.azul50 : Fz.tarjeta,
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            FzAvatar(
              url: Data.fotoUrl(pet['foto_path'] as String?),
              icon: Icons.pets_rounded,
              size: 54,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_str(pet['nombre']).isEmpty ? 'Mascota' : _str(pet['nombre']),
                    style: t.titleLarge, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  [
                    if (pet['especie'] != null) especieTxt,
                    if (peso != null) '${peso.toStringAsFixed(peso % 1 == 0 ? 0 : 1)} kg',
                    if (pet['braquiocefalico'] == true) 'braquiocefálico',
                  ].join(' · '),
                  style: t.bodySmall,
                ),
                if (_str(i['codigo']).isNotEmpty) CodigoCopiable(_str(i['codigo']), compacto: true),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(Money.usd(precio), style: t.titleMedium),
              Text(servicioTexto(i['servicio']?.toString()), style: t.bodySmall),
            ]),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            StatusPill(
              retirada ? 'Retirada' : estadoInscripcionTexto(estado),
              icon: retirada ? Icons.person_remove_rounded : estadoInscripcionIcono(estado),
              color: retirada
                  ? Fz.frambuesaSuave
                  : estado == 'confirmada' || estado == 'atendida'
                      ? Fz.azul200
                      : Fz.azul50,
              dashed: estado == 'pendiente_pago',
            ),
            if (presente && !retirada) const StatusPill('Presente', icon: Icons.how_to_reg_rounded, color: Fz.azul100),
            if (atendida) const StatusPill('Atendida', icon: Icons.medical_services_rounded, color: Fz.azul200),
            if (i['incluye_kit'] == true) const StatusPill('Kit', icon: Icons.inventory_2_rounded, color: Fz.tarjeta),
            if (i['incluye_cono'] == true) const StatusPill('Cono', icon: Icons.shield_rounded, color: Fz.tarjeta),
          ]),
          if (retirada && i['motivo_retiro'] != null) ...[
            const SizedBox(height: 8),
            Text('Motivo del retiro: ${i['motivo_retiro']}', style: t.bodySmall?.copyWith(color: Fz.frambuesa)),
          ],
          const Divider(height: 22),
          // ---- Propietario ----
          dato(Icons.person_rounded, 'Propietario', _str(prop['nombre']).isEmpty ? '—' : _str(prop['nombre'])),
          dato(
            Icons.phone_rounded,
            'Teléfono',
            tel ?? '—',
            trailing: tel == null
                ? null
                : Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      tooltip: 'Copiar teléfono',
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: tel));
                        if (context.mounted) showInfo(context, 'Teléfono copiado');
                      },
                    ),
                    if (wa != null)
                      IconButton(
                        tooltip: 'Abrir WhatsApp',
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chat_rounded, size: 20),
                        onPressed: () async {
                          final ok = await abrirEnlace('https://wa.me/$wa');
                          if (!ok && context.mounted) showInfo(context, 'No pudimos abrir WhatsApp.');
                        },
                      ),
                  ]),
          ),
          if (prop['cedula'] != null) dato(Icons.badge_rounded, 'Cédula', _str(prop['cedula'])),
          if (prop['email'] != null) dato(Icons.mail_rounded, 'Correo', _str(prop['email'])),
          const Divider(height: 22),
          // ---- Pago ----
          if (pago == null)
            dato(Icons.payments_rounded, 'Pago', 'Sin pago reportado')
          else ...[
            dato(
              pago['metodo'] == 'efectivo_divisa' ? Icons.payments_rounded : Icons.account_balance_rounded,
              'Método',
              pago['metodo'] == 'efectivo_divisa' ? 'Efectivo en divisas' : 'Pago Móvil',
            ),
            dato(
              pago['estado'] == 'verificado' ? Icons.check_circle_rounded : Icons.hourglass_top_rounded,
              'Estado',
              estadoPagoTexto(pago['estado']?.toString()),
            ),
            if (pago['referencia'] != null) dato(Icons.tag_rounded, 'Referencia', _str(pago['referencia'])),
            if (pago['banco'] != null) dato(Icons.account_balance_rounded, 'Banco', _str(pago['banco'])),
            if (pago['monto_usd'] != null || pago['monto_bs'] != null)
              dato(
                Icons.attach_money_rounded,
                'Monto',
                [
                  if (pago['monto_usd'] != null) Money.usd(pago['monto_usd'] as num?),
                  if (pago['monto_bs'] != null) Money.bs(pago['monto_bs'] as num?),
                ].join(' · '),
              ),
          ],
          if (onFijarPrecio != null || (onRetirar != null && !retirada && !atendida)) ...[
            const SizedBox(height: 12),
            Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 10, children: [
              if (onFijarPrecio != null)
                FilledButton.icon(
                  onPressed: onFijarPrecio,
                  icon: const Icon(Icons.sell_rounded),
                  label: const Text('Fijar precio'),
                ),
              if (onRetirar != null && !retirada && !atendida)
                OutlinedButton.icon(
                  onPressed: onRetirar,
                  style: OutlinedButton.styleFrom(foregroundColor: Fz.frambuesa),
                  icon: const Icon(Icons.person_remove_rounded),
                  label: const Text('Retirar de la jornada'),
                ),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Hoja para retirar una mascota: motivo obligatorio con chips rápidos + detalle.
class _RetirarSheet extends StatefulWidget {
  const _RetirarSheet({required this.nombre});
  final String nombre;

  @override
  State<_RetirarSheet> createState() => _RetirarSheetState();
}

class _RetirarSheetState extends State<_RetirarSheet> {
  static const _rapidos = ['No pagó', 'No asistió', 'No apta para cirugía', 'Lo pidió el propietario'];
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
          Text('Retirar de la jornada', textAlign: TextAlign.center, style: t.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '${widget.nombre.isEmpty ? 'La mascota' : widget.nombre} saldrá de la lista y se liberará su cupo. '
            'El motivo es obligatorio y queda registrado.',
            textAlign: TextAlign.center,
            style: t.bodyMedium,
          ),
          const SizedBox(height: 14),
          Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
            for (final m in _rapidos)
              ChoiceChip(
                label: Text(m),
                selected: _chip == m,
                onSelected: (s) => setState(() => _chip = s ? m : null),
              ),
          ]),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            maxLines: 3,
            minLines: 2,
            maxLength: 300,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(labelText: _chip == null ? 'Motivo' : 'Detalle (opcional)'),
          ),
          const SizedBox(height: 8),
          PopButton.danger(
            label: 'Retirar',
            icon: Icons.person_remove_rounded,
            onPressed: _motivo.length < 3 ? null : () => Navigator.of(context).pop(_motivo),
          ),
          const SizedBox(height: 8),
          Center(child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar'))),
        ]),
      ),
    );
  }
}
