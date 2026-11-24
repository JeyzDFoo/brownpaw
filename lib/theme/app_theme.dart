import 'package:flutter/material.dart';

import 'flow_status_style.dart';

/// The brownpaw look: "Riverstone".
///
/// Chocolate-brown ink on silt-green paper, cards as filled white pebbles
/// with uneven rounded corners, a burnt-orange paw for the brand and the
/// primary action, and glacier blue for water and runs that are in.
@immutable
class Riverstone {
  /// The page background: glacial silt.
  final Color paper;

  /// Card and sheet fill: the pebbles.
  final Color card;

  /// Text and lines.
  final Color ink;

  /// Secondary text.
  final Color muted;

  /// Tracks, dividers, unselected segment backgrounds.
  final Color faint;

  /// Burnt orange: the brand, the Log button, selected tabs.
  final Color accent;
  final Color accentSoft;

  /// Glacier blue: water, charts, and "good".
  final Color glacier;
  final Color glacierSoft;

  /// Ochre for too low, red clay for too high.
  final Color low;
  final Color high;

  /// Map land and river lines.
  final Color map;
  final Color water;

  const Riverstone({
    required this.paper,
    required this.card,
    required this.ink,
    required this.muted,
    required this.faint,
    required this.accent,
    required this.accentSoft,
    required this.glacier,
    required this.glacierSoft,
    required this.low,
    required this.high,
    required this.map,
    required this.water,
  });

  static const light = Riverstone(
    paper: Color(0xFFECEFEA),
    card: Color(0xFFFFFFFF),
    ink: Color(0xFF3A2B22),
    muted: Color(0xFF7A6A5E),
    faint: Color(0xFFDCE1DA),
    accent: Color(0xFFA65A24),
    accentSoft: Color(0xFFF4E3D5),
    glacier: Color(0xFF2C7C82),
    glacierSoft: Color(0xFFD6ECEC),
    low: Color(0xFF9A6A10),
    high: Color(0xFFB23A28),
    map: Color(0xFFE3E8E0),
    water: Color(0xFF9CC9C9),
  );

  static const dark = Riverstone(
    paper: Color(0xFF1B1916),
    card: Color(0xFF272320),
    ink: Color(0xFFF1E8DE),
    muted: Color(0xFFB5A698),
    faint: Color(0xFF36302B),
    accent: Color(0xFFE0935A),
    accentSoft: Color(0xFF45301F),
    glacier: Color(0xFF6FC1C5),
    glacierSoft: Color(0xFF1F3B3D),
    low: Color(0xFFE3B04F),
    high: Color(0xFFF08A78),
    map: Color(0xFF22201C),
    water: Color(0xFF2F5658),
  );

  static Riverstone of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Pebble shapes: rounded corners that differ a little from each other, so
/// cards look like river stones rather than stamped rectangles.
class Pebble {
  Pebble._();

  static const BorderRadius a = BorderRadius.only(
    topLeft: Radius.elliptical(28, 22),
    topRight: Radius.elliptical(22, 30),
    bottomRight: Radius.elliptical(30, 20),
    bottomLeft: Radius.elliptical(20, 28),
  );
  static const BorderRadius b = BorderRadius.only(
    topLeft: Radius.elliptical(22, 30),
    topRight: Radius.elliptical(30, 20),
    bottomRight: Radius.elliptical(20, 28),
    bottomLeft: Radius.elliptical(28, 22),
  );

  /// Smaller pebbles for buttons, inputs and tiles.
  static const BorderRadius small = BorderRadius.only(
    topLeft: Radius.elliptical(18, 14),
    topRight: Radius.elliptical(14, 20),
    bottomRight: Radius.elliptical(20, 13),
    bottomLeft: Radius.elliptical(13, 18),
  );

  /// For text fields, whose outline must use circular corners.
  static const BorderRadius input = BorderRadius.only(
    topLeft: Radius.circular(18),
    topRight: Radius.circular(14),
    bottomRight: Radius.circular(20),
    bottomLeft: Radius.circular(13),
  );

  /// Fully rounded, for pills and segmented controls.
  static const BorderRadius pill = BorderRadius.all(Radius.circular(999));

  /// Corner set for a list item, from anything stable about it (an index
  /// or an id), so neighbours differ.
  static BorderRadius alternating(Object? seed) =>
      ((seed?.hashCode ?? 0) & 1) == 1 ? b : a;

  static RoundedRectangleBorder shape([BorderRadius radius = a]) =>
      RoundedRectangleBorder(borderRadius: radius);

  /// A filled pebble for containers that aren't [Card]s.
  static BoxDecoration decoration(
    BuildContext context, {
    BorderRadius radius = a,
    Color? fill,
  }) => BoxDecoration(
    color: fill ?? Riverstone.of(context).card,
    borderRadius: radius,
  );
}

class AppTheme {
  AppTheme._();

  static const String font = 'Nunito';

  static ThemeData get lightTheme => _build(Riverstone.light, Brightness.light);
  static ThemeData get darkTheme => _build(Riverstone.dark, Brightness.dark);

  static TextTheme _text(Riverstone p) {
    TextStyle t(
      double size,
      FontWeight w, {
      double ls = 0,
      double? height,
      Color? color,
    }) => TextStyle(
      fontFamily: font,
      fontSize: size,
      fontWeight: w,
      letterSpacing: ls,
      height: height,
      color: color ?? p.ink,
    );
    return TextTheme(
      displayLarge: t(57, FontWeight.w900, ls: -0.8, height: 1.1),
      displayMedium: t(45, FontWeight.w900, ls: -0.6, height: 1.1),
      displaySmall: t(36, FontWeight.w900, ls: -0.4, height: 1.1),
      headlineLarge: t(32, FontWeight.w900, ls: -0.3, height: 1.15),
      headlineMedium: t(28, FontWeight.w900, ls: -0.2, height: 1.15),
      headlineSmall: t(25, FontWeight.w900, ls: -0.2, height: 1.2),
      titleLarge: t(21, FontWeight.w800),
      titleMedium: t(16.5, FontWeight.w800),
      titleSmall: t(14.5, FontWeight.w800),
      bodyLarge: t(16, FontWeight.w600),
      bodyMedium: t(14.5, FontWeight.w600),
      bodySmall: t(13, FontWeight.w600, color: p.muted),
      labelLarge: t(14.5, FontWeight.w800),
      labelMedium: t(12.5, FontWeight.w800),
      labelSmall: t(12, FontWeight.w800, ls: 0.3, color: p.muted),
    );
  }

  static ThemeData _build(Riverstone p, Brightness brightness) {
    final text = _text(p);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: p.accent,
      onPrimary: p.card,
      primaryContainer: p.accentSoft,
      onPrimaryContainer: p.ink,
      secondary: p.glacier,
      onSecondary: p.card,
      secondaryContainer: p.glacierSoft,
      onSecondaryContainer: p.ink,
      tertiary: p.muted,
      onTertiary: p.card,
      tertiaryContainer: p.faint,
      onTertiaryContainer: p.ink,
      error: p.high,
      onError: p.card,
      errorContainer: p.accentSoft,
      onErrorContainer: p.high,
      surface: p.paper,
      onSurface: p.ink,
      onSurfaceVariant: p.muted,
      surfaceDim: p.paper,
      surfaceBright: p.card,
      surfaceContainerLowest: p.card,
      surfaceContainerLow: p.card,
      surfaceContainer: p.card,
      surfaceContainerHigh: p.card,
      surfaceContainerHighest: p.faint,
      outline: p.muted,
      outlineVariant: p.faint,
      inverseSurface: p.ink,
      onInverseSurface: p.paper,
      inversePrimary: p.accentSoft,
      shadow: Colors.transparent,
      scrim: Colors.black54,
      surfaceTint: Colors.transparent,
    );

    final buttonText = text.labelLarge!.copyWith(fontSize: 15.5);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 22, vertical: 12);
    const buttonSize = Size(64, 48);
    final none = WidgetStatePropertyAll<double>(0);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: font,
      textTheme: text,
      scaffoldBackgroundColor: p.paper,
      canvasColor: p.paper,
      dividerColor: p.faint,
      extensions: [
        brightness == Brightness.dark
            ? FlowStatusColors.dark
            : FlowStatusColors.light,
      ],

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: p.paper,
        foregroundColor: p.ink,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.headlineSmall,
        iconTheme: IconThemeData(color: p.ink),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        shape: Pebble.shape(),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        clipBehavior: Clip.antiAlias,
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: p.accent,
          foregroundColor: p.card,
          padding: buttonPadding,
          minimumSize: buttonSize,
          shape: Pebble.shape(Pebble.small),
          textStyle: buttonText,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.accent,
          foregroundColor: p.card,
          padding: buttonPadding,
          minimumSize: buttonSize,
          shape: Pebble.shape(Pebble.small),
          textStyle: buttonText,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.ink,
          backgroundColor: p.card,
          padding: buttonPadding,
          minimumSize: buttonSize,
          shape: Pebble.shape(Pebble.small),
          side: BorderSide.none,
          textStyle: buttonText,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.accent,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          minimumSize: buttonSize,
          shape: Pebble.shape(Pebble.small),
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: p.ink),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          elevation: none,
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: Pebble.pill),
          ),
          side: WidgetStatePropertyAll(BorderSide(color: p.faint, width: 3)),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.card : p.faint,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? p.ink : p.muted,
          ),
          textStyle: WidgetStatePropertyAll(text.labelLarge),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: p.accent,
        foregroundColor: p.card,
        shape: Pebble.shape(Pebble.small),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: const OutlineInputBorder(
          borderRadius: Pebble.input,
          borderSide: BorderSide.none,
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: Pebble.input,
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: Pebble.input,
          borderSide: BorderSide(color: p.glacier, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: Pebble.input,
          borderSide: BorderSide(color: p.high, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: Pebble.input,
          borderSide: BorderSide(color: p.high, width: 2),
        ),
        labelStyle: text.bodyLarge!.copyWith(color: p.muted),
        hintStyle: text.bodyLarge!.copyWith(color: p.muted),
        prefixIconColor: p.muted,
        suffixIconColor: p.muted,
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: none,
        backgroundColor: WidgetStatePropertyAll(p.card),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: Pebble.small),
        ),
        hintStyle: WidgetStatePropertyAll(
          text.bodyLarge!.copyWith(color: p.muted),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: p.card,
        selectedColor: p.accentSoft,
        checkmarkColor: p.accent,
        labelStyle: text.labelLarge,
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        shape: const RoundedRectangleBorder(borderRadius: Pebble.pill),
      ),

      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => text.labelMedium!.copyWith(
            fontSize: 12,
            color: s.contains(WidgetState.selected) ? p.accent : p.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            size: 26,
            color: s.contains(WidgetState.selected) ? p.accent : p.muted,
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: p.card,
        selectedItemColor: p.accent,
        unselectedItemColor: p.muted,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: p.paper,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        dragHandleColor: p.muted,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.elliptical(32, 26),
            topRight: Radius.elliptical(26, 32),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: p.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: Pebble.shape(),
        titleTextStyle: text.titleLarge,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: p.ink,
        contentTextStyle: text.bodyMedium!.copyWith(color: p.paper),
        actionTextColor: p.accentSoft,
        behavior: SnackBarBehavior.floating,
        shape: Pebble.shape(Pebble.small),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: p.card,
        surfaceTintColor: Colors.transparent,
        shape: Pebble.shape(Pebble.small),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: p.ink, borderRadius: Pebble.small),
        textStyle: text.bodySmall!.copyWith(color: p.paper),
      ),

      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: p.accent,
        linearTrackColor: p.faint,
        circularTrackColor: p.faint,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.card : p.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.faint,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? p.accent : p.card,
        ),
        checkColor: WidgetStatePropertyAll(p.card),
        side: BorderSide(color: p.muted, width: 2),
      ),
      radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(p.accent)),
      sliderTheme: SliderThemeData(
        activeTrackColor: p.accent,
        inactiveTrackColor: p.faint,
        thumbColor: p.accent,
      ),

      dividerTheme: DividerThemeData(color: p.faint, thickness: 1.5, space: 1),
      iconTheme: IconThemeData(color: p.ink, size: 24),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        minVerticalPadding: 8,
        iconColor: p.ink,
        textColor: p.ink,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        iconColor: p.ink,
        collapsedIconColor: p.ink,
        shape: const Border(),
        collapsedShape: const Border(),
      ),
    );
  }
}
