import 'package:flutter/material.dart';

/// brownpaw App Theme
///
/// Designed for outdoor use with high contrast and readability.
/// Colors inspired by whitewater kayaking: river blues, water whites,
/// earthy tones for safety and natural elements.
class AppTheme {
  // Private constructor to prevent instantiation
  AppTheme._();

  // Brand Colors - River-inspired palette
  static const Color _primaryRiverBlue = Color(
    0xFF1E88E5,
  ); // Vibrant river blue
  static const Color _deepWater = Color(0xFF0D47A1); // Deep water blue
  static const Color _whitewater = Color(0xFFE3F2FD); // Whitewater foam
  static const Color _rapids = Color(0xFF42A5F5); // Light rapids blue

  // Accent Colors
  static const Color _safetyOrange = Color(
    0xFFFF6F00,
  ); // High visibility safety
  static const Color _warningAmber = Color(0xFFFFB300); // Caution/warning
  static const Color _successGreen = Color(0xFF43A047); // Go/safe
  static const Color _dangerRed = Color(0xFFE53935); // Stop/danger

  // Neutral Colors - Earthy tones
  static const Color _rockGrey = Color(0xFF455A64); // Rock/slate
  static const Color _riverbank = Color(0xFF5D4037); // Brown earth
  static const Color _mist = Color(0xFFECEFF1); // Morning mist
  static const Color _shadow = Color(0xFF263238); // Deep shadow

  // Text Colors
  static const Color _textDark = Color(0xFF212121);
  static const Color _textMedium = Color(0xFF757575);
  static const Color _textLight = Color(0xFFBDBDBD);
  static const Color _textOnPrimary = Colors.white;

  /// Light Theme - Primary theme for most conditions
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      // Color Scheme
      colorScheme: const ColorScheme.light(
        primary: _primaryRiverBlue,
        onPrimary: _textOnPrimary,
        primaryContainer: _whitewater,
        onPrimaryContainer: _deepWater,

        secondary: _safetyOrange,
        onSecondary: _textOnPrimary,
        secondaryContainer: Color(0xFFFFE0B2),
        onSecondaryContainer: Color(0xFFE65100),

        tertiary: _rockGrey,
        onTertiary: _textOnPrimary,
        tertiaryContainer: _mist,
        onTertiaryContainer: _shadow,

        error: _dangerRed,
        onError: _textOnPrimary,

        surface: Colors.white,
        onSurface: _textDark,
        surfaceContainerHighest: _mist,

        outline: Color(0xFFBDBDBD),
        outlineVariant: Color(0xFFE0E0E0),
      ),

      // Typography - Optimized for outdoor readability
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.25,
          color: _textDark,
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.bold,
          color: _textDark,
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: _textDark,
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: _textDark,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: _textDark,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: _textDark,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: _textDark,
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: _textDark,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
          color: _textDark,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.25,
          color: _textDark,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.4,
          color: _textMedium,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: _textDark,
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: _textDark,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: _textMedium,
        ),
      ),

      // AppBar Theme - High contrast for outdoor visibility
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: _primaryRiverBlue,
        foregroundColor: _textOnPrimary,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: _textOnPrimary,
        ),
      ),

      // Card Theme - Elevated, clear separation
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Elevated Button - Primary actions
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(64, 48), // Touch-friendly
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Outlined Button - Secondary actions
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(width: 2),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Text Button - Tertiary actions
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: _safetyOrange,
        foregroundColor: _textOnPrimary,
      ),

      // Input Decoration - Forms
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _mist,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _primaryRiverBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _dangerRed, width: 2),
        ),
        labelStyle: const TextStyle(fontSize: 16, color: _textMedium),
        hintStyle: const TextStyle(fontSize: 16, color: _textLight),
      ),

      // Chip Theme
      chipTheme: ChipThemeData(
        backgroundColor: _mist,
        selectedColor: _rapids,
        labelStyle: const TextStyle(fontSize: 14, color: _textDark),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      // Bottom Navigation Bar
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        selectedItemColor: _primaryRiverBlue,
        unselectedItemColor: _textMedium,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE0E0E0),
        thickness: 1,
        space: 1,
      ),

      // Icon Theme
      iconTheme: const IconThemeData(color: _textDark, size: 24),

      // List Tile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 8,
      ),
    );
  }

  /// Dark Theme - For low-light conditions or user preference
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      // Color Scheme
      colorScheme: const ColorScheme.dark(
        primary: _rapids,
        onPrimary: _textDark,
        primaryContainer: _deepWater,
        onPrimaryContainer: _whitewater,

        secondary: _safetyOrange,
        onSecondary: _textDark,
        secondaryContainer: Color(0xFFBF360C),
        onSecondaryContainer: Color(0xFFFFCCBC),

        tertiary: _rockGrey,
        onTertiary: _textOnPrimary,
        tertiaryContainer: _shadow,
        onTertiaryContainer: _mist,

        error: Color(0xFFEF5350),
        onError: _textDark,

        surface: Color(0xFF121212),
        onSurface: Color(0xFFE0E0E0),
        surfaceContainerHighest: Color(0xFF2C2C2C),

        outline: Color(0xFF616161),
        outlineVariant: Color(0xFF424242),
      ),

      // Keep same text theme structure but adapt colors
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 57,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.25,
          color: Color(0xFFE0E0E0),
        ),
        displayMedium: TextStyle(
          fontSize: 45,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE0E0E0),
        ),
        displaySmall: TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE0E0E0),
        ),
        headlineLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFE0E0E0),
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE0E0E0),
        ),
        headlineSmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE0E0E0),
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          color: Color(0xFFE0E0E0),
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
          color: Color(0xFFE0E0E0),
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: Color(0xFFE0E0E0),
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.5,
          color: Color(0xFFE0E0E0),
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.25,
          color: Color(0xFFE0E0E0),
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          letterSpacing: 0.4,
          color: Color(0xFFBDBDBD),
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
          color: Color(0xFFE0E0E0),
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Color(0xFFE0E0E0),
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: Color(0xFFBDBDBD),
        ),
      ),

      // AppBar Theme
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: false,
        backgroundColor: Color(0xFF1A1A1A),
        foregroundColor: Color(0xFFE0E0E0),
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE0E0E0),
        ),
      ),

      // Card Theme
      cardTheme: CardThemeData(
        elevation: 2,
        color: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),

      // Button themes (similar structure to light theme)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          side: const BorderSide(width: 2),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          minimumSize: const Size(64, 48),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 4,
        backgroundColor: _safetyOrange,
        foregroundColor: _textDark,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF2C2C2C),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF616161)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _rapids, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFEF5350), width: 2),
        ),
        labelStyle: const TextStyle(fontSize: 16, color: Color(0xFFBDBDBD)),
        hintStyle: const TextStyle(fontSize: 16, color: Color(0xFF757575)),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF2C2C2C),
        selectedColor: _deepWater,
        labelStyle: const TextStyle(fontSize: 14, color: Color(0xFFE0E0E0)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        elevation: 8,
        backgroundColor: Color(0xFF1A1A1A),
        selectedItemColor: _rapids,
        unselectedItemColor: Color(0xFF757575),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
      ),

      dividerTheme: const DividerThemeData(
        color: Color(0xFF424242),
        thickness: 1,
        space: 1,
      ),

      iconTheme: const IconThemeData(color: Color(0xFFE0E0E0), size: 24),

      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 8,
      ),
    );
  }

  // Semantic Colors - For specific use cases
  static const Color riverLevelLow = Color(0xFFD32F2F); // Red - Low/dangerous
  static const Color riverLevelMedium = _successGreen; // Green - Good
  static const Color riverLevelHigh = _warningAmber; // Amber - Caution
  static const Color riverLevelFlood = Color(0xFF6A1B9A); // Purple - Flood

  static const Color difficultyClass1 = Color(0xFF4CAF50); // Green
  static const Color difficultyClass2 = Color(0xFF8BC34A); // Light green
  static const Color difficultyClass3 = Color(0xFFFFEB3B); // Yellow
  static const Color difficultyClass4 = Color(0xFFFF9800); // Orange
  static const Color difficultyClass5 = Color(0xFFFF5722); // Deep orange
  static const Color difficultyClass6 = Color(0xFF000000); // Black
}
