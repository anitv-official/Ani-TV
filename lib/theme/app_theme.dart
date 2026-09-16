import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF1976D2);
  static const Color primarySoft = Color(0xFF0D47A1);
  static const Color accentColor = Color(0xFF1976D2);
  static const Color backgroundColor = Color(0xFF0B0B0D);
  static const Color cardColor = Color(0xFF141418);
  static const Color surfaceColor = Color(0xFF1A1A20);
  static const Color elevatedColor = Color(0xFF22222A);
  static const Color errorColor = Color(0xFF1565C0);
  static const Color successColor = Color(0xFF3D9A5F);
  static const Color warningColor = Color(0xFFC9A227);
  static const Color textPrimaryColor = Color(0xFFF5F5F7);
  static const Color textSecondaryColor = Color(0xFFA8A8B3);
  static const Color textMutedColor = Color(0xFF6E6E78);
  static const Color borderColor = Color(0x22FFFFFF);
  static const Color highlightColor = primaryColor;
  static const Color glassColor = Color(0x14FFFFFF);

  static const double radiusSmall = 10;
  static const double radiusMedium = 14;
  static const double radiusLarge = 18;
  static const double radiusXLarge = 24;
  static const double spaceXs = 6;
  static const double spaceSm = 10;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double minTap = 44;

  static List<BoxShadow> get subtleShadow => [
        BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 12, offset: const Offset(0, 4)),
      ];

  static List<BoxShadow> get mediumShadow => [
        BoxShadow(color: Colors.black.withOpacity(.38), blurRadius: 18, offset: const Offset(0, 8)),
      ];

  static LinearGradient get primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF1976D2), Color(0xFF0D47A1)],
      );

  static LinearGradient get darkGradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black.withOpacity(.88)],
      );

  static LinearGradient get glassGradient => LinearGradient(
        colors: [Colors.white.withOpacity(.07), Colors.white.withOpacity(.02)],
      );

  static LinearGradient get heroOverlay => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withOpacity(.55),
          Colors.transparent,
          backgroundColor.withOpacity(.55),
          backgroundColor,
        ],
        stops: const [0.0, 0.32, 0.78, 1.0],
      );

  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(radiusMedium),
        border: Border.all(color: borderColor),
      );

  static SystemUiOverlayStyle get systemOverlay => const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
        systemNavigationBarDividerColor: Colors.transparent,
      );

  static ThemeData _base({required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    final background = dark ? backgroundColor : const Color(0xFFF3F3F5);
    final surface = dark ? surfaceColor : Colors.white;
    final card = dark ? cardColor : Colors.white;
    final primaryText = dark ? textPrimaryColor : const Color(0xFF141418);
    final secondaryText = dark ? textSecondaryColor : const Color(0xFF5C5C66);
    final border = dark ? borderColor : const Color(0x14000000);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      visualDensity: VisualDensity.standard,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      primaryColor: primaryColor,
      splashFactory: InkRipple.splashFactory,
      colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(
        primary: primaryColor,
        secondary: primarySoft,
        surface: surface,
        error: errorColor,
        onPrimary: Colors.white,
        onSurface: primaryText,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(color: primaryText, fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        iconTheme: IconThemeData(color: primaryText, size: 22),
        systemOverlayStyle: systemOverlay,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: primaryText, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.4),
        displayMedium: TextStyle(color: primaryText, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.3),
        headlineLarge: TextStyle(color: primaryText, fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2),
        headlineMedium: TextStyle(color: primaryText, fontSize: 18, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: secondaryText, fontSize: 12, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: primaryText, fontSize: 15, height: 1.45),
        bodyMedium: TextStyle(color: primaryText, fontSize: 13, height: 1.42),
        bodySmall: TextStyle(color: secondaryText, fontSize: 12, height: 1.35),
        labelLarge: TextStyle(color: primaryText, fontSize: 13, fontWeight: FontWeight.w700),
        labelMedium: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardTheme(
        color: card,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMedium),
          side: BorderSide(color: border),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: primaryText, size: 22),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? elevatedColor : const Color(0xFFF0F0F2),
        selectedColor: primaryColor,
        labelStyle: TextStyle(color: primaryText, fontSize: 12, fontWeight: FontWeight.w600),
        secondaryLabelStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: BorderSide(color: border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: primaryColor, width: 1.4)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(radiusMedium), borderSide: const BorderSide(color: errorColor)),
        hintStyle: TextStyle(color: secondaryText, fontSize: 13),
        labelStyle: TextStyle(color: secondaryText, fontSize: 13),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: primaryColor.withOpacity(.35),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 44),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          foregroundColor: textPrimaryColor,
          side: const BorderSide(color: borderColor),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          minimumSize: const Size(44, 40),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSmall)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(44, 44),
          foregroundColor: primaryText,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) => Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primaryColor : const Color(0xFF3A3A44)),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
        titleTextStyle: TextStyle(color: primaryText, fontSize: 18, fontWeight: FontWeight.w700),
        contentTextStyle: TextStyle(color: secondaryText, fontSize: 14, height: 1.45),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        showDragHandle: true,
        dragHandleColor: dark ? Colors.white24 : Colors.black26,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXLarge))),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: elevatedColor,
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
