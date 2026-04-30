import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Premium dark luxury theme — black/red cinematic palette
class AppTheme {
  AppTheme._();

  static const Color bgPrimary   = Color(0xFF080808);
  static const Color bgSurface   = Color(0xFF111111);
  static const Color bgCard      = Color(0xFF1C1C1C);
  static const Color accentRed   = Color(0xFFD32F2F);
  static const Color accentGold  = Color(0xFFD4AF37);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textMuted   = Color(0xFF9E9E9E);

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0xCC000000)],
    stops: [0.45, 1.0],
  );

  static const LinearGradient redGoldGradient = LinearGradient(
    colors: [accentRed, Color(0xFF8B0000)],
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bgPrimary,
    colorScheme: const ColorScheme.dark(
      primary: accentRed,
      secondary: accentGold,
      surface: bgSurface,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      titleTextStyle: TextStyle(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
      ),
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        color: textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.5,
      ),
      labelSmall: TextStyle(
        color: textPrimary,
        fontSize: 10,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    ),
  );
}
