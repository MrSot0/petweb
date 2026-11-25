import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'owner_shell.dart';
import 'registrar_pago_screen.dart';

/// Inscribir una o varias mascotas en una jornada.
class InscribirScreen extends StatefulWidget {
  const InscribirScreen({super.key, required this.jornada});
  final Jornada jornada;

  @override
  State<InscribirScreen> createState() => _InscribirScreenState();
}

class _Sel {
  bool esterilizacion = false;
  bool dental = false;
  bool kit = true;
  bool cono = false;
  bool get alguna => esterilizacion || dental;
}

class _Carga {
  _Carga(this.pets, this.precios, this.tasa);
  final List<Pet> pets;
  final Precios precios;
  final Tasa? tasa;
}

const _maxItems = 5; // límite de rpc_inscribir

class _InscribirScreenState extends State<InscribirScreen> {
  late Future<_Carga> _f = _load();
  final Map<String, _Sel> _sel = {};
  bool _enviando = false;

  Future<_Carga> _load() async {
    final petsF = Data.misMascotas();
    final preciosF = Data.precios();
    Tasa? tasa;
    try {
      tasa = await Data.tasaVigente();
    } catch (_) {}
    return _Carga(await petsF, await preciosF, tasa);
  }

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _f = f);
    try {
      await f;
    } catch (_) {}
  }

  _Sel _s(Pet p) => _sel.putIfAbsent(p.id, _Sel.new);

  /// Precio base mostrado; null = por confirmar. Un perro sin peso también queda por confirmar.
  double? _base(Precios pr, String servicio, Pet p) {
    if (p.esPerro && p.pesoKg == null) return null;
    return pr.base(servicio, p);
  }

  bool _puedeEsterilizar(Pet p) => !p.esterilizada;
  bool _habilitada(Pet p) => _puedeEsterilizar(p) || widget.jornada.limpiezaDental;

  int get _nItems => _sel.values.fold(0, (a, s) => a + (s.esterilizacion ? 1 : 0) + (s.dental ? 1 : 0));

  ({double total, bool porConfirmar}) _totales(_Carga c) {
    var total = 0.0;
    var pc = false;
    for (final p in c.pets) {
      final s = _sel[p.id];
      if (s == null) continue;
      if (s.esterilizacion) {
        final b = _base(c.precios, 'esterilizacion', p);
        if (b == null) {
          pc = true;
        } else {
          total += b + (s.kit ? c.precios.extra('kit', p.especie) : 0) + (s.cono ? c.precios.extra('cono', p.especie) : 0);
        }
      }
      if (s.dental) {
        final b = _base(c.precios, 'limpieza_dental', p);
        if (b == null) {
          pc = true;
        } else {
          total += b;
        }
      }
    }
    return (total: total, porConfirmar: pc);
  }

  void _toggle(Pet p, String servicio, bool v) {
    final s = _s(p);
    final actual = servicio == 'esterilizacion' ? s.esterilizacion : s.dental;
    if (v && !actual && _nItems >= _maxItems) {
      showInfo(context, 'Puedes inscribir hasta $_maxItems servicios a la vez.');
      return;
    }
    final libres = widget.jornada.cuposLibres;
    if (v && !actual && libres != null && _nItems >= libres) {
      showInfo(context, libres == 1 ? 'Solo queda 1 cupo en esta jornada.' : 'Solo quedan $libres cupos en esta jornada.');
      return;
    }
    setState(() {
      if (servicio == 'esterilizacion') {
        s.esterilizacion = v;
      } else {
        s.dental = v;
      }
    });
  }

  void _togglePet(Pet p) {
    final s = _s(p);
    if (s.alguna) {
      setState(() {
        s.esterilizacion = false;
        s.dental = false;
      });
    } else {
      _toggle(p, _puedeEsterilizar(p) ? 'esterilizacion' : 'limpieza_dental', true);
    }
  }

  Future<void> _confirmar(_Carga c) async {
    final items = <Map<String, dynamic>>[];
    for (final p in c.pets) {
      final s = _sel[p.id];
      if (s == null) continue;
      if (s.esterilizacion) {
        items.add({'pet_id': p.id, 'servicio': 'esterilizacion', 'kit': s.kit, 'cono': s.cono});
      }
      if (s.dental) {
        items.add({'pet_id': p.id, 'servicio': 'limpieza_dental', 'kit': false, 'cono': false});
      }
    }
    if (items.isEmpty) {
      showInfo(context, 'Marca al menos una mascota.');
      return;
    }
    setState(() => _enviando = true);
    try {
      final rows = await Data.inscribir(widget.jornada.id, items);
      if (!mounted) return;
      final nombres = {for (final p in c.pets) p.id: p.nombre};
      await _exito(rows, nombres);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _exito(List<Map<String, dynamic>> rows, Map<String, String> nombres) async {
    final t = Theme.of(context).textTheme;
    final pagables = rows.where((r) => r['estado'] == 'pendiente_pago').map((r) => r['id'] as String).toList();
    final hayPorConfirmar = rows.any((r) => r['estado'] == 'precio_por_confirmar');
    final pagar = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle_rounded, size: 48, color: Fz.azul),
        title: const Text('¡Inscripción lista!'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Guarda tus códigos. Los vas a mostrar el día de la jornada.', style: t.bodyMedium),
            const SizedBox(height: 12),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  const Icon(Icons.qr_code_2_rounded, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${r['codigo'] ?? ''}', style: Fz.display(18, w: FontWeight.w700)),
                      Text(
                        '${nombres[r['pet_id']] ?? 'Mascota'} · '
                        '${r['servicio'] == 'limpieza_dental' ? 'Limpieza dental' : 'Esterilización'} · '
                        '${r['precio_total_usd'] == null ? 'Precio por confirmar' : Money.usd(num.tryParse('${r['precio_total_usd']}'))}',
                        style: t.bodySmall,
                      ),
                    ]),
                  ),
                ]),
              ),
            if (hayPorConfirmar) ...[
              const SizedBox(height: 4),
              Text('La administración te dirá el precio antes de pagar en los casos por confirmar.', style: t.bodySmall),
            ],
            if (pagables.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Tu cupo queda confirmado cuando verifiquemos el pago.', style: t.bodyMedium),
            ],
          ]),
        ),
        actionsOverflowDirection: VerticalDirection.up,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(pagables.isEmpty ? 'Entendido' : 'Pagar después'),
          ),
          if (pagables.isNotEmpty)
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Pagar ahora')),
        ],
      ),
    );
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (pagar == true) {
      nav.popUntil((r) => r.isFirst);
      nav.push(MaterialPageRoute(builder: (_) => RegistrarPagoScreen(inscripcionIds: pagables)));
    } else {
      OwnerShell.irA(context, 3);
      nav.popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inscribir mascotas')),
      body: FutureBuilder<_Carga>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'No pudimos cargar tus mascotas',
              message: friendlyError(snap.error!),
              action: PopButton(label: 'Reintentar', icon: Icons.refresh_rounded, onPressed: _refresh, expand: false),
            );
          }
          final c = snap.data!;
          if (c.pets.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
                const SizedBox(height: 40),
                EmptyState(
                  icon: Icons.pets_rounded,
                  title: 'Primero registra a tu mascota',
                  message: 'Necesitamos su especie, sexo y peso para calcular el precio.',
                  action: PopButton(
                    label: 'Ir a Mis mascotas',
                    icon: Icons.add_rounded,
                    expand: false,
                    onPressed: () {
                      OwnerShell.irA(context, 2);
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                  ),
                ),
              ]),
            );
          }
          return _contenido(context, c);
        },
      ),
    );
  }

  Widget _contenido(BuildContext context, _Carga c) {
    final t = Theme.of(context).textTheme;
    final j = widget.jornada;
    final tot = _totales(c);
    final tasa = c.tasa;
    return Column(children: [
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              Text(j.titulo, style: t.titleLarge),
              Text('${Money.fechaLarga(j.fecha)} · ${j.sede}', style: t.bodyMedium),
              const SectionTitle('¿A quién inscribes?'),
              for (final p in c.pets) ...[_petCard(context, c, p), const SizedBox(height: 14)],
              const SizedBox(height: 4),
              PopCard(
                shadow: false,
                color: Fz.rosaSuave,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _nota(context, Icons.health_and_safety_rounded, 'Precios válidos para animales sanos.'),
                  _nota(context, Icons.priority_high_rounded,
                      'Patología reproductiva (piometra, parto difícil, TVT, testículo ectópico): el costo es el doble según especie y peso. Lo decide el cirujano.'),
                  _nota(context, Icons.medical_services_rounded, 'Prolapsos: requieren evaluación especial.'),
                ]),
              ),
            ],
          ),
        ),
      ),
      SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: Fz.cremaClaro,
            border: Border(top: BorderSide(color: Fz.tinta, width: 2)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_nItems == 0 ? 'Total' : 'Total · $_nItems ${_nItems == 1 ? 'servicio' : 'servicios'}', style: t.bodySmall),
                  Text(Money.usd(tot.total), style: Fz.display(28)),
                ]),
              ),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(tasa == null ? 'Bs por confirmar' : Money.bs(Money.aBs(tot.total, tasa.valor)), style: t.titleMedium),
                Text(
                  tasa == null
                      ? 'Tasa no disponible; el monto en Bs se confirma al pagar'
                      : tasa.vieja
                          ? 'Tasa del ${DateFormat('dd/MM').format(tasa.fechaValor)}, puede variar'
                          : 'Tasa euro BCV ${Money.fecha(tasa.fechaValor)}',
                  style: t.bodySmall,
                  textAlign: TextAlign.end,
                ),
              ]),
            ]),
            if (tot.porConfirmar)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text('+ servicios con precio por confirmar', style: t.bodySmall?.copyWith(fontWeight: FontWeight.w700)),
              ),
            const SizedBox(height: 10),
            PopButton(
              label: 'Confirmar inscripción',
              icon: Icons.check_rounded,
              loading: _enviando,
              onPressed: _nItems == 0 ? null : () => _confirmar(c),
            ),
          ]),
        ),
      ),
    ]);
  }

  Widget _petCard(BuildContext context, _Carga c, Pet p) {
    final t = Theme.of(context).textTheme;
    final s = _s(p);
    final habil = _habilitada(p);
    final kitUsd = c.precios.extra('kit', p.especie);
    final conoUsd = c.precios.extra('cono', p.especie);
    final baseE = _base(c.precios, 'esterilizacion', p);
    final baseD = _base(c.precios, 'limpieza_dental', p);
    return Opacity(
      opacity: habil ? 1 : .6,
      child: PopCard(
        color: s.alguna ? Fz.azulPastel : Fz.cremaClaro,
        padding: const EdgeInsets.fromLTRB(8, 8, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: habil ? () => _togglePet(p) : null,
            child: Row(children: [
              Transform.scale(
                scale: 1.35,
                child: Checkbox(value: s.alguna, onChanged: habil ? (_) => _togglePet(p) : null),
              ),
              const SizedBox(width: 4),
              Icon(p.esPerro ? Icons.pets_rounded : Icons.cruelty_free_rounded, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p.nombre, style: t.titleLarge),
                  Text(p.descripcion, style: t.bodyMedium),
                ]),
              ),
            ]),
          ),
          if (p.esterilizada)
            Padding(
              padding: const EdgeInsets.only(left: 12, top: 4),
              child: StatusPill(
                j.limpiezaDental ? 'Ya esterilizada · solo limpieza dental' : 'Ya esterilizada',
                icon: Icons.verified_rounded,
                color: Fz.cremaClaro,
              ),
            ),
          if (s.alguna) ...[
            const SizedBox(height: 6),
            if (_puedeEsterilizar(p))
              _servicio(
                context,
                titulo: 'Esterilización',
                valor: s.esterilizacion,
                precio: baseE,
                onChanged: (v) => _toggle(p, 'esterilizacion', v),
              ),
            if (s.esterilizacion) ...[
              if (baseE == null)
                _porConfirmar(context)
              else
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 4),
                  child: Text('Precio base ${Money.usd(baseE)} · Con kit recomendado ${Money.usd(baseE + kitUsd)}',
                      style: t.bodySmall),
                ),
              _extra(
                context,
                titulo: 'Kit post-operatorio',
                etiqueta: 'Recomendado (+${Money.usd(kitUsd)})',
                valor: s.kit,
                recomendado: true,
                onChanged: (v) => setState(() => s.kit = v),
              ),
              if (!s.kit)
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 0, 0, 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: Fz.frambuesa),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text('Sin el kit tendrás que comprar los medicamentos por tu cuenta.',
                          style: t.bodySmall?.copyWith(color: Fz.tinta, fontWeight: FontWeight.w700)),
                    ),
                  ]),
                ),
              _extra(
                context,
                titulo: 'Cono',
                etiqueta: 'Opcional (+${Money.usd(conoUsd)})',
                valor: s.cono,
                onChanged: (v) => setState(() => s.cono = v),
              ),
            ],
            if (j.limpiezaDental) ...[
              _servicio(
                context,
                titulo: 'Limpieza dental',
                sub: 'Con pulitura de esmalte',
                valor: s.dental,
                precio: baseD,
                onChanged: (v) => _toggle(p, 'limpieza_dental', v),
              ),
              if (s.dental && baseD == null) _porConfirmar(context),
            ],
          ],
        ]),
      ),
    );
  }

  Jornada get j => widget.jornada;

  Widget _servicio(BuildContext context,
      {required String titulo, String? sub, required bool valor, required double? precio, required ValueChanged<bool> onChanged}) {
    final t = Theme.of(context).textTheme;
    return CheckboxListTile(
      value: valor,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.only(left: 4),
      dense: false,
      title: Text(titulo, style: t.titleMedium),
      subtitle: sub == null ? null : Text(sub, style: t.bodySmall),
      secondary: Text(precio == null ? 'Por confirmar' : Money.usd(precio), style: Fz.display(18, w: FontWeight.w700)),
    );
  }

  Widget _extra(BuildContext context,
      {required String titulo,
      required String etiqueta,
      required bool valor,
      bool recomendado = false,
      required ValueChanged<bool> onChanged}) {
    final t = Theme.of(context).textTheme;
    return CheckboxListTile(
      value: valor,
      onChanged: (v) => onChanged(v ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: const EdgeInsets.only(left: 28),
      title: Text('$titulo · $etiqueta', style: t.titleSmall),
      secondary: recomendado ? const Icon(Icons.thumb_up_rounded, size: 20) : null,
    );
  }

  Widget _porConfirmar(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 0, 6),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.hourglass_top_rounded, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text('Precio por confirmar: la administración te dirá el precio antes de pagar.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Fz.tinta, fontWeight: FontWeight.w700)),
          ),
        ]),
      );

  Widget _nota(BuildContext context, IconData ic, String tx) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(ic, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(tx, style: Theme.of(context).textTheme.bodyMedium)),
        ]),
      );
}
