import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

/// Datos de cobro de la organización (solo administración): Pago Móvil y efectivo en divisas.
class DatosCobroScreen extends StatefulWidget {
  const DatosCobroScreen({super.key});

  @override
  State<DatosCobroScreen> createState() => _DatosCobroScreenState();
}

class _DatosCobroScreenState extends State<DatosCobroScreen> {
  List<Map<String, dynamic>>? _items;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Data.datosCobro();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _editar([Map<String, dynamic>? d]) async {
    final r = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DatoCobroFormScreen(dato: d, ordenSiguiente: (_items?.length ?? 0) + 1)),
    );
    if (r == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos de cobro')),
      floatingActionButton: _items == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _editar(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Agregar'),
            ),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    final items = _items;
    if (_error != null && items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar los datos de cobro',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (items == null) return const Center(child: CircularProgressIndicator());
    final activos = items.where((d) => d['activo'] == true).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 100), children: [
        FadeSlideIn(
          child: FzHero(
            title: '$activos activos',
            subtitle: 'Así ven los propietarios dónde pagar. Solo se muestran los activos. Toca uno para editarlo.',
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.account_balance_rounded,
            title: 'Sin datos de cobro',
            message: 'Agrega un Pago Móvil o instrucciones de efectivo.',
          ),
        for (var k = 0; k < items.length; k++) ...[
          FadeSlideIn(
            index: k + 1,
            child: DatoCobroPreview(
              dato: items[k],
              onTap: () => _editar(items[k]),
              estado: items[k]['activo'] == true
                  ? const StatusPill('Activo', icon: Icons.visibility_rounded, color: Fz.azul100)
                  : const StatusPill('Inactivo', icon: Icons.visibility_off_rounded, color: Fz.tarjeta, dashed: true),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ]),
    );
  }
}

/// Vista previa de un dato de cobro tal como lo ve el propietario.
class DatoCobroPreview extends StatelessWidget {
  const DatoCobroPreview({super.key, required this.dato, this.onTap, this.estado});
  final Map<String, dynamic> dato;
  final VoidCallback? onTap;
  final Widget? estado;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pm = dato['tipo'] == 'pago_movil';
    Widget fila(String k, String? v) => (v == null || v.isEmpty)
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Row(children: [
              SizedBox(width: 90, child: Text(k, style: t.bodySmall)),
              Expanded(child: Text(v, style: t.titleMedium)),
            ]),
          );
    return PopCard(
      onTap: onTap,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(pm ? Icons.account_balance_rounded : Icons.payments_rounded, color: Fz.azul),
          const SizedBox(width: 8),
          Expanded(child: Text(pm ? 'Pago Móvil' : 'Efectivo en divisas', style: t.titleLarge)),
          ?estado,
        ]),
        const SizedBox(height: 4),
        if (pm) ...[
          fila('Banco', dato['banco'] as String?),
          fila('Teléfono', dato['telefono'] as String?),
          fila('Cédula/RIF', dato['cedula_rif'] as String?),
          fila('Titular', dato['titular'] as String?),
        ],
        if ((dato['instrucciones'] as String?)?.isNotEmpty == true)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(dato['instrucciones'] as String, style: t.bodyMedium),
          ),
      ]),
    );
  }
}

class DatoCobroFormScreen extends StatefulWidget {
  const DatoCobroFormScreen({super.key, this.dato, this.ordenSiguiente = 1});
  final Map<String, dynamic>? dato;
  final int ordenSiguiente;

  @override
  State<DatoCobroFormScreen> createState() => _DatoCobroFormScreenState();
}

class _DatoCobroFormScreenState extends State<DatoCobroFormScreen> {
  static final _telRe = RegExp(r'^0(412|414|416|422|424|426)\d{7}$');
  final _key = GlobalKey<FormState>();
  late String _tipo;
  late bool _activo;
  late final TextEditingController _banco, _tel, _ced, _tit, _inst;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final d = widget.dato ?? const {};
    _tipo = (d['tipo'] as String?) ?? 'pago_movil';
    _activo = (d['activo'] as bool?) ?? true;
    _banco = TextEditingController(text: d['banco'] as String? ?? '');
    _tel = TextEditingController(text: d['telefono'] as String? ?? '');
    _ced = TextEditingController(text: d['cedula_rif'] as String? ?? '');
    _tit = TextEditingController(text: d['titular'] as String? ?? '');
    _inst = TextEditingController(text: d['instrucciones'] as String? ?? '');
  }

  @override
  void dispose() {
    for (final c in [_banco, _tel, _ced, _tit, _inst]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic> get _datos {
    String? v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final pm = _tipo == 'pago_movil';
    return {
      'tipo': _tipo,
      'banco': pm ? v(_banco) : null,
      'telefono': pm ? v(_tel)?.replaceAll(RegExp(r'[\s-]'), '') : null,
      'cedula_rif': pm ? v(_ced)?.toUpperCase() : null,
      'titular': pm ? v(_tit) : null,
      'instrucciones': v(_inst),
      'activo': _activo,
    };
  }

  Future<void> _guardar() async {
    if (!_key.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final datos = _datos;
      if (widget.dato == null) datos['orden'] = widget.ordenSiguiente;
      await Data.guardarDatoCobro(datos, id: (widget.dato?['id'] as num?)?.toInt());
      if (!mounted) return;
      showInfo(context, 'Datos de cobro guardados');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showError(context, e);
      }
    }
  }

  Widget _tipoCard(String tipo, String label, IconData icon) {
    final sel = _tipo == tipo;
    final t = Theme.of(context).textTheme;
    return Expanded(
      child: Semantics(
        selected: sel,
        button: true,
        child: PopCard(
          color: sel ? Fz.azul : Fz.tarjeta,
          shadow: sel,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
          onTap: () => setState(() => _tipo = tipo),
          child: Column(children: [
            Icon(icon, color: sel ? Fz.tarjeta : Fz.azul),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: t.titleSmall?.copyWith(color: sel ? Fz.tarjeta : Fz.tinta)),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final pm = _tipo == 'pago_movil';
    const gap = SizedBox(height: 14);
    String? req(String? v) => (v ?? '').trim().isEmpty ? 'Este campo es obligatorio' : null;
    return Scaffold(
      appBar: AppBar(title: Text(widget.dato == null ? 'Nuevo dato de cobro' : 'Editar dato de cobro')),
      body: Form(
        key: _key,
        onChanged: () => setState(() {}),
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
          Text('Tipo', textAlign: TextAlign.center, style: t.titleSmall),
          const SizedBox(height: 8),
          Row(children: [
            _tipoCard('pago_movil', 'Pago Móvil', Icons.account_balance_rounded),
            const SizedBox(width: 12),
            _tipoCard('efectivo_divisa', 'Efectivo en divisas', Icons.payments_rounded),
          ]),
          gap,
          if (pm) ...[
            TextFormField(
              controller: _banco,
              decoration: const InputDecoration(labelText: 'Banco', hintText: '0102 Banco de Venezuela'),
              validator: req,
            ),
            gap,
            TextFormField(
              controller: _tel,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono', hintText: '04141234567'),
              validator: (v) => _telRe.hasMatch((v ?? '').replaceAll(RegExp(r'[\s-]'), ''))
                  ? null
                  : 'Teléfono no válido (ej. 04141234567)',
            ),
            gap,
            TextFormField(
              controller: _ced,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Cédula o RIF', hintText: 'J-12345678-9'),
              validator: (v) =>
                  RegExp(r'^[VEJGPvejgp]-?\d{5,9}(-?\d)?$').hasMatch((v ?? '').trim()) ? null : 'Ej. V-12345678 o J-12345678-9',
            ),
            gap,
            TextFormField(
              controller: _tit,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Titular'),
              validator: req,
            ),
            gap,
          ],
          TextFormField(
            controller: _inst,
            maxLines: 4,
            minLines: 2,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: pm ? 'Instrucciones (opcional)' : 'Instrucciones',
              hintText: pm ? null : 'Paga en efectivo el día de la jornada en la mesa de registro.',
            ),
            validator: pm ? null : req,
          ),
          PopCard(
            shadow: false,
            color: Fz.azul50,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: SwitchListTile(
              value: _activo,
              onChanged: (v) => setState(() => _activo = v),
              title: Text('Activo', style: t.titleMedium),
              subtitle: Text(_activo ? 'Los propietarios lo ven al pagar' : 'Oculto para los propietarios',
                  style: t.bodySmall),
            ),
          ),
          const SizedBox(height: 22),
          Text('Vista previa', textAlign: TextAlign.center, style: t.headlineSmall),
          Text('Así lo verá el propietario:', textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 10),
          DatoCobroPreview(dato: _datos),
          const SizedBox(height: 24),
          PopButton(
            label: 'Guardar',
            icon: Icons.save_rounded,
            loading: _saving,
            onPressed: _saving ? null : _guardar,
          ),
        ]),
      ),
    );
  }
}
