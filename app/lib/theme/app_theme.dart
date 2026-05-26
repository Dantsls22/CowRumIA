import 'package:flutter/material.dart';

class AppColors {
  // Primarios — alto contraste para uso en campo
  static const Color primary = Color(0xFF1B5E20); // Verde bosque oscuro
  static const Color primaryLight = Color(0xFF4CAF50); // Verde medio
  static const Color accent = Color(
    0xFFF9A825,
  ); // Amarillo campo — visible en sol
  static const Color accentDark = Color(0xFFE65100); // Naranja quemado

  // Fondo
  static const Color background = Color(0xFFF1F8E9); // Verde muy pálido
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFDCEDC8);

  // Texto
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF4E5E44);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Estados de estrés
  static const Color stressHigh = Color(0xFFD32F2F); // Rojo — muy estresada
  static const Color stressMedium = Color(
    0xFFFF8F00,
  ); // Naranja — estrés moderado
  static const Color stressLow = Color(0xFF388E3C); // Verde — sin estrés

  // Grabación
  static const Color recording = Color(0xFFD32F2F);
  static const Color recordingBg = Color(0xFFFFEBEE);
}

class AppTheme {
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Roboto',
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.textOnDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.textPrimary,
      error: AppColors.stressHigh,
      onError: AppColors.textOnDark,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textOnDark,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textOnDark,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnDark,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 3,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
}
