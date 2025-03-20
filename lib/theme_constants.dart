import 'package:flutter/material.dart';

class ThemeConstants {
  static const Color accentColor = Color(0xFF008000);
  static const Color secondaryColor = Color(0xFFE8F5E9);
  static const Color errorColor = Color(0xFFD32F2F);

  static ThemeData lightTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
    ),
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      color: Colors.white,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black87),
      titleTextStyle: TextStyle(
        color: Colors.black87,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
    ),
    fontFamily: 'Roboto',
    scaffoldBackgroundColor: Colors.black87,
  );
}
