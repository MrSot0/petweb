import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'theme.dart';

/// Tarjeta "pop": contorno de tinta + sombra dura sin desenfoque (lenguaje Holy Mochi).
class PopCard extends StatelessWidget {
  const PopCard({
    super.key,
    required this.child,
    this.color = Fz.cremaClaro,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.radius = Fz.radioTarjeta,
    this.shadow = true,
  });

  final Widget child;
  final Color color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final double radius;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final br = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: br,
        border: Border.all(color: Fz.tinta, width: Fz.borde),
        boxShadow: shadow ? const [BoxShadow(color: Fz.tinta, offset: Fz.sombra)] : null,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// Botón píldora de un solo color con sombra dura que "se aplasta" al presionar.
class PopButton extends StatefulWidget {
  const PopButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.color = Fz.azul,
    this.foreground = Fz.cremaClaro,
    this.expand = true,
    this.loading = false,
  });

  /// Variante tonal (azul pastel, texto tinta).
  const PopButton.tonal({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
  })  : color = Fz.azulPastel,
        foreground = Fz.tinta;

  /// Variante de acento (rosa pastel, texto tinta).
  const PopButton.accent({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
  })  : color = Fz.rosa,
        foreground = Fz.tinta;

  /// Variante de peligro (frambuesa, texto crema).
  const PopButton.danger({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.loading = false,
  })  : color = Fz.frambuesa,
        foreground = Fz.cremaClaro;

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final Color foreground;
  final bool expand;
  final bool loading;

  @override
  State<PopButton> createState() => _PopButtonState();
}

class _PopButtonState extends State<PopButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final offset = _down ? const Offset(2, 2) : Offset.zero;
    final content = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: widget.foreground),
          )
        else if (widget.icon != null)
          Icon(widget.icon, color: widget.foreground, size: 22),
        if (widget.loading || widget.icon != null) const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: Fz.display(17, w: FontWeight.w700, color: widget.foreground),
          ),
        ),
      ],
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTap: enabled ? widget.onPressed : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(offset.dx, offset.dy, 0),
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
          decoration: BoxDecoration(
            color: enabled ? widget.color : widget.color.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Fz.tinta, width: Fz.borde),
            boxShadow: enabled && !_down ? const [BoxShadow(color: Fz.tinta, offset: Fz.sombra)] : null,
          ),
          child: content,
        ),
      ),
    );
  }
}

/// Etiqueta de estado: forma + icono + texto (nunca solo color).
class StatusPill extends StatelessWidget {
  const StatusPill(this.text, {super.key, this.icon, this.color = Fz.azulPastel, this.dashed = false});

  final String text;
  final IconData? icon;
  final Color color;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Fz.tinta, width: dashed ? 1.5 : 2),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 16, color: Fz.tinta), const SizedBox(width: 4)],
        Text(text, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 12.5)),
      ]),
    );
  }
}

/// Logo pata-corazón (assets/logo.svg).
class FzLogo extends StatelessWidget {
  const FzLogo({super.key, this.size = 56});
  final double size;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(size * .28),
        child: SvgPicture.asset('assets/logo.svg', width: size, height: size, semanticsLabel: 'FAUNAZULIA'),
      );
}

/// Estado vacío / error con mensaje claro y acción.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: Fz.rosa,
              shape: BoxShape.circle,
              border: Border.all(color: Fz.tinta, width: Fz.borde),
            ),
            child: Icon(icon, size: 42, color: Fz.tinta),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: t.headlineSmall),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Fz.variante)),
          ],
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

/// Muestra un error de forma amable.
void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(error))));
}

void showInfo(BuildContext context, String msg) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Convierte errores de Supabase/red en mensajes entendibles.
String friendlyError(Object e) {
  final s = e.toString();
  final m = RegExp(r'message: ([^,]+)').firstMatch(s);
  final msg = m?.group(1) ?? s;
  if (s.contains('SocketException') || s.contains('Failed host lookup')) {
    return 'Sin conexión. Revisa tu internet e inténtalo de nuevo.';
  }
  if (s.contains('Invalid login credentials')) return 'Correo o contraseña incorrectos.';
  if (s.contains('Email not confirmed')) return 'Confirma tu correo: te enviamos un enlace.';
  if (s.contains('User already registered')) return 'Ya existe una cuenta con ese correo.';
  return msg.replaceAll(RegExp(r'^(Exception|PostgrestException)\W*'), '');
}

/// Encabezado de sección.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 10),
        child: Row(children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.headlineSmall)),
          if (trailing != null) trailing!,
        ]),
      );
}

// ======================= v0.2: dinamismo visual =======================

/// Aparición suave (sube y se desvanece) con retraso escalonado por índice.
/// Respeta "reducir animaciones" del sistema.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.index = 0, this.dy = 18});
  final Widget child;
  final int index;
  final double dy;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final delay = (index.clamp(0, 10)) * 55;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Interval(delay / (380 + delay), 1, curve: Curves.easeOutCubic),
      builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * dy), child: c)),
      child: child,
    );
  }
}

/// Patrón decorativo de huellas (círculos) en tonos del azul principal.
class PawPatternPainter extends CustomPainter {
  PawPatternPainter({this.color = const Color(0x22FBFDFF)});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    const step = 64.0;
    var row = 0;
    for (var y = 12.0; y < size.height + step; y += step, row++) {
      for (var x = (row.isEven ? 10.0 : 42.0); x < size.width + step; x += step) {
        final c = Offset(x, y);
        canvas.drawOval(Rect.fromCenter(center: c + const Offset(0, 7), width: 16, height: 13), p);
        for (final d in const [Offset(-9, -4), Offset(-3, -10), Offset(4, -10), Offset(10, -4)]) {
          canvas.drawCircle(c + d, 3.6, p);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant PawPatternPainter old) => old.color != color;
}

/// Cabecera azul con patrón de huellas, título centrado y contenido opcional.
/// Úsala como primer elemento de listas para dar ritmo y evitar pantallas planas.
class FzHero extends StatelessWidget {
  const FzHero({super.key, required this.title, this.subtitle, this.leading, this.child, this.color = Fz.azul});
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(Fz.radioTarjeta + 4),
        border: Border.all(color: Fz.tinta, width: Fz.borde),
        boxShadow: const [BoxShadow(color: Fz.tinta, offset: Fz.sombra)],
      ),
      child: CustomPaint(
        painter: PawPatternPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (leading != null) ...[leading!, const SizedBox(height: 10)],
            Text(title, textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(color: Fz.tarjeta)),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!, textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: Fz.azul50)),
            ],
            if (child != null) ...[const SizedBox(height: 14), child!],
          ]),
        ),
      ),
    );
  }
}

/// Avatar circular con foto (URL pública) o iniciales/icono como respaldo.
class FzAvatar extends StatelessWidget {
  const FzAvatar({super.key, this.url, this.text, this.icon = Icons.person_rounded, this.size = 48, this.color = Fz.azul100});
  final String? url;
  final String? text;
  final IconData icon;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: text != null && text!.isNotEmpty
          ? Text(text!, style: Fz.display(size * .38, color: Fz.tinta))
          : Icon(icon, size: size * .5, color: Fz.tinta),
    );
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Fz.tinta, width: Fz.borde)),
      child: url == null
          ? fallback
          : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => fallback),
    );
  }
}

/// Iniciales a partir de un nombre ("Jesús Soto" -> "JS").
String iniciales(String? nombre) {
  final p = (nombre ?? '').trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
  if (p.isEmpty) return '';
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}
