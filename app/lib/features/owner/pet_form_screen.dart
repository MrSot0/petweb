import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/webp.dart';
import '../../core/widgets.dart';
import 'pets_screen.dart';

/// Registrar o editar una mascota. Devuelve `true` al hacer pop si hubo cambios.
class PetFormScreen extends StatefulWidget {
  const PetFormScreen({super.key, this.pet});
  final Pet? pet;

  @override
  State<PetFormScreen> createState() => _PetFormScreenState();
}

class _PetFormScreenState extends State<PetFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _nombre;
  late final TextEditingController _peso;
  late final TextEditingController _notas;
  String? _especie;
  String? _sexo;
  int _anios = 0;
  int _meses = 0;
  bool? _braqui;
  bool _guardando = false;
  bool _borrando = false;
  Precios? _precios;
  Tasa? _tasa;
  String? _fotoPath;
  bool _subiendoFoto = false;

  bool get _editando => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final p = widget.pet;
    _nombre = TextEditingController(text: p?.nombre ?? '');
    _peso = TextEditingController(
        text: p?.pesoKg?.toStringAsFixed(p.pesoKg! % 1 == 0 ? 0 : 1).replaceAll('.', ',') ?? '');
    _notas = TextEditingController(text: (p?.m['notas'] as String?) ?? '');
    _especie = p?.especie;
    _sexo = p?.sexo;
    _anios = (p?.edadMeses ?? 0) ~/ 12;
    _meses = (p?.edadMeses ?? 0) % 12;
    _braqui = p?.braqui;
    _fotoPath = p?.m['foto_path'] as String?;
    _peso.addListener(() => setState(() {}));
    _cargarPrecios();
  }

  Future<void> _cargarPrecios() async {
    try {
      final pr = await Data.precios();
      if (mounted) setState(() => _precios = pr);
      final t = await Data.tasaVigente();
      if (mounted) setState(() => _tasa = t);
    } catch (_) {
      // El recuadro de precio simplemente no se muestra.
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _peso.dispose();
    _notas.dispose();
    super.dispose();
  }

  double? get _pesoKg {
    final s = _peso.text.trim().replaceAll(',', '.');
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  Map<String, dynamic> _datos() => {
        'nombre': _nombre.text.trim(),
        'especie': _especie,
        'sexo': _sexo,
        'edad_meses': _anios * 12 + _meses,
        'peso_kg': _pesoKg,
        'braquiocefalico': _braqui == true,
        'notas': _notas.text.trim().isEmpty ? null : _notas.text.trim(),
        'foto_path': _fotoPath,
      };

  Future<void> _elegirFoto() async {
    final camara = await showModalBottomSheet<bool>(
      context: context,
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('Foto de tu mascota', textAlign: TextAlign.center, style: Theme.of(c).textTheme.headlineSmall),
            const SizedBox(height: 14),
            PopButton(label: 'Tomar foto', icon: Icons.photo_camera_rounded, onPressed: () => Navigator.pop(c, true)),
            const SizedBox(height: 10),
            PopButton.tonal(label: 'Elegir de la galería', icon: Icons.photo_library_rounded, onPressed: () => Navigator.pop(c, false)),
            if (_fotoPath != null) ...[
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(c);
                  setState(() => _fotoPath = null);
                },
                style: TextButton.styleFrom(foregroundColor: Fz.frambuesa),
                icon: const Icon(Icons.delete_outline_rounded),
                label: const Text('Quitar foto'),
              ),
            ],
          ]),
        ),
      ),
    );
    if (camara == null || !mounted) return;
    try {
      final x = await WebpPipeline.elegir(camara: camara);
      if (x == null) return;
      setState(() => _subiendoFoto = true);
      final path = await Data.subirFoto(x, carpeta: 'mascotas');
      if (mounted) setState(() => _fotoPath = path);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _subiendoFoto = false);
    }
  }

  Future<void> _guardar() async {
    if (!_form.currentState!.validate()) return;
    if (_especie == null || _sexo == null || _braqui == null) {
      showInfo(context, 'Elige especie, sexo y si es de hocico corto.');
      return;
    }
    setState(() => _guardando = true);
    try {
      await Data.guardarMascota(_datos(), id: widget.pet?.id);
      if (!mounted) return;
      showInfo(context, _editando ? 'Cambios guardados' : 'Mascota registrada');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _borrar() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text('¿Eliminar a ${widget.pet!.nombre}?'),
        content: const Text('Se borrará su ficha. Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('No, volver')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            style: TextButton.styleFrom(foregroundColor: Fz.frambuesa),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _borrando = true);
    try {
      await Data.borrarMascota(widget.pet!.id);
      if (!mounted) return;
      showInfo(context, 'Mascota eliminada');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      if (s.contains('23503') || s.contains('foreign key') || s.contains('inscripciones')) {
        showInfo(context,
            'No se puede eliminar: tiene inscripciones o citas registradas. Si ya no irá, cancela su inscripción desde Mis citas.');
      } else {
        showError(context, e);
      }
    } finally {
      if (mounted) setState(() => _borrando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final esPerro = _especie == 'perro';
    return Scaffold(
      appBar: AppBar(title: Text(_editando ? 'Editar mascota' : 'Registrar mascota')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Center(child: _FotoPicker(
              url: Data.fotoUrl(_fotoPath),
              esPerro: esPerro,
              cargando: _subiendoFoto,
              onTap: _subiendoFoto || _guardando ? null : _elegirFoto,
            )),
            const SizedBox(height: 18),
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe su nombre' : null,
            ),
            const _Titulo('Especie'),
            Row(children: [
              Expanded(
                child: _BigChoice(
                  label: 'Perro',
                  sub: 'Perra o perro',
                  selected: _especie == 'perro',
                  icon: Icons.pets_rounded,
                  onTap: () => setState(() => _especie = 'perro'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigChoice(
                  label: 'Gato',
                  sub: 'Gata o gato',
                  selected: _especie == 'gato',
                  icon: Icons.cruelty_free_rounded,
                  onTap: () => setState(() => _especie = 'gato'),
                ),
              ),
            ]),
            const _Titulo('Sexo'),
            Row(children: [
              Expanded(
                child: _Toggle(
                  label: 'Hembra',
                  icon: Icons.female_rounded,
                  selected: _sexo == 'hembra',
                  onTap: () => setState(() => _sexo = 'hembra'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Toggle(
                  label: 'Macho',
                  icon: Icons.male_rounded,
                  selected: _sexo == 'macho',
                  onTap: () => setState(() => _sexo = 'macho'),
                ),
              ),
            ]),
            const _Titulo('Edad'),
            Row(children: [
              Expanded(
                child: _Stepper(
                  value: _anios,
                  unidad: _anios == 1 ? 'año' : 'años',
                  onChanged: (v) => setState(() => _anios = v.clamp(0, 30)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stepper(
                  value: _meses,
                  unidad: _meses == 1 ? 'mes' : 'meses',
                  onChanged: (v) => setState(() => _meses = v.clamp(0, 11)),
                ),
              ),
            ]),
            _Titulo('Peso', sub: esPerro ? 'Obligatorio en perros' : null),
            TextFormField(
              controller: _peso,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Peso en kg',
                suffixText: 'kg',
                helperText: esPerro ? 'En perros el peso define el precio.' : 'Opcional en gatos.',
                helperMaxLines: 2,
              ),
              validator: (v) {
                final s = (v ?? '').trim();
                if (s.isEmpty) return esPerro ? 'Indica el peso de tu perro' : null;
                final d = double.tryParse(s.replaceAll(',', '.'));
                if (d == null || d <= 0 || d > 120) return 'Escribe un peso válido, por ejemplo 12,5';
                return null;
              },
            ),
            const _Titulo('¿Es de hocico corto (braquiocefálico: pug, bulldog, persa…)?'),
            Row(children: [
              Expanded(
                child: _Toggle(label: 'Sí', selected: _braqui == true, onTap: () => setState(() => _braqui = true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Toggle(label: 'No', selected: _braqui == false, onTap: () => setState(() => _braqui = false)),
              ),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.help_outline_rounded, size: 20, color: Fz.variante),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Braquiocefálico: cara chata, como pug, bulldog, shih tzu o gato persa. Respiran distinto con la '
                  'anestesia; su precio se acuerda según peso y raza.',
                  style: t.bodySmall,
                ),
              ),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _notas,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas (opcional)', hintText: 'Alergias, carácter, etc.'),
            ),
            const SizedBox(height: 20),
            if (_precios != null && _especie != null && _sexo != null)
              PrecioEstimadoBox(
                precio: precioEsterilizacion(
                  _precios!,
                  Pet({..._datos(), 'id': widget.pet?.id ?? ''}),
                ),
                tasa: _tasa,
                kit: _precios!.extra('kit', _especie!),
              ),
            const SizedBox(height: 20),
            PopButton(
              label: _editando ? 'Guardar cambios' : 'Guardar mascota',
              icon: Icons.check_rounded,
              loading: _guardando,
              onPressed: _borrando || _subiendoFoto ? null : _guardar,
            ),
            if (_editando) ...[
              const SizedBox(height: 14),
              PopButton.danger(
                label: 'Eliminar mascota',
                icon: Icons.delete_outline_rounded,
                loading: _borrando,
                onPressed: _guardando ? null : _borrar,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  const _Titulo(this.text, {this.sub});
  final String text;
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
      child: Column(children: [
        Text(text, textAlign: TextAlign.center, style: t.titleLarge),
        if (sub != null) Text(sub!, textAlign: TextAlign.center, style: t.bodySmall),
      ]),
    );
  }
}

/// Avatar grande y tocable para agregar o cambiar la foto.
class _FotoPicker extends StatelessWidget {
  const _FotoPicker({required this.url, required this.esPerro, required this.cargando, required this.onTap});
  final String? url;
  final bool esPerro;
  final bool cargando;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      label: url == null ? 'Agregar foto' : 'Cambiar foto',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Stack(clipBehavior: Clip.none, children: [
            FzAvatar(
              url: url,
              size: 128,
              icon: esPerro ? Icons.pets_rounded : Icons.cruelty_free_rounded,
              color: Fz.azul100,
            ),
            if (cargando)
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(color: Color(0x88FBFDFF), shape: BoxShape.circle),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
            Positioned(
              right: -2,
              bottom: 2,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Fz.azul,
                  shape: BoxShape.circle,
                  border: Border.all(color: Fz.tinta, width: Fz.borde),
                ),
                child: const Icon(Icons.photo_camera_rounded, color: Fz.tarjeta, size: 22),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text(cargando ? 'Subiendo foto…' : (url == null ? 'Agregar foto' : 'Cambiar foto'),
              style: t.labelLarge?.copyWith(color: Fz.azul)),
        ]),
      ),
    );
  }
}

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.label, required this.sub, required this.selected, required this.icon, required this.onTap});
  final String label;
  final String sub;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Fz.tarjeta : Fz.tinta;
    return Semantics(
      selected: selected,
      button: true,
      child: PopCard(
        onTap: onTap,
        color: selected ? Fz.azul : Fz.tarjeta,
        shadow: selected,
        child: SizedBox(
          height: 88,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(selected ? Icons.check_circle_rounded : icon, size: 28, color: fg),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: fg)),
            Text(sub, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: selected ? Fz.azul50 : Fz.variante)),
          ]),
        ),
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Fz.tarjeta : Fz.tinta;
    return Semantics(
      selected: selected,
      button: true,
      child: PopCard(
        onTap: onTap,
        radius: 999,
        color: selected ? Fz.azul : Fz.tarjeta,
        shadow: selected,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: SizedBox(
          height: 50,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: fg)
            else if (icon != null)
              Icon(icon, size: 20, color: fg),
            const SizedBox(width: 6),
            Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: fg)),
          ]),
        ),
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.unidad, required this.onChanged});
  final int value;
  final String unidad;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Fz.tarjeta,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Fz.tinta, width: 2),
        ),
        child: Row(children: [
          IconButton(
            tooltip: 'Menos $unidad',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.remove_rounded),
            onPressed: value > 0 ? () => onChanged(value - 1) : null,
          ),
          Expanded(
            child: Text('$value $unidad',
                textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          ),
          IconButton(
            tooltip: 'Más $unidad',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.add_rounded),
            onPressed: () => onChanged(value + 1),
          ),
        ]),
      );
}
