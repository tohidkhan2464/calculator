import 'package:flutter/material.dart';

class ThemeConstants {
  // Modern Palette
  static const Color primaryColor = Color(0xFF1E1E1E); // Dark Grey Background
  static const Color secondaryColor =
      Color(0xFF2D2D2D); // Lighter Grey for cards/buttons
  static const Color accentColor = Color(0xFF26F4CE); // Vibrant Mint/Cyan
  static const Color errorColor = Color(0xFFFF5252); // Soft Red
  static const Color textColor = Colors.white;
  static const Color secondaryTextColor = Color(0xFFB3B3B3);

  // Button Colors
  static const Color btnNumber = Color(0xFF333333);
  static const Color btnOperator = Color(0xFF424242);
  static const Color btnFunction = Color(0xFF616161);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.light,
      surface: const Color(0xFFF5F5F5),
      onSurface: Colors.black,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),
    fontFamily: 'Roboto',
    appBarTheme: const AppBarTheme(
      color: Color(0xFFF5F5F5),
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
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: accentColor,
      brightness: Brightness.dark,
      surface: primaryColor,
      onSurface: textColor,
    ),
    scaffoldBackgroundColor: primaryColor,
    fontFamily: 'Roboto',
    iconTheme: const IconThemeData(color: textColor),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: textColor),
      bodyLarge: TextStyle(color: textColor),
    ),
  );
}
