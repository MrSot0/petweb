import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Identidad v0.2 de FAUNAZULIA: UN SOLO color principal (azul médico) y sus variaciones.
/// Fondo azul muy claro (no blanco puro). El frambuesa queda solo para errores.
class Fz {
  // --- Escala del azul principal ---
  static const azul900 = Color(0xFF0B2A5B);
  static const azul700 = Color(0xFF124E9F);
  static const azul = Color(0xFF1660C4); // principal
  static const azul400 = Color(0xFF4A86D6);
  static const azul200 = Color(0xFFA9C8F2);
  static const azul100 = Color(0xFFD6E5F8);
  static const azul50 = Color(0xFFEAF2FC);

  static const tinta = Color(0xFF0E1C3A); // texto, contornos y sombras (azul noche)
  static const fondo = Color(0xFFEEF3FA); // fondo de pantallas
  static const tarjeta = Color(0xFFFBFDFF); // tarjetas (casi blanco azulado, no puro)
  static const variante = Color(0xFF3A4766); // texto secundario (AA sobre fondo)
  static const frambuesa = Color(0xFFB01E45); // error / peligro
  static const frambuesaSuave = Color(0xFFFAD4DC);

  // Nombres heredados (v0.1) remapeados a la escala azul para no romper pantallas.
  static const crema = fondo;
  static const cremaClaro = tarjeta;
  static const azulPastel = azul100;
  static const rosa = azul200;
  static const rosaSuave = azul50;

  static const borde = 2.0;
  static const sombra = Offset(3, 3);
  static const radioTarjeta = 22.0;

  static TextStyle display(double size, {FontWeight w = FontWeight.w800, Color color = tinta}) =>
      GoogleFonts.baloo2(fontSize: size, fontWeight: w, color: color, height: 1.15);

  /// Texto de lectura: Atkinson Hyperlegible Next (distingue 0/O y 1/l en montos y dosis).
  static TextStyle body(double size, {FontWeight w = FontWeight.w400, Color color = tinta, double height = 1.4}) =>
      GoogleFonts.getFont('Atkinson Hyperlegible Next', fontSize: size, fontWeight: w, color: color, height: height);

  // Escala reducida (v0.2): títulos más contenidos, texto 15/14/12.
  static TextTheme _text() => TextTheme(
        displayLarge: display(36),
        displayMedium: display(30),
        displaySmall: display(26),
        headlineLarge: display(24),
        headlineMedium: display(21),
        headlineSmall: display(18.5, w: FontWeight.w700),
        titleLarge: display(17, w: FontWeight.w700),
        titleMedium: body(15, w: FontWeight.w700),
        titleSmall: body(13.5, w: FontWeight.w700),
        bodyLarge: body(15, height: 1.45),
        bodyMedium: body(14),
        bodySmall: body(12, color: variante, height: 1.35),
        labelLarge: display(15, w: FontWeight.w700),
        labelMedium: body(12.5, w: FontWeight.w700),
        labelSmall: body(11.5, w: FontWeight.w700),
      );

  static ThemeData theme() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: azul,
      onPrimary: tarjeta,
      primaryContainer: azul100,
      onPrimaryContainer: tinta,
      secondary: azul700,
      onSecondary: tarjeta,
      secondaryContainer: azul200,
      onSecondaryContainer: tinta,
      tertiary: azul900,
      onTertiary: tarjeta,
      error: frambuesa,
      onError: tarjeta,
      errorContainer: frambuesaSuave,
      onErrorContainer: tinta,
      surface: tarjeta,
      onSurface: tinta,
      onSurfaceVariant: variante,
      surfaceContainerLowest: tarjeta,
      surfaceContainerLow: azul50,
      surfaceContainer: Color(0xFFE3ECF8),
      surfaceContainerHigh: azul100,
      surfaceContainerHighest: Color(0xFFC9DBF3),
      outline: tinta,
      outlineVariant: azul200,
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
    // Opciones seleccionadas: azul sólido con texto claro (acento fuerte).
    Color sel(Set<WidgetState> s, Color on, Color off) => s.contains(WidgetState.selected) ? on : off;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: fondo,
      textTheme: text,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: fondo,
        foregroundColor: tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: display(19),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: azul,
          foregroundColor: tarjeta,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 22),
          shape: pill,
          textStyle: display(15.5, w: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: azul50,
          foregroundColor: tinta,
          minimumSize: const Size(64, 50),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          shape: pill,
          side: const BorderSide(color: tinta, width: borde),
          textStyle: display(15, w: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: azul,
          minimumSize: const Size(48, 48),
          textStyle: display(14.5, w: FontWeight.w700),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((s) => sel(s, azul, tarjeta)),
          foregroundColor: WidgetStateProperty.resolveWith((s) => sel(s, tarjeta, tinta)),
          iconColor: WidgetStateProperty.resolveWith((s) => sel(s, tarjeta, tinta)),
          side: const WidgetStatePropertyAll(BorderSide(color: tinta, width: borde)),
          textStyle: WidgetStatePropertyAll(body(13.5, w: FontWeight.w700)),
          minimumSize: const WidgetStatePropertyAll(Size(48, 46)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tarjeta,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: field(tinta),
        enabledBorder: field(azul200),
        focusedBorder: field(azul, 2.5),
        errorBorder: field(frambuesa),
        focusedErrorBorder: field(frambuesa, 2.5),
        labelStyle: text.bodyMedium?.copyWith(color: variante),
        floatingLabelStyle: text.titleSmall?.copyWith(color: azul),
        helperStyle: text.bodySmall,
        prefixIconColor: azul,
        suffixIconColor: azul,
        errorStyle: text.bodySmall?.copyWith(color: frambuesa, fontWeight: FontWeight.w700),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: tarjeta,
        selectedColor: azul,
        secondarySelectedColor: azul,
        side: const BorderSide(color: tinta, width: 1.6),
        shape: const StadiumBorder(),
        labelStyle: text.titleSmall?.copyWith(fontSize: 13),
        secondaryLabelStyle: text.titleSmall?.copyWith(fontSize: 13, color: tarjeta),
        showCheckmark: true,
        checkmarkColor: tarjeta,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: tarjeta,
        indicatorColor: azul,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
            (s) => text.titleSmall?.copyWith(fontSize: 11.5, color: s.contains(WidgetState.selected) ? azul : variante)),
        iconTheme: WidgetStateProperty.resolveWith(
            (s) => IconThemeData(color: s.contains(WidgetState.selected) ? tarjeta : variante, size: 24)),
      ),
      checkboxTheme: CheckboxThemeData(
        side: const BorderSide(color: tinta, width: 2),
        fillColor: WidgetStateProperty.resolveWith((s) => sel(s, azul, tarjeta)),
        checkColor: const WidgetStatePropertyAll(tarjeta),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStateProperty.resolveWith((s) => sel(s, azul, variante))),
      switchTheme: SwitchThemeData(
        trackOutlineColor: const WidgetStatePropertyAll(tinta),
        thumbColor: WidgetStateProperty.resolveWith((s) => sel(s, tarjeta, tinta)),
        trackColor: WidgetStateProperty.resolveWith((s) => sel(s, azul, tarjeta)),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: tarjeta,
        unselectedLabelColor: tinta,
        labelStyle: text.titleSmall,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(color: azul, borderRadius: BorderRadius.circular(999)),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: azul,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: azul,
        foregroundColor: tarjeta,
        shape: pill,
        extendedTextStyle: display(15, w: FontWeight.w700),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tinta,
        contentTextStyle: text.bodyMedium?.copyWith(color: tarjeta),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tarjeta,
        titleTextStyle: display(19),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: const BorderSide(color: tinta, width: borde)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(backgroundColor: tarjeta, showDragHandle: true),
      dividerTheme: const DividerThemeData(color: azul100, thickness: 1.5),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: azul, linearTrackColor: azul100),
    );
  }
}
