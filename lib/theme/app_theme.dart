import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFE50914);
  static const Color accentColor = Color(0xFFF47521);
  static const Color backgroundColor = Color(0xFF141414);
  static const Color cardColor = Color(0xFF1F1F1F);
  static const Color surfaceColor = Color(0xFF242424);
  static const Color errorColor = Color(0xFFB00020);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Color(0xFFB3B3B3);
  static const Color highlightColor = primaryColor;
  static const Color glassColor = Color(0x22FFFFFF);

  static const double radiusSmall = 8;
  static const double radiusMedium = 12;
  static const double radiusLarge = 16;
  static const double radiusXLarge = 20;

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(color: Colors.black.withOpacity(.22), blurRadius: 12, offset: const Offset(0, 4)),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(color: Colors.black.withOpacity(.30), blurRadius: 18, offset: const Offset(0, 8)),
      ];

  static List<BoxShadow> get heavyShadow => [
        BoxShadow(color: Colors.black.withOpacity(.38), blurRadius: 26, offset: const Offset(0, 12)),
      ];

  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor.withOpacity(.86), accentColor.withOpacity(.62)],
      );

  static LinearGradient get darkGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black.withOpacity(.82)],
      );

  static LinearGradient get glassGradient => LinearGradient(
        colors: [Colors.white.withOpacity(.09), Colors.white.withOpacity(.03)],
      );

  static ThemeData _base({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;
    final background = isDark ? backgroundColor : const Color(0xFFF6F6F7);
    final surface = isDark ? surfaceColor : Colors.white;
    final primaryText = isDark ? Colors.white : const Color(0xFF171717);
    final secondaryText = isDark ? textSecondaryColor : const Color(0xFF656565);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: primaryColor,
      colorScheme: (isDark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: primaryColor,
        secondary: accentColor,
        surface: surface,
        error: errorColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: primaryText, fontSize: 20, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: primaryText, size: 22),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: primaryText, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -.4),
        displayMedium: TextStyle(color: primaryText, fontSize: 26, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(color: primaryText, fontSize: 23, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: primaryText, fontSize: 20, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: primaryText, fontSize: 17, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: primaryText, fontSize: 15, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: secondaryText, fontSize: 13, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: primaryText, fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(color: primaryText, fontSize: 13, height: 1.4),
        bodySmall: TextStyle(color: secondaryText, fontSize: 12, height: 1.35),
        labelLarge: TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
      ),
      dividerTheme: DividerThemeData(color: isDark ? Colors.white12 : Colors.black12, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: accentColor, width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: errorColor)),
        hintStyle: TextStyle(color: secondaryText, fontSize: 13),
        labelStyle: TextStyle(color: secondaryText, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 42),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
      )),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        titleTextStyle: TextStyle(color: primaryText, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: secondaryText, fontSize: 14, height: 1.4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: isDark ? Colors.white38 : Colors.black26,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXLarge))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        contentTextStyle: TextStyle(color: primaryText, fontSize: 13),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  static ThemeData get lightTheme => _base(brightness: Brightness.light);
  static ThemeData get darkTheme => _base(brightness: Brightness.dark);
}
