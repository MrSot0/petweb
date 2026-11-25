import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'pet_form_screen.dart';

/// Precio estimado de esterilización para mostrar (el servidor recalcula al inscribir).
/// Devuelve null si el precio es "por confirmar" (braquiocefálico, perro > 30 kg o perro sin peso).
({double base, double conKit})? precioEsterilizacion(Precios precios, Pet p) {
  if (p.braqui) return null;
  if (p.esPerro && (p.pesoKg == null || p.pesoKg! <= 0 || p.pesoKg! > 30)) return null;
  final base = precios.base('esterilizacion', p);
  if (base == null) return null;
  return (base: base, conKit: base + precios.extra('kit', p.especie));
}

/// Recuadro con el precio base y con kit recomendado (y su equivalente en Bs si hay tasa).
class PrecioEstimadoBox extends StatelessWidget {
  const PrecioEstimadoBox({super.key, required this.precio, this.tasa, this.kit, this.titulo});

  final ({double base, double conKit})? precio;
  final Tasa? tasa;
  final double? kit;
  final String? titulo;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = precio;
    String bs(double usd) => tasa == null ? '' : ' · ${Money.bs(Money.aBs(usd, tasa!.valor))}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Fz.azulPastel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Fz.tinta, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(titulo ?? 'Precio estimado de esterilización', style: t.titleSmall),
        const SizedBox(height: 6),
        if (p == null) ...[
          Row(children: [
            const Icon(Icons.help_outline_rounded, size: 20),
            const SizedBox(width: 6),
            Text('Precio por confirmar', style: Fz.display(20)),
          ]),
          const SizedBox(height: 4),
          Text('Perros de más de 30 kg y razas de hocico corto: la administración fija el precio antes del pago.',
              style: t.bodySmall),
        ] else ...[
          Text('Precio base ${Money.usd(p.base)}${bs(p.base)}', style: t.bodyMedium),
          const SizedBox(height: 2),
          Text('Con kit recomendado ${Money.usd(p.conKit)}${bs(p.conKit)}', style: Fz.display(18, w: FontWeight.w700)),
          if (kit != null) Text('El kit post-operatorio (${Money.usd(kit)}) es opcional.', style: t.bodySmall),
          const SizedBox(height: 4),
          Text(
            tasa == null
                ? 'Tasa no disponible; el monto en Bs se confirma al pagar.'
                : tasa!.vieja
                    ? 'Tasa del ${Money.fecha(tasa!.fechaValor).substring(0, 5)}, puede variar.'
                    : 'Tasa BCV del euro ${Money.tasa(tasa!.valor)} · ${Money.fecha(tasa!.fechaValor)}',
            style: t.bodySmall,
          ),
        ],
      ]),
    );
  }
}

String edadTexto(int? meses) {
  if (meses == null) return 'Edad sin indicar';
  final a = meses ~/ 12, m = meses % 12;
  final pa = a == 0 ? '' : '$a ${a == 1 ? 'año' : 'años'}';
  final pm = m == 0 ? '' : '$m ${m == 1 ? 'mes' : 'meses'}';
  if (pa.isEmpty && pm.isEmpty) return 'Menos de 1 mes';
  return [pa, pm].where((s) => s.isNotEmpty).join(' y ');
}

class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.esPerro, this.size = 56});
  final bool esPerro;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: esPerro ? Fz.azulPastel : Fz.rosa,
          shape: BoxShape.circle,
          border: Border.all(color: Fz.tinta, width: Fz.borde),
        ),
        child: Icon(Icons.pets_rounded, color: Fz.tinta, size: size * .5),
      );
}

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  List<Pet>? _pets;
  Precios? _precios;
  Tasa? _tasa;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await Future.wait([Data.misMascotas(), Data.precios()]);
      Tasa? tasa;
      try {
        tasa = await Data.tasaVigente();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _pets = r[0] as List<Pet>;
        _precios = r[1] as Precios;
        _tasa = tasa;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _abrir([Pet? pet]) async {
    final cambio = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => PetFormScreen(pet: pet)));
    if (cambio == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis mascotas')),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (_error != null && _pets == null) {
      return EmptyState(
        icon: Icons.wifi_off_rounded,
        title: 'No pudimos cargar tus mascotas',
        message: friendlyError(_error!),
        action: PopButton(label: 'Reintentar', onPressed: _load, expand: false),
      );
    }
    if (_pets == null) return const Center(child: CircularProgressIndicator());
    final pets = _pets!;
    if (pets.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(children: [
          const SizedBox(height: 40),
          EmptyState(
            icon: Icons.pets_rounded,
            title: 'Aún no tienes mascotas',
            message: 'Regístrala para ver su precio estimado e inscribirla en una jornada.',
            action: PopButton(
                label: 'Agregar mascota', icon: Icons.add_rounded, onPressed: () => _abrir(), expand: false),
          ),
        ]),
      );
    }
    final t = Theme.of(context).textTheme;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text(
            '${pets.length} ${pets.length == 1 ? 'peludo registrado' : 'peludos registrados'}. Toca una tarjeta para editarla.',
            style: t.bodyMedium?.copyWith(color: Fz.variante),
          ),
          const SizedBox(height: 12),
          for (final p in pets) ...[
            PopCard(
              onTap: () => _abrir(p),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  PetAvatar(esPerro: p.esPerro),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p.nombre, style: t.titleLarge),
                      Text(p.descripcion, style: t.bodyMedium),
                      Text(edadTexto(p.edadMeses), style: t.bodySmall),
                    ]),
                  ),
                  const Icon(Icons.edit_rounded),
                ]),
                const SizedBox(height: 10),
                StatusPill(
                  p.esterilizada ? 'Esterilizada' : 'Sin esterilizar',
                  icon: p.esterilizada ? Icons.check_circle_rounded : Icons.schedule_rounded,
                  color: p.esterilizada ? Fz.azulPastel : Fz.rosaSuave,
                  dashed: !p.esterilizada,
                ),
                if (!p.esterilizada && _precios != null) ...[
                  const SizedBox(height: 10),
                  PrecioEstimadoBox(precio: precioEsterilizacion(_precios!, p), tasa: _tasa),
                ],
              ]),
            ),
            const SizedBox(height: 14),
          ],
          PopButton(label: 'Agregar mascota', icon: Icons.add_rounded, onPressed: () => _abrir()),
        ],
      ),
    );
  }
}
