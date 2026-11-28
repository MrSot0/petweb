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
        color: Fz.azul100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Fz.tinta, width: 2),
      ),
      child: Column(children: [
        Text(titulo ?? 'Precio estimado de esterilización', textAlign: TextAlign.center, style: t.titleSmall),
        const SizedBox(height: 6),
        if (p == null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.help_outline_rounded, size: 20),
            const SizedBox(width: 6),
            Text('Precio por confirmar', style: t.titleLarge),
          ]),
          const SizedBox(height: 4),
          Text('Perros de más de 30 kg y razas de hocico corto: la administración fija el precio antes del pago.',
              textAlign: TextAlign.center, style: t.bodySmall),
        ] else ...[
          Text('Con kit recomendado', textAlign: TextAlign.center, style: t.bodySmall),
          Text(Money.usd(p.conKit), textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(color: Fz.azul700)),
          if (tasa != null) Text(Money.bs(Money.aBs(p.conKit, tasa!.valor)), textAlign: TextAlign.center, style: t.titleSmall),
          const SizedBox(height: 2),
          Text('Precio base ${Money.usd(p.base)}${bs(p.base)}', textAlign: TextAlign.center, style: t.bodyMedium),
          if (kit != null)
            Text('El kit post-operatorio (${Money.usd(kit)}) es opcional.', textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 4),
          Text(
            textAlign: TextAlign.center,
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

/// Avatar de mascota: su foto si la tiene; si no, una huella.
class PetAvatar extends StatelessWidget {
  const PetAvatar({super.key, required this.esPerro, this.size = 56, this.url});
  final bool esPerro;
  final double size;
  final String? url;

  @override
  Widget build(BuildContext context) => FzAvatar(
        url: url,
        size: size,
        icon: esPerro ? Icons.pets_rounded : Icons.cruelty_free_rounded,
        color: esPerro ? Fz.azul100 : Fz.azul200,
      );
}

class PetsScreen extends StatefulWidget {
  const PetsScreen({super.key});

  @override
  State<PetsScreen> createState() => _PetsScreenState();
}

class _PetsScreenState extends State<PetsScreen> {
  Widget _petCard(BuildContext context, Pet p, bool alterna) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: alterna ? Fz.azul50 : Fz.tarjeta,
      onTap: () => _abrir(p),
      child: Column(children: [
        Row(children: [
          PetAvatar(esPerro: p.esPerro, url: p.fotoUrl, size: 68),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p.nombre, style: t.titleLarge),
              Text(p.descripcion, style: t.bodyMedium),
              Text(edadTexto(p.edadMeses), style: t.bodySmall),
              const SizedBox(height: 6),
              StatusPill(
                p.esterilizada ? 'Esterilizada' : 'Sin esterilizar',
                icon: p.esterilizada ? Icons.check_circle_rounded : Icons.schedule_rounded,
                color: p.esterilizada ? Fz.azul100 : Fz.tarjeta,
                dashed: !p.esterilizada,
              ),
            ]),
          ),
          const Icon(Icons.edit_rounded, color: Fz.azul),
        ]),
        if (!p.esterilizada && _precios != null) ...[
          const SizedBox(height: 12),
          PrecioEstimadoBox(precio: precioEsterilizacion(_precios!, p), tasa: _tasa),
        ],
      ]),
    );
  }

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
        child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.all(16), children: [
          const FzHero(
            title: 'Mis mascotas',
            subtitle: 'Registra a tus perros y gatos',
            leading: Icon(Icons.pets_rounded, size: 36, color: Fz.tarjeta),
          ),
          const SizedBox(height: 12),
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
    final sinEsterilizar = pets.where((p) => !p.esterilizada).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          FadeSlideIn(
            child: FzHero(
              title: 'Mis mascotas',
              subtitle: '${pets.length} ${pets.length == 1 ? 'peludo registrado' : 'peludos registrados'}'
                  '${sinEsterilizar > 0 ? ' · $sinEsterilizar sin esterilizar' : ''}',
              leading: SizedBox(
                height: 56,
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  for (final p in pets.take(4))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: PetAvatar(esPerro: p.esPerro, url: p.fotoUrl, size: 50),
                    ),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text('Toca una tarjeta para editarla o agregarle foto.',
              textAlign: TextAlign.center, style: t.bodySmall),
          const SizedBox(height: 12),
          for (var i = 0; i < pets.length; i++) ...[
            FadeSlideIn(index: i + 1, child: _petCard(context, pets[i], i.isOdd)),
            const SizedBox(height: 14),
          ],
          PopButton(label: 'Agregar mascota', icon: Icons.add_rounded, onPressed: () => _abrir()),
        ],
      ),
    );
  }
}
