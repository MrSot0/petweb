import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/data.dart';
import '../../core/money.dart';
import '../../core/theme.dart';
import '../../core/webp.dart';
import '../../core/widgets.dart';
import '../scan/ficha_screen.dart';

/// Registro de la cirugía, pensado para usar con guantes (objetivos táctiles ≥ 56 dp).
/// Devuelve `true` al pulsar "Siguiente mascota".
class CirugiaFormScreen extends StatefulWidget {
  const CirugiaFormScreen({super.key, required this.ficha});
  final Map<String, dynamic> ficha;

  @override
  State<CirugiaFormScreen> createState() => _CirugiaFormScreenState();
}

class _CirugiaFormScreenState extends State<CirugiaFormScreen> {
  late final Map<String, dynamic> _pet = fichaMapa(widget.ficha['pet']);
  late String _especie = _pet['especie'] as String? ?? 'perro';
  late String _sexo = _pet['sexo'] as String? ?? 'hembra';
  final _obs = TextEditingController();
  XFile? _foto;
  Uint8List? _fotoBytes;
  bool _patologia = false;
  bool _prolapso = false;
  bool _guardando = false;
  bool _fotoFalta = false;
  Map<String, dynamic>? _resultado;

  @override
  void dispose() {
    _obs.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto({bool camara = true}) async {
    try {
      final x = await WebpPipeline.elegir(camara: camara);
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (!mounted) return;
      setState(() {
        _foto = x;
        _fotoBytes = bytes;
        _fotoFalta = false;
      });
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _guardar() async {
    if (_foto == null || _fotoBytes == null) {
      setState(() => _fotoFalta = true);
      showInfo(context, 'Falta la foto de la mascota operada.');
      return;
    }
    setState(() => _guardando = true);
    try {
      final id = widget.ficha['id'] as String;
      final path = await Data.subirFotoCirugia(_foto!, id);
      final r = await Data.registrarCirugia(
        inscripcionId: id,
        especie: _especie,
        sexo: _sexo,
        fotoPath: path,
        patologia: _patologia,
        prolapso: _prolapso,
        observaciones: _obs.text.trim().isEmpty ? null : _obs.text.trim(),
      );
      if (mounted) setState(() => _resultado = r);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_resultado != null) return _exito(context);
    final t = Theme.of(context).textTheme;
    final nombre = _pet['nombre'] as String? ?? 'Mascota';
    final prop = fichaMapa(widget.ficha['propietario']);
    return Scaffold(
      appBar: AppBar(title: const Text('Registrar cirugía')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          FadeSlideIn(
            child: PopCard(
              color: Fz.azul50,
              child: Row(children: [
                FzAvatar(
                  url: Data.fotoUrl(_pet['foto_path'] as String?),
                  text: iniciales(nombre),
                  icon: Icons.pets_rounded,
                  size: 56,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nombre, style: t.titleLarge),
                    Text(
                      [widget.ficha['codigo'], prop['nombre']].whereType<String>().join(' · '),
                      style: t.bodySmall,
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          _titulo(context, 'Foto de la mascota operada', 'Obligatoria'),
          FadeSlideIn(index: 1, child: _fotoCard(context)),
          _titulo(context, 'Especie'),
          FadeSlideIn(
            index: 2,
            child: Row(children: [
              Expanded(
                child: _Opcion(
                  icon: Icons.pets_rounded,
                  label: 'Perro',
                  selected: _especie == 'perro',
                  onTap: () => setState(() => _especie = 'perro'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Opcion(
                  icon: Icons.cruelty_free_rounded,
                  label: 'Gato',
                  selected: _especie == 'gato',
                  onTap: () => setState(() => _especie = 'gato'),
                ),
              ),
            ]),
          ),
          _titulo(context, 'Sexo'),
          FadeSlideIn(
            index: 3,
            child: Row(children: [
              Expanded(
                child: _Opcion(
                  icon: Icons.male_rounded,
                  label: 'Macho',
                  selected: _sexo == 'macho',
                  onTap: () => setState(() => _sexo = 'macho'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Opcion(
                  icon: Icons.female_rounded,
                  label: 'Hembra',
                  selected: _sexo == 'hembra',
                  onTap: () => setState(() => _sexo = 'hembra'),
                ),
              ),
            ]),
          ),
          _titulo(context, 'Hallazgos'),
          FadeSlideIn(
            index: 4,
            child: PopCard(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Column(children: [
                _Interruptor(
                  value: _patologia,
                  onChanged: (v) => setState(() => _patologia = v),
                  title: 'Patología reproductiva',
                  subtitle: 'Piometra, TVT, testículo ectópico… El costo se duplica.',
                ),
                const Divider(height: 1),
                _Interruptor(
                  value: _prolapso,
                  onChanged: (v) => setState(() => _prolapso = v),
                  title: 'Prolapso',
                  subtitle: 'Requiere evaluación especial.',
                ),
              ]),
            ),
          ),
          _titulo(context, 'Observaciones', 'Opcional'),
          FadeSlideIn(
            index: 5,
            child: TextField(
              controller: _obs,
              minLines: 3,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(hintText: 'Notas o complicaciones'),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 60,
            child: PopButton(
              label: 'Guardar cirugía',
              icon: Icons.check_rounded,
              loading: _guardando,
              onPressed: _guardar,
            ),
          ),
        ],
      ),
    );
  }

  Widget _titulo(BuildContext context, String text, [String? extra]) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Text.rich(
        TextSpan(text: text, children: [
          if (extra != null) TextSpan(text: '  ·  $extra', style: t.bodySmall),
        ]),
        textAlign: TextAlign.center,
        style: t.titleMedium,
      ),
    );
  }

  Widget _fotoCard(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_foto == null || _fotoBytes == null) {
      return PopCard(
        color: _fotoFalta ? Fz.frambuesaSuave : Fz.azul100,
        onTap: _guardando ? null : _tomarFoto,
        child: SizedBox(
          height: 150,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.add_a_photo_rounded, size: 48, color: Fz.azul),
            const SizedBox(height: 8),
            Text('Tomar foto', style: t.titleLarge),
            Text(
              _fotoFalta ? 'Sin foto no se puede guardar' : 'Encuadra a la mascota completa',
              textAlign: TextAlign.center,
              style: t.bodySmall,
            ),
            TextButton(
              onPressed: _guardando ? null : () => _tomarFoto(camara: false),
              child: const Text('Elegir de la galería'),
            ),
          ]),
        ),
      );
    }
    return PopCard(
      padding: const EdgeInsets.all(10),
      child: Column(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: AspectRatio(aspectRatio: 4 / 3, child: Image.memory(_fotoBytes!, fit: BoxFit.cover, gaplessPlayback: true)),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 56,
          child: OutlinedButton.icon(
            onPressed: _guardando ? null : _tomarFoto,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Repetir foto'),
          ),
        ),
      ]),
    );
  }

  Widget _exito(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final r = _resultado!;
    final ajuste = r['ajuste_usd'] as num?;
    final nombre = _pet['nombre'] as String? ?? 'Mascota';
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(true);
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeSlideIn(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: Fz.azul,
                      shape: BoxShape.circle,
                      border: Border.all(color: Fz.tinta, width: Fz.borde),
                      boxShadow: const [BoxShadow(color: Fz.tinta, offset: Fz.sombra)],
                    ),
                    child: const Icon(Icons.check_rounded, size: 60, color: Fz.tarjeta),
                  ),
                  const SizedBox(height: 20),
                  Text('¡$nombre registrado!', textAlign: TextAlign.center, style: t.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    '${_especie == 'perro' ? 'Perro' : 'Gato'} · ${_sexo == 'macho' ? 'Macho' : 'Hembra'}',
                    textAlign: TextAlign.center,
                    style: t.bodyMedium?.copyWith(color: Fz.variante),
                  ),
                  if (_patologia) ...[
                    const SizedBox(height: 18),
                    PopCard(
                      color: Fz.azul100,
                      child: Row(children: [
                        const Icon(Icons.info_rounded, color: Fz.azul),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ajuste != null && ajuste > 0
                                ? 'Patología reproductiva: el costo se duplica. Ajuste de ${Money.usd(ajuste)} '
                                    'que la administración le cobrará al propietario.'
                                : 'Patología reproductiva: el costo se duplica. La administración confirmará el ajuste.',
                            style: t.bodyMedium,
                          ),
                        ),
                      ]),
                    ),
                  ],
                  if (_prolapso) ...[
                    const SizedBox(height: 12),
                    Text('Prolapso marcado para evaluación especial.',
                        textAlign: TextAlign.center, style: t.bodySmall),
                  ],
                  const SizedBox(height: 28),
                  SizedBox(
                    height: 60,
                    child: PopButton(
                      label: 'Siguiente mascota',
                      icon: Icons.qr_code_scanner_rounded,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Tarjeta grande seleccionable: seleccionada = azul sólido con texto claro.
class _Opcion extends StatelessWidget {
  const _Opcion({required this.icon, required this.label, required this.selected, required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Fz.tarjeta : Fz.tinta;
    return Semantics(
      selected: selected,
      button: true,
      child: PopCard(
        color: selected ? Fz.azul : Fz.tarjeta,
        shadow: selected,
        onTap: onTap,
        padding: EdgeInsets.zero,
        child: SizedBox(
          height: 92,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 34, color: fg),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (selected) ...[Icon(Icons.check_circle_rounded, size: 16, color: fg), const SizedBox(width: 4)],
              Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg)),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _Interruptor extends StatelessWidget {
  const _Interruptor({required this.value, required this.onChanged, required this.title, required this.subtitle});
  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: SwitchListTile(
          value: value,
          onChanged: onChanged,
          title: Text(title),
          subtitle: Text(subtitle),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        ),
      );
}
