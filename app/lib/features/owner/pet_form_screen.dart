import 'package:flutter/material.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
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
      };

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
            'No se puede eliminar: tiene inscripciones o citas registradas. Si ya no irá, cancela su inscripción desde Perfil.');
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
            TextFormField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre'),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Escribe su nombre' : null,
            ),
            const SectionTitle('Especie'),
            Row(children: [
              Expanded(
                child: _BigChoice(
                  label: 'Perro',
                  sub: 'Perra o perro',
                  selected: _especie == 'perro',
                  color: Fz.azulPastel,
                  onTap: () => setState(() => _especie = 'perro'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BigChoice(
                  label: 'Gato',
                  sub: 'Gata o gato',
                  selected: _especie == 'gato',
                  color: Fz.rosa,
                  onTap: () => setState(() => _especie = 'gato'),
                ),
              ),
            ]),
            const SectionTitle('Sexo'),
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
            const SectionTitle('Edad'),
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
            SectionTitle('Peso', trailing: esPerro ? Text('Obligatorio en perros', style: t.bodySmall) : null),
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
            const SectionTitle('¿Es de hocico corto (braquiocefálico: pug, bulldog, persa…)?'),
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
              onPressed: _borrando ? null : _guardar,
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

class _BigChoice extends StatelessWidget {
  const _BigChoice({required this.label, required this.sub, required this.selected, required this.color, required this.onTap});
  final String label;
  final String sub;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: PopCard(
          onTap: onTap,
          color: selected ? color : Fz.cremaClaro,
          shadow: selected,
          child: SizedBox(
            height: 96,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(selected ? Icons.check_circle_rounded : Icons.pets_rounded, size: 32),
              const SizedBox(height: 4),
              Text(label, style: Fz.display(20)),
              Text(sub, style: Theme.of(context).textTheme.bodySmall),
            ]),
          ),
        ),
      );
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.label, required this.selected, required this.onTap, this.icon});
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        selected: selected,
        button: true,
        child: PopCard(
          onTap: onTap,
          radius: 999,
          color: selected ? Fz.rosa : Fz.cremaClaro,
          shadow: selected,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: SizedBox(
            height: 52,
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (selected)
                const Icon(Icons.check_rounded, size: 20)
              else if (icon != null)
                Icon(icon, size: 20),
              const SizedBox(width: 6),
              Text(label, style: Theme.of(context).textTheme.titleMedium),
            ]),
          ),
        ),
      );
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.unidad, required this.onChanged});
  final int value;
  final String unidad;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Fz.cremaClaro,
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
