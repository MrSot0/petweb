import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';

double? _parseMonto(String s) {
  var v = s.trim().replaceAll(RegExp(r'[\s$]'), '');
  if (v.isEmpty) return null;
  // Acepta "1.234,56", "1234,56" y "1234.56".
  if (v.contains(',')) v = v.replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(v);
}

/// Diálogo para fijar el precio total (USD) de una inscripción "precio por confirmar".
/// Devuelve true si se guardó.
Future<bool> dialogoFijarPrecio(BuildContext context, Map<String, dynamic> inscripcion) async {
  final pet = (inscripcion['pets'] as Map?) ?? const {};
  final ctrl = TextEditingController();
  final key = GlobalKey<FormState>();
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) {
      var saving = false;
      return StatefulBuilder(builder: (c, setD) {
        Future<void> guardar() async {
          if (!key.currentState!.validate()) return;
          setD(() => saving = true);
          try {
            await Data.fijarPrecio(inscripcion['id'] as String, _parseMonto(ctrl.text)!);
            if (c.mounted) Navigator.pop(c, true);
          } catch (e) {
            setD(() => saving = false);
            if (c.mounted) showError(c, e);
          }
        }

        final t = Theme.of(c).textTheme;
        return AlertDialog(
          title: const Text('Fijar precio', textAlign: TextAlign.center),
          content: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(
                '${pet['nombre'] ?? 'Mascota'}'
                '${pet['peso_kg'] != null ? ' · ${pet['peso_kg']} kg' : ''}'
                '${pet['braquiocefalico'] == true ? ' · braquiocefálico' : ''}',
                textAlign: TextAlign.center,
                style: t.titleMedium,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: ctrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: r'Precio total en $', prefixText: r'$ '),
                validator: (v) {
                  final n = _parseMonto(v ?? '');
                  if (n == null || n <= 0) return 'Escribe un monto mayor que cero';
                  if (n > 2000) return 'El monto parece demasiado alto';
                  return null;
                },
              ),
              const SizedBox(height: 6),
              Text('Incluye kit y cono si los eligió. El propietario podrá pagar después.',
                  textAlign: TextAlign.center, style: t.bodySmall),
            ]),
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(c, false), child: const Text('Cancelar')),
            TextButton(onPressed: saving ? null : guardar, child: Text(saving ? 'Guardando…' : 'Guardar')),
          ],
        );
      });
    },
  );
  ctrl.dispose();
  if (ok == true && context.mounted) showInfo(context, 'Precio fijado');
  return ok == true;
}

/// Inscripciones con "precio por confirmar" (solo administración).
class PreciosPorConfirmarScreen extends StatefulWidget {
  const PreciosPorConfirmarScreen({super.key});

  @override
  State<PreciosPorConfirmarScreen> createState() => _PreciosPorConfirmarScreenState();
}

class _PreciosPorConfirmarScreenState extends State<PreciosPorConfirmarScreen> {
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
      final r = await Data.inscripcionesPorConfirmarPrecio();
      if (mounted) setState(() => _items = r);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: AppBar(title: const Text('Precios por confirmar')), body: _body(context));
  }

  Widget _body(BuildContext context) {
    final items = _items;
    if (_error != null && items == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar la lista',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (items == null) return const Center(child: CircularProgressIndicator());
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        FadeSlideIn(
          child: FzHero(
            title: items.isEmpty ? 'Todo con precio' : '${items.length} por confirmar',
            subtitle: 'Perros de más de 30 kg o braquiocefálicos. Fija el precio para que el propietario pueda pagar.',
          ),
        ),
        const SizedBox(height: 16),
        if (items.isEmpty)
          const EmptyState(
            icon: Icons.task_alt_rounded,
            title: 'Nada por confirmar',
            message: 'Todas las inscripciones tienen precio.',
          ),
        for (var k = 0; k < items.length; k++) ...[
          FadeSlideIn(
            index: k + 1,
            child: Builder(builder: (context) {
              final i = items[k];
              final pet = (i['pets'] as Map?) ?? const {};
              final prof = (i['profiles'] as Map?) ?? const {};
              final jor = (i['jornadas'] as Map?) ?? const {};
              return PopCard(
                color: k.isEven ? Fz.tarjeta : Fz.azul50,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    FzAvatar(
                      icon: Icons.pets_rounded,
                      size: 44,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${pet['nombre'] ?? 'Mascota'}${pet['peso_kg'] != null ? ' · ${pet['peso_kg']} kg' : ''}',
                        style: t.titleLarge,
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                    [
                      pet['especie'] == 'gato' ? 'Gato' : 'Perro',
                      if (pet['braquiocefalico'] == true) 'braquiocefálico',
                      if (i['incluye_kit'] == true) 'con kit',
                      if (i['incluye_cono'] == true) 'con cono',
                    ].join(' · '),
                    style: t.bodyMedium,
                  ),
                  Text('${prof['nombre'] ?? 'Propietario'}${prof['telefono'] != null ? ' · ${prof['telefono']}' : ''}',
                      style: t.bodySmall),
                  if (jor['titulo'] != null) Text(jor['titulo'] as String, style: t.bodySmall),
                  if (i['precio_base_usd'] != null)
                    Text('Base calculada: ${Money.usd(i['precio_base_usd'] as num)}', style: t.bodySmall),
                  const SizedBox(height: 8),
                  const StatusPill('Precio por confirmar', icon: Icons.help_rounded, color: Fz.azul100, dashed: true),
                  const SizedBox(height: 12),
                  PopButton(
                    label: 'Fijar precio',
                    icon: Icons.sell_rounded,
                    onPressed: () async {
                      if (await dialogoFijarPrecio(context, i)) _load();
                    },
                  ),
                ]),
              );
            }),
          ),
          const SizedBox(height: 14),
        ],
      ]),
    );
  }
}
