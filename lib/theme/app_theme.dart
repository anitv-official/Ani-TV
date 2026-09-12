import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFE50914);
  static const Color accentColor = Color(0xFF21B6B1);
  static const Color backgroundColor = Color(0xFF101214);
  static const Color cardColor = Color(0xFF191C20);
  static const Color surfaceColor = Color(0xFF20242A);
  static const Color errorColor = Color(0xFFB00020);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Color(0xFFB7BDC5);
  static const Color highlightColor = accentColor;
  static const Color glassColor = Color(0x22FFFFFF);

  static const double radiusSmall = 8;
  static const double radiusMedium = 11;
  static const double radiusLarge = 15;
  static const double radiusXLarge = 18;

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(color: Colors.black.withOpacity(.24), blurRadius: 10, offset: const Offset(0, 3)),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(color: Colors.black.withOpacity(.32), blurRadius: 16, offset: const Offset(0, 6)),
      ];

  static LinearGradient get primaryGradient => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryColor.withOpacity(.88), accentColor.withOpacity(.65)],
      );

  static LinearGradient get darkGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black.withOpacity(.86)],
      );

  static LinearGradient get glassGradient => LinearGradient(
        colors: [Colors.white.withOpacity(.08), Colors.white.withOpacity(.025)],
      );

  static ThemeData _base({required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    final background = dark ? backgroundColor : const Color(0xFFF4F5F6);
    final surface = dark ? surfaceColor : Colors.white;
    final primaryText = dark ? Colors.white : const Color(0xFF17191C);
    final secondaryText = dark ? textSecondaryColor : const Color(0xFF626870);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.compact,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: primaryColor,
      colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
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
        titleTextStyle: TextStyle(color: primaryText, fontSize: 18, fontWeight: FontWeight.w700),
        iconTheme: IconThemeData(color: primaryText, size: 21),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: primaryText, fontSize: 28, fontWeight: FontWeight.w700),
        displayMedium: TextStyle(color: primaryText, fontSize: 24, fontWeight: FontWeight.w700),
        headlineLarge: TextStyle(color: primaryText, fontSize: 21, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: primaryText, fontSize: 18, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: primaryText, fontSize: 14, height: 1.45),
        bodyMedium: TextStyle(color: primaryText, fontSize: 12.5, height: 1.4),
        bodySmall: TextStyle(color: secondaryText, fontSize: 11.5, height: 1.35),
        labelLarge: TextStyle(color: primaryText, fontSize: 13, fontWeight: FontWeight.w600),
        labelMedium: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardTheme(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
      ),
      dividerTheme: DividerThemeData(color: dark ? Colors.white12 : Colors.black12, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide(color: dark ? Colors.white10 : Colors.black12)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: accentColor, width: 1.4)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: errorColor)),
        hintStyle: TextStyle(color: secondaryText, fontSize: 12.5),
        labelStyle: TextStyle(color: secondaryText, fontSize: 12.5),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 40),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        foregroundColor: accentColor,
        side: const BorderSide(color: accentColor),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
      )),
      textButtonTheme: TextButtonThemeData(style: TextButton.styleFrom(
        foregroundColor: accentColor,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
      )),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        titleTextStyle: TextStyle(color: primaryText, fontSize: 17, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: secondaryText, fontSize: 13, height: 1.4),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: dark ? Colors.white38 : Colors.black26,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXLarge))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
        contentTextStyle: TextStyle(color: primaryText, fontSize: 12.5),
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
