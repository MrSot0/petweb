import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/data.dart';
import '../../core/mapa.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import '../../main.dart';
import '../surgeon/cirugia_form_screen.dart';

// ---------- Ayudantes compartidos de la ficha (escáner, cirujano) ----------

Map<String, dynamic> fichaMapa(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

/// Texto "Perra · 12 kg · 2 años" a partir del pet de la ficha.
String fichaDescripcion(Map<String, dynamic> pet, {bool edad = true}) {
  final perro = pet['especie'] == 'perro';
  final macho = pet['sexo'] == 'macho';
  final partes = <String>[perro ? (macho ? 'Perro' : 'Perra') : (macho ? 'Gato' : 'Gata')];
  final peso = (pet['peso_kg'] as num?)?.toDouble();
  if (peso != null) partes.add('${peso.toStringAsFixed(peso % 1 == 0 ? 0 : 1).replaceAll('.', ',')} kg');
  final m = (pet['edad_meses'] as num?)?.toInt();
  if (edad && m != null) {
    partes.add(m < 12 ? '$m ${m == 1 ? 'mes' : 'meses'}' : '${m ~/ 12} ${m ~/ 12 == 1 ? 'año' : 'años'}');
  }
  return partes.join(' · ');
}

bool fichaAtendida(Map<String, dynamic> f) => f['estado'] == 'atendida' || f['cirugia'] != null;
bool fichaActiva(Map<String, dynamic> f) => f['estado'] != 'cancelada' && !fichaAtendida(f);

/// Etiqueta de estado (icono + texto + color de la escala azul; frambuesa solo para retiradas).
StatusPill fichaEstadoPill(Map<String, dynamic> f) {
  final estado = f['estado'] as String?;
  if (estado == 'cancelada') {
    return StatusPill(f['motivo_retiro'] != null ? 'Retirada' : 'Cancelada',
        icon: Icons.block_rounded, color: Fz.frambuesaSuave);
  }
  if (fichaAtendida(f)) return const StatusPill('Atendida', icon: Icons.check_circle_rounded, color: Fz.azul200);
  if (f['presente_at'] != null) return const StatusPill('Presente', icon: Icons.how_to_reg_rounded, color: Fz.azul100);
  return switch (estado) {
    'confirmada' => const StatusPill('Confirmada', icon: Icons.verified_rounded, color: Fz.azul100),
    'pago_en_revision' => const StatusPill('Pago en revisión', icon: Icons.hourglass_top_rounded, color: Fz.azul50),
    'pendiente_pago' => const StatusPill('Falta pagar', icon: Icons.payments_rounded, color: Fz.azul50, dashed: true),
    'precio_por_confirmar' =>
      const StatusPill('Precio por confirmar', icon: Icons.help_rounded, color: Fz.azul50, dashed: true),
    _ => StatusPill(estado ?? 'Sin estado', icon: Icons.info_rounded),
  };
}

/// Copia un código (FZ-…/VD-…) al portapapeles y avisa "Código copiado".
Future<void> copiarCodigo(BuildContext context, String codigo) async {
  if (codigo.isEmpty) return;
  await Clipboard.setData(ClipboardData(text: codigo));
  if (context.mounted) showInfo(context, 'Código copiado');
}

/// Código con icono de copiar (toca para copiar).
class CodigoCopiable extends StatelessWidget {
  const CodigoCopiable(this.codigo, {super.key, this.color = Fz.azul, this.style});
  final String codigo;
  final Color color;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    if (codigo.isEmpty) return const SizedBox.shrink();
    final st = style ?? Theme.of(context).textTheme.labelMedium?.copyWith(color: color);
    return Semantics(
      button: true,
      label: 'Copiar código $codigo',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => copiarCodigo(context, codigo),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 36),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(codigo, style: st, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 6),
              Icon(Icons.copy_rounded, size: 16, color: color),
            ]),
          ),
        ),
      ),
    );
  }
}

String fichaServicio(String? s) => switch (s) {
      'esterilizacion' => 'Esterilización',
      null => 'Servicio',
      _ => s.contains('dental') ? 'Limpieza dental' : s,
    };

/// Ficha de una inscripción (lo que ve el equipo al escanear el QR).
class FichaScreen extends StatefulWidget {
  const FichaScreen({super.key, required this.ficha});
  final Map<String, dynamic> ficha;

  @override
  State<FichaScreen> createState() => _FichaScreenState();
}

class _FichaScreenState extends State<FichaScreen> {
  late Map<String, dynamic> _f = widget.ficha;
  bool _busy = false;
  bool _cambio = false;

  String get _codigo => _f['codigo'] as String? ?? '';

  Future<void> _recargar() async {
    try {
      final f = await Data.buscarCodigo(_codigo);
      if (mounted) setState(() => _f = f);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _accion(Future<void> Function() fn, String ok) async {
    setState(() => _busy = true);
    try {
      await fn();
      _cambio = true;
      await _recargar();
      if (mounted) showInfo(context, ok);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _registrarCirugia() async {
    final r = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CirugiaFormScreen(ficha: _f)),
    );
    if (!mounted) return;
    if (r == true) {
      // "Siguiente mascota": volvemos directo al escáner o a la lista.
      Navigator.of(context).pop(true);
      return;
    }
    _cambio = true;
    await _recargar();
  }

  Future<void> _retirar() async {
    final ctrl = TextEditingController();
    final motivo = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Retirar de la jornada', textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('La mascota deja de estar inscrita en esta jornada. Escribe el motivo.',
              textAlign: TextAlign.center, style: Theme.of(ctx).textTheme.bodyMedium),
          const SizedBox(height: 14),
          TextField(
            controller: ctrl,
            autofocus: true,
            maxLines: 3,
            minLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Volver')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Fz.frambuesa),
            onPressed: () {
              final t = ctrl.text.trim();
              if (t.length < 3) return;
              Navigator.pop(ctx, t);
            },
            child: const Text('Retirar'),
          ),
        ],
      ),
    );
    ctrl.dispose();
    if (motivo == null || !mounted) return;
    await _accion(() => Data.retirarInscripcion(_f['id'] as String, motivo), 'Mascota retirada de la jornada.');
  }

  @override
  Widget build(BuildContext context) {
    final mode = AppMode.of(context);
    final t = Theme.of(context).textTheme;
    final pet = fichaMapa(_f['pet']);
    final jornada = fichaMapa(_f['jornada']);
    final prop = fichaMapa(_f['propietario']);
    final pago = _f['pago'] == null ? null : fichaMapa(_f['pago']);
    final cirugia = _f['cirugia'] == null ? null : fichaMapa(_f['cirugia']);
    final cancelada = _f['estado'] == 'cancelada';
    final atendida = fichaAtendida(_f);
    final presente = _f['presente_at'] != null;
    final nombre = pet['nombre'] as String? ?? 'Mascota';

    final acciones = <Widget>[
      if (!cancelada && !presente && !atendida)
        PopButton(
          label: 'Marcar llegada',
          icon: Icons.how_to_reg_rounded,
          loading: _busy,
          onPressed: () => _accion(() => Data.marcarPresente(_f['id'] as String), '$nombre marcada como presente.'),
        ),
      if (!cancelada && !atendida && (mode.isCirujano || mode.isAdmin))
        PopButton.tonal(
          label: 'Registrar cirugía',
          icon: Icons.medical_services_rounded,
          onPressed: _busy ? null : _registrarCirugia,
        ),
      if (!cancelada && !atendida && (mode.isAdmin || mode.isContador))
        PopButton.danger(
          label: 'Retirar de la jornada',
          icon: Icons.person_remove_rounded,
          onPressed: _busy ? null : _retirar,
        ),
    ];

    var i = 0;
    Widget item(Widget w) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: FadeSlideIn(index: i++, child: w),
        );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_cambio);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ficha'),
          leading: BackButton(onPressed: () => Navigator.of(context).pop(_cambio)),
        ),
        body: RefreshIndicator(
          onRefresh: _recargar,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              item(FzHero(
                title: nombre,
                subtitle: fichaDescripcion(pet),
                leading: FzAvatar(
                  url: Data.fotoUrl(pet['foto_path'] as String?),
                  text: iniciales(nombre),
                  icon: Icons.pets_rounded,
                  size: 108,
                ),
                child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 8, children: [
                  _HeroChip(
                    icon: Icons.qr_code_2_rounded,
                    text: _codigo,
                    onTap: () => copiarCodigo(context, _codigo),
                  ),
                  fichaEstadoPill(_f),
                  if (pet['braquiocefalico'] == true)
                    const StatusPill('Braquiocefálico', icon: Icons.warning_amber_rounded, color: Fz.azul50),
                  if (pet['esterilizada'] == true)
                    const StatusPill('Ya esterilizada', icon: Icons.info_rounded, color: Fz.azul50),
                ]),
              )),
              if (cancelada && _f['motivo_retiro'] != null)
                item(PopCard(
                  color: Fz.frambuesaSuave,
                  child: _Linea(icon: Icons.block_rounded, label: 'Motivo del retiro', value: _f['motivo_retiro'] as String),
                )),
              item(PopCard(
                color: Fz.azul50,
                child: Column(children: [
                  _Linea(
                    icon: Icons.event_rounded,
                    label: 'Jornada',
                    value: jornada['titulo'] as String? ?? '—',
                  ),
                  if (jornada['fecha_inicio'] != null)
                    _Linea(
                      icon: Icons.schedule_rounded,
                      label: 'Fecha',
                      value: Money.fechaLarga(DateTime.parse(jornada['fecha_inicio'] as String)),
                    ),
                  if (jornada['sede_nombre'] != null)
                    _Linea(icon: Icons.location_on_rounded, label: 'Sede', value: jornada['sede_nombre'] as String),
                  if (presente)
                    _Linea(
                      icon: Icons.how_to_reg_rounded,
                      label: 'Llegó',
                      value: Money.fechaLarga(DateTime.parse(_f['presente_at'] as String)),
                    ),
                ]),
              )),
              item(_Seccion(
                titulo: 'Propietario',
                child: Column(children: [
                  _Linea(icon: Icons.person_rounded, label: 'Nombre', value: prop['nombre'] as String? ?? '—'),
                  if (prop['telefono'] != null) _Telefono(telefono: prop['telefono'] as String),
                  if (prop['cedula'] != null)
                    _Linea(icon: Icons.badge_rounded, label: 'Cédula', value: prop['cedula'] as String),
                  if (prop['email'] != null)
                    _Linea(icon: Icons.mail_rounded, label: 'Correo', value: prop['email'] as String),
                ]),
              )),
              item(_Seccion(
                titulo: 'Servicio',
                color: Fz.azul50,
                child: Column(children: [
                  _Linea(
                    icon: Icons.medical_services_rounded,
                    label: 'Servicio',
                    value: fichaServicio(_f['servicio'] as String?),
                  ),
                  _Linea(
                    icon: Icons.inventory_2_rounded,
                    label: 'Kit post-operatorio',
                    value: _f['incluye_kit'] == true ? 'Sí' : 'No',
                  ),
                  _Linea(icon: Icons.healing_rounded, label: 'Cono', value: _f['incluye_cono'] == true ? 'Sí' : 'No'),
                  _Linea(
                    icon: Icons.sell_rounded,
                    label: 'Precio',
                    value: Money.usd(_f['precio_total_usd'] as num?),
                  ),
                  if (_f['ajuste_usd'] != null)
                    _Linea(
                      icon: Icons.add_circle_rounded,
                      label: 'Ajuste por patología',
                      value: '+${Money.usd(_f['ajuste_usd'] as num?)}',
                    ),
                ]),
              )),
              item(_Seccion(
                titulo: 'Pago',
                child: pago == null
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text('Sin pago registrado',
                            textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Fz.variante)),
                      )
                    : Column(children: [
                        _Linea(
                          icon: Icons.account_balance_wallet_rounded,
                          label: 'Método',
                          value: pago['metodo'] == 'efectivo_divisa' ? 'Efectivo en divisas' : 'Pago Móvil',
                        ),
                        _Linea(icon: Icons.fact_check_rounded, label: 'Estado', value: _estadoPago(pago['estado'] as String?)),
                        _Linea(
                          icon: Icons.attach_money_rounded,
                          label: 'Monto',
                          value: [
                            Money.usd(pago['monto_usd'] as num?),
                            if (pago['monto_bs'] != null) Money.bs(pago['monto_bs'] as num?),
                          ].join(' · '),
                        ),
                        if (pago['referencia'] != null)
                          _Linea(icon: Icons.tag_rounded, label: 'Referencia', value: pago['referencia'] as String),
                        if (pago['banco'] != null)
                          _Linea(icon: Icons.account_balance_rounded, label: 'Banco', value: pago['banco'] as String),
                      ]),
              )),
              if (cirugia != null)
                item(_Seccion(
                  titulo: 'Cirugía registrada',
                  color: Fz.azul100,
                  child: Column(children: [
                    if (cirugia['created_at'] != null)
                      _Linea(
                        icon: Icons.check_circle_rounded,
                        label: 'Registrada',
                        value: Money.fechaLarga(DateTime.parse(cirugia['created_at'] as String)),
                      ),
                    _Linea(
                      icon: Icons.biotech_rounded,
                      label: 'Patología reproductiva',
                      value: cirugia['patologia_reproductiva'] == true ? 'Sí (el costo se duplica)' : 'No',
                    ),
                  ]),
                )),
              for (final a in acciones) item(a),
            ]),
          ),
        ),
      ),
    );
  }

  static String _estadoPago(String? e) => switch (e) {
        'pendiente' => 'Por verificar',
        'verificado' => 'Verificado',
        'rechazado' => 'Rechazado',
        'anulado' => 'Anulado',
        _ => e ?? '—',
      };
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.text, this.onTap});
  final IconData icon;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        button: onTap != null,
        label: onTap != null ? 'Copiar código $text' : text,
        excludeSemantics: true,
        child: Material(
          color: Fz.azul900,
          shape: const StadiumBorder(side: BorderSide(color: Fz.tinta, width: 2)),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 16, color: Fz.tarjeta),
                const SizedBox(width: 4),
                Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 12.5, color: Fz.tarjeta)),
                if (onTap != null) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.copy_rounded, size: 15, color: Fz.tarjeta),
                ],
              ]),
            ),
          ),
        ),
      );
}

class _Seccion extends StatelessWidget {
  const _Seccion({required this.titulo, required this.child, this.color = Fz.tarjeta});
  final String titulo;
  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) => PopCard(
        color: color,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(titulo, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          child,
        ]),
      );
}

class _Linea extends StatelessWidget {
  const _Linea({required this.icon, required this.label, required this.value, this.trailing});
  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Icon(icon, size: 20, color: Fz.azul),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: t.bodySmall),
            Text(value, style: t.titleSmall),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}

class _Telefono extends StatelessWidget {
  const _Telefono({required this.telefono});
  final String telefono;

  /// 0414-1234567 -> 584141234567
  String get _wa {
    var d = telefono.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = d.substring(1);
    if (!d.startsWith('58')) d = '58$d';
    return d;
  }

  @override
  Widget build(BuildContext context) => _Linea(
        icon: Icons.phone_rounded,
        label: 'Teléfono',
        value: telefono,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            tooltip: 'Copiar teléfono',
            icon: const Icon(Icons.copy_rounded),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: telefono));
              if (context.mounted) showInfo(context, 'Teléfono copiado.');
            },
          ),
          IconButton(
            tooltip: 'Escribir por WhatsApp',
            icon: const Icon(Icons.chat_rounded),
            onPressed: () async {
              final ok = await abrirEnlace('https://wa.me/$_wa');
              if (!ok && context.mounted) showInfo(context, 'No pudimos abrir WhatsApp.');
            },
          ),
        ]),
      );
}
