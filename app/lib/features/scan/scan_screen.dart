import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/data.dart';
import '../../core/theme.dart';
import '../../core/widgets.dart';
import 'ficha_screen.dart';

/// Normaliza lo leído o escrito a FZ-AAMM-NNNN. Devuelve null si no tiene esa forma.
String? normalizarCodigo(String raw) {
  final s = raw.trim().toUpperCase();
  final m = RegExp(r'FZ\W*(\d{4})\W*(\d{4})').firstMatch(s);
  if (m == null) return null;
  return 'FZ-${m.group(1)}-${m.group(2)}';
}

/// Pestaña "Escanear": lee el QR de la inscripción (o el código escrito) y abre la ficha.
/// Vive dentro de un IndexedStack: la cámara solo se enciende al pulsar "Abrir cámara"
/// y se apaga al cambiar de pestaña, al cerrar con X o mientras la ficha está abierta.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _codigo = TextEditingController();
  MobileScannerController? _ctrl;
  bool _buscando = false;
  bool _enFicha = false;
  String? _error;
  String? _ultimo;
  DateTime _ultimoAt = DateTime(2000);
  Map<String, dynamic>? _stats;
  Object? _statsError;

  @override
  void initState() {
    super.initState();
    _cargarStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // En el IndexedStack la pestaña oculta queda con TickerMode desactivado: apagamos la cámara.
    if (!TickerMode.valuesOf(context).enabled && _ctrl != null && !_enFicha) _cerrarCamara();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    _codigo.dispose();
    super.dispose();
  }

  Future<void> _cargarStats() async {
    try {
      final s = await Data.estadisticas();
      if (!mounted) return;
      setState(() {
        _stats = s;
        _statsError = null;
      });
    } catch (e) {
      if (mounted) setState(() => _statsError = e);
    }
  }

  void _abrirCamara() {
    if (_ctrl != null) return;
    setState(() {
      _error = null;
      _ctrl = MobileScannerController(
        formats: const [BarcodeFormat.qrCode],
        detectionSpeed: DetectionSpeed.normal,
      );
    });
  }

  void _cerrarCamara() {
    final c = _ctrl;
    if (c == null) return;
    setState(() => _ctrl = null);
    c.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_buscando || _enFicha) return;
    for (final b in cap.barcodes) {
      final raw = b.rawValue;
      if (raw == null) continue;
      final c = normalizarCodigo(raw);
      if (c == null) {
        _mostrarError('Ese QR no es de FAUNAZULIA.', raw);
        return;
      }
      // Evita leer el mismo código varias veces seguidas.
      if (c == _ultimo && DateTime.now().difference(_ultimoAt).inSeconds < 4) return;
      _buscar(c);
      return;
    }
  }

  void _mostrarError(String msg, String clave) {
    if (clave == _ultimo && DateTime.now().difference(_ultimoAt).inSeconds < 4) return;
    _ultimo = clave;
    _ultimoAt = DateTime.now();
    setState(() => _error = msg);
  }

  Future<void> _buscar(String codigo) async {
    setState(() {
      _buscando = true;
      _error = null;
    });
    _ultimo = codigo;
    _ultimoAt = DateTime.now();
    try {
      final ficha = await Data.buscarCodigo(codigo);
      if (!mounted) return;
      _enFicha = true;
      final c = _ctrl;
      await c?.stop(); // pausa la lectura mientras la ficha está abierta
      if (!mounted) return;
      setState(() => _buscando = false);
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => FichaScreen(ficha: ficha)));
      if (!mounted) return;
      _enFicha = false;
      _codigo.clear();
      _ultimoAt = DateTime.now();
      _cargarStats();
      if (_ctrl != null && _ctrl == c) {
        if (TickerMode.valuesOf(context).enabled) {
          try {
            await c!.start();
          } catch (_) {}
        } else {
          _cerrarCamara();
        }
      }
    } catch (e) {
      if (!mounted) return;
      final s = e.toString();
      setState(() {
        _buscando = false;
        _error = s.contains('No encontramos')
            ? 'No encontramos ese código ($codigo). Revisa que esté bien escrito.'
            : friendlyError(e);
      });
    }
  }

  void _buscarEscrito() {
    FocusScope.of(context).unfocus();
    final c = normalizarCodigo(_codigo.text);
    if (c == null) {
      setState(() => _error = 'El código tiene la forma FZ-AAMM-NNNN, por ejemplo FZ-2611-0042.');
      return;
    }
    _codigo.text = c;
    _buscar(c);
  }

  Future<void> _pegar() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    final txt = d?.text?.trim();
    if (txt == null || txt.isEmpty) {
      if (mounted) showInfo(context, 'No hay texto copiado.');
      return;
    }
    _codigo.text = normalizarCodigo(txt) ?? txt.toUpperCase();
    _codigo.selection = TextSelection.collapsed(offset: _codigo.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarStats,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const FadeSlideIn(
                child: FzHero(
                  title: 'Escanear código',
                  subtitle: 'Lee el QR de la inscripción para ver la ficha de la mascota.',
                  leading: Icon(Icons.qr_code_scanner_rounded, size: 40, color: Fz.tarjeta),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(index: 1, child: _ctrl == null ? _abrir(context) : _visor(context)),
              if (_buscando) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                PopCard(
                  color: Fz.frambuesaSuave,
                  padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                  child: Row(children: [
                    const Icon(Icons.error_rounded, color: Fz.frambuesa),
                    const SizedBox(width: 10),
                    Expanded(child: Text(_error!, style: t.bodyMedium)),
                    IconButton(
                      tooltip: 'Cerrar aviso',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(() => _error = null),
                    ),
                  ]),
                ),
              ],
              const SizedBox(height: 16),
              FadeSlideIn(index: 2, child: _escribir(context)),
              const SizedBox(height: 8),
              FadeSlideIn(index: 3, child: _resumen(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _abrir(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      color: Fz.azul100,
      onTap: _abrirCamara,
      child: Column(children: [
        const SizedBox(height: 8),
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Fz.azul,
            shape: BoxShape.circle,
            border: Border.all(color: Fz.tinta, width: Fz.borde),
          ),
          child: const Icon(Icons.photo_camera_rounded, size: 40, color: Fz.tarjeta),
        ),
        const SizedBox(height: 12),
        Text('Apunta la cámara al QR', textAlign: TextAlign.center, style: t.titleLarge),
        const SizedBox(height: 4),
        Text('La cámara solo se enciende mientras escaneas.', textAlign: TextAlign.center, style: t.bodySmall),
        const SizedBox(height: 14),
        PopButton(label: 'Abrir cámara', icon: Icons.qr_code_scanner_rounded, onPressed: _abrirCamara),
      ]),
    );
  }

  Widget _visor(BuildContext context) {
    final ctrl = _ctrl!;
    return Container(
      height: 340,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Fz.tinta,
        borderRadius: BorderRadius.circular(Fz.radioTarjeta),
        border: Border.all(color: Fz.tinta, width: Fz.borde),
        boxShadow: const [BoxShadow(color: Fz.tinta, offset: Fz.sombra)],
      ),
      child: Stack(fit: StackFit.expand, children: [
        MobileScanner(
          controller: ctrl,
          onDetect: _onDetect,
          errorBuilder: (context, error) => _errorCamara(context, error),
          placeholderBuilder: (_) => const Center(child: CircularProgressIndicator(color: Fz.tarjeta)),
        ),
        IgnorePointer(
          child: Center(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Fz.tarjeta, width: 4),
                boxShadow: const [BoxShadow(color: Color(0x660E1C3A), spreadRadius: 400)],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 14,
          child: Text(
            _enFicha || _buscando ? 'Buscando…' : 'Encuadra el QR dentro del marco',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Fz.tarjeta),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _BotonVisor(icon: Icons.close_rounded, tooltip: 'Cerrar cámara', onPressed: _cerrarCamara),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: ValueListenableBuilder<MobileScannerState>(
            valueListenable: ctrl,
            builder: (_, s, _) {
              if (s.torchState == TorchState.unavailable) return const SizedBox.shrink();
              final on = s.torchState == TorchState.on;
              return _BotonVisor(
                icon: on ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                tooltip: on ? 'Apagar linterna' : 'Encender linterna',
                selected: on,
                onPressed: () => ctrl.toggleTorch(),
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _errorCamara(BuildContext context, MobileScannerException error) {
    final t = Theme.of(context).textTheme;
    final permiso = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Fz.azul900,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(permiso ? Icons.no_photography_rounded : Icons.videocam_off_rounded, size: 44, color: Fz.tarjeta),
            const SizedBox(height: 10),
            Text(
              permiso ? 'Sin permiso para usar la cámara' : 'No pudimos abrir la cámara',
              textAlign: TextAlign.center,
              style: t.titleLarge?.copyWith(color: Fz.tarjeta),
            ),
            const SizedBox(height: 6),
            Text(
              permiso
                  ? 'Permite el acceso a la cámara en los ajustes del teléfono (Aplicaciones > FAUNAZULIA > Permisos) '
                      'o escribe el código abajo.'
                  : 'Cierra otras apps que usen la cámara e inténtalo de nuevo, o escribe el código abajo.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: Fz.azul50),
            ),
            const SizedBox(height: 14),
            PopButton.tonal(
              label: 'Reintentar',
              icon: Icons.refresh_rounded,
              expand: false,
              onPressed: () {
                _cerrarCamara();
                _abrirCamara();
              },
            ),
          ]),
        ),
      ),
    );
  }

  Widget _escribir(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return PopCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Escribir código', textAlign: TextAlign.center, style: t.titleLarge),
        const SizedBox(height: 4),
        Text('Si el QR no se lee, escribe el código de la inscripción.',
            textAlign: TextAlign.center, style: t.bodySmall),
        const SizedBox(height: 12),
        TextField(
          controller: _codigo,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.search,
          autocorrect: false,
          enableSuggestions: false,
          maxLength: 14,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9\- ]')),
            TextInputFormatter.withFunction(
                (_, v) => v.copyWith(text: v.text.toUpperCase(), selection: v.selection)),
          ],
          onSubmitted: (_) => _buscarEscrito(),
          style: t.titleMedium?.copyWith(letterSpacing: 1.2),
          decoration: InputDecoration(
            labelText: 'Código',
            hintText: 'FZ-AAMM-NNNN',
            counterText: '',
            prefixIcon: const Icon(Icons.qr_code_2_rounded),
            suffixIcon: TextButton.icon(
              onPressed: _pegar,
              icon: const Icon(Icons.content_paste_rounded, size: 18),
              label: const Text('Pegar'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        PopButton.tonal(
          label: 'Buscar ficha',
          icon: Icons.search_rounded,
          loading: _buscando,
          onPressed: _buscarEscrito,
        ),
      ]),
    );
  }

  Widget _resumen(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (_statsError != null && _stats == null) {
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(children: [
          Text('No pudimos cargar el resumen.', textAlign: TextAlign.center, style: t.bodySmall),
          TextButton(onPressed: _cargarStats, child: const Text('Reintentar')),
        ]),
      );
    }
    final s = _stats;
    String n(Object? v) => s == null ? '…' : '${(v as num?)?.toInt() ?? 0}';
    final esp = s == null ? const <String, dynamic>{} : fichaMapa(s['por_especie']);
    final chips = [
      (Icons.pets_rounded, 'Mascotas', n(s?['total'])),
      (Icons.check_circle_rounded, 'Atendidas', n(s?['atendidas'])),
      (Icons.how_to_reg_rounded, 'Presentes', n(s?['presentes'])),
      (Icons.pets_rounded, 'Perros', n(esp['perro'])),
      (Icons.cruelty_free_rounded, 'Gatos', n(esp['gato'])),
    ];
    return Column(children: [
      const SectionTitle('Resumen total'),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, c) in chips.indexed)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: i.isEven ? Fz.azul100 : Fz.tarjeta,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Fz.tinta, width: 1.6),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(c.$1, size: 18, color: Fz.azul),
                const SizedBox(width: 6),
                Text(c.$3, style: t.titleMedium),
                const SizedBox(width: 4),
                Text(c.$2, style: t.bodySmall),
              ]),
            ),
        ],
      ),
    ]);
  }
}

class _BotonVisor extends StatelessWidget {
  const _BotonVisor({required this.icon, required this.tooltip, required this.onPressed, this.selected = false});
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? Fz.azul : Fz.tarjeta,
        shape: const CircleBorder(side: BorderSide(color: Fz.tinta, width: Fz.borde)),
        child: IconButton(
          tooltip: tooltip,
          iconSize: 26,
          constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
          icon: Icon(icon, color: selected ? Fz.tarjeta : Fz.tinta),
          onPressed: onPressed,
        ),
      );
}
