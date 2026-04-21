import 'package:flutter/material.dart';

const seppanBrandColor = Color(0xFFD98B00);

ThemeData seppanLightTheme() {
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seppanBrandColor,
    brightness: Brightness.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: true,
      elevation: 0,
      scrolledUnderElevation: 1,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 20,
        color: colorScheme.onSurface,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: colorScheme.surfaceContainerLow,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      backgroundColor: colorScheme.surfaceContainer,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      showCheckmark: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: seppanBrandColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        minimumSize: const Size.fromHeight(48),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: seppanBrandColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        // Match FilledButton's default height for visual parity when
        // ElevatedButton and OutlinedButton sit next to each other
        // (e.g. edit + delete buttons on the expense detail page).
        minimumSize: const Size.fromHeight(48),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        minimumSize: const Size.fromHeight(48),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      hintStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      labelStyle: TextStyle(
        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
      ),
      floatingLabelStyle: TextStyle(
        color: colorScheme.primary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: colorScheme.outlineVariant,
      thickness: 0.5,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: seppanBrandColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: colorScheme.secondaryContainer,
      backgroundColor: colorScheme.surfaceContainer,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: colorScheme.inverseSurface,
      contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      behavior: SnackBarBehavior.floating,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 26,
      ),
      displayMedium: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 19,
      ),
      titleLarge: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 17,
      ),
      titleMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
      ),
      titleSmall: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.normal,
        fontSize: 14,
      ),
      bodyLarge: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.bold,
        fontSize: 15,
      ),
      bodyMedium: TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.normal,
        fontSize: 15,
      ),
      bodySmall: TextStyle(
        fontSize: 13,
        color: colorScheme.onSurfaceVariant,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        color: colorScheme.onSurfaceVariant,
      ),
    ),
  );
}
