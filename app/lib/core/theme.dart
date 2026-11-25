import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad v3 de FAUNAZULIA (ver design/brand.md).
/// Azul médico + tinta + rosa y azul pastel sobre crema. Sin naranja, sin blanco puro.
class Fz {
  static const azul = Color(0xFF1660C4); // Azul Lago: primario
  static const tinta = Color(0xFF0E1C3A); // Texto, contornos, sombras duras
  static const rosa = Color(0xFFF6B8CB); // Acento pastel
  static const azulPastel = Color(0xFFC7DBF5); // Contenedores, chips
  static const crema = Color(0xFFFAF3E6); // Fondo
  static const cremaClaro = Color(0xFFFFFAF2); // Tarjetas
  static const rosaSuave = Color(0xFFFBD9E3); // Contenedor secundario
  static const frambuesa = Color(0xFFB01E45); // Error / peligro
  static const frambuesaSuave = Color(0xFFFAD4DC);
  static const variante = Color(0xFF3A4766); // Texto secundario (AA sobre crema)

  static const borde = 2.5;
  static const sombra = Offset(4, 4);
  static const radioTarjeta = 24.0;

  static TextStyle display(double size, {FontWeight w = FontWeight.w800, Color color = tinta}) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: w, color: color, height: 1.15);

  /// Texto de lectura: Atkinson Hyperlegible Next (distingue 0/O y 1/l en montos y dosis).
  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color color = tinta, double height = 1.4}) =>
      GoogleFonts.getFont('Atkinson Hyperlegible Next', fontSize: size, fontWeight: w, color: color, height: height);

  static TextTheme _text() => TextTheme(
        displayLarge: display(48),
        displayMedium: display(40),
        displaySmall: display(32),
        headlineLarge: display(28),
        headlineMedium: display(24),
        headlineSmall: display(22, w: FontWeight.w700),
        titleLarge: display(20, w: FontWeight.w700),
        titleMedium: body(16, w: FontWeight.w700),
        titleSmall: body(14, w: FontWeight.w700),
        bodyLarge: body(16, height: 1.45),
        bodyMedium: body(14),
        bodySmall: body(12.5, color: variante, height: 1.35),
        labelLarge: display(16, w: FontWeight.w700),
        labelMedium: body(13, w: FontWeight.w700),
        labelSmall: body(12, w: FontWeight.w700),
      );

  static ThemeData theme() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: azul,
      onPrimary: cremaClaro,
      primaryContainer: azulPastel,
      onPrimaryContainer: tinta,
      secondary: Color(0xFF9C2F5C),
      onSecondary: cremaClaro,
      secondaryContainer: rosa,
      onSecondaryContainer: tinta,
      tertiary: tinta,
      onTertiary: cremaClaro,
      error: frambuesa,
      onError: cremaClaro,
      errorContainer: frambuesaSuave,
      onErrorContainer: tinta,
      surface: cremaClaro,
      onSurface: tinta,
      onSurfaceVariant: variante,
      surfaceContainerLowest: cremaClaro,
      surfaceContainerLow: Color(0xFFF7EEDD),
      surfaceContainer: Color(0xFFF4EBDB),
      surfaceContainerHigh: Color(0xFFEDE2CF),
      surfaceContainerHighest: Color(0xFFE6D9C2),
      outline: tinta,
      outlineVariant: Color(0xFFCFC3AE),
    );
    final text = _text();
    final pill = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(999),
      side: const BorderSide(color: tinta, width: borde),
    );
    OutlineInputBorder field(Color c, [double w = borde]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: crema,
      textTheme: text,
      appBarTheme: AppBarTheme(
        backgroundColor: crema,
        foregroundColor: tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: display(22),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: azul,
          foregroundColor: cremaClaro,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          shape: pill,
          textStyle: display(17, w: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: azulPastel,
          foregroundColor: tinta,
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: pill,
          side: const BorderSide(color: tinta, width: borde),
          textStyle: display(16, w: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: azul,
          minimumSize: const Size(48, 48),
          textStyle: display(15, w: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: cremaClaro,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: field(tinta),
        enabledBorder: field(tinta),
        focusedBorder: field(azul, 3),
        errorBorder: field(frambuesa),
        focusedErrorBorder: field(frambuesa, 3),
        labelStyle: text.bodyMedium,
        floatingLabelStyle: text.titleSmall?.copyWith(color: azul),
        helperStyle: text.bodySmall,
        errorStyle: text.bodySmall?.copyWith(color: frambuesa, fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: cremaClaro,
        selectedColor: rosa,
        side: const BorderSide(color: tinta, width: 2),
        shape: const StadiumBorder(),
        labelStyle: text.titleSmall,
        showCheckmark: true,
        checkmarkColor: tinta,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: cremaClaro,
        indicatorColor: rosa,
        height: 72,
        labelTextStyle: WidgetStatePropertyAll(text.titleSmall?.copyWith(fontSize: 12)),
        iconTheme: const WidgetStatePropertyAll(IconThemeData(color: tinta)),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: tinta, width: 2),
        fillColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? azul : cremaClaro),
        checkColor: const WidgetStatePropertyAll(cremaClaro),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(tinta),
        thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? cremaClaro : tinta),
        trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? azul : cremaClaro),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tinta,
        contentTextStyle: text.bodyMedium?.copyWith(color: cremaClaro),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFFCFC3AE), thickness: 1.5),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: azul, linearTrackColor: azulPastel),
    );
  }
}
