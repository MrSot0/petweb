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
