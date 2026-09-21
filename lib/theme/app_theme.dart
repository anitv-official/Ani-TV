import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../l10n/app_strings.dart';
class AppTheme {
  // AniTV 2.0 palette: blue is the accent, not the whole canvas.
  static AppPalette palette = AppPalette.blue;
  static void setPalette(AppPalette value) => palette = value;
  static const Color primaryColor = Color(0xFF42A5F5);
  static const Color primarySoft = Color(0xFF1976D2);
  static const Color accentColor = Color(0xFF64B5F6);
  static const Color backgroundColor = Color(0xFF080B12);
  static const Color cardColor = Color(0xFF101722);
  static const Color surfaceColor = Color(0xFF141E2C);
  static const Color elevatedColor = Color(0xFF1D2A3B);
  static const Color errorColor = Color(0xFFE85D75);
  static const Color successColor = Color(0xFF3D9A5F);
  static const Color warningColor = Color(0xFFC9A227);
  static const Color textPrimaryColor = Color(0xFFF5F5F7);
  static const Color textSecondaryColor = Color(0xFFB7C4D6);
  static const Color textMutedColor = Color(0xFF718096);
  static const Color borderColor = Color(0x22FFFFFF);
  static const Color highlightColor = primaryColor;
  static const Color glassColor = Color(0x14FFFFFF);

  static const double radiusSmall = 12;
  static const double radiusMedium = 16;
  static const double radiusLarge = 22;
  static const double radiusXLarge = 28;
  static const double spaceXs = 6;
  static const double spaceSm = 10;
  static const double spaceMd = 16;
  static const double spaceLg = 24;
  static const double minTap = 44;

  static List<BoxShadow> get subtleShadow => [BoxShadow(color: Colors.black.withOpacity(.28), blurRadius: 12, offset: const Offset(0, 4))];
  static List<BoxShadow> get mediumShadow => [BoxShadow(color: Colors.black.withOpacity(.38), blurRadius: 18, offset: const Offset(0, 8))];
  static LinearGradient get primaryGradient => const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF64B5F6), Color(0xFF1565C0)]);
  static LinearGradient get darkGradient => const LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xF2080B12)]);
  static LinearGradient get glassGradient => LinearGradient(colors: [Colors.white.withOpacity(.07), Colors.white.withOpacity(.02)]);
  static LinearGradient get heroOverlay => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.55), Colors.transparent, backgroundColor.withOpacity(.55), backgroundColor], stops: const [0.0, 0.32, 0.78, 1.0]);
  static BoxDecoration get cardDecoration => BoxDecoration(color: surfaceColor, borderRadius: BorderRadius.circular(radiusMedium), border: Border.all(color: borderColor));
  static SystemUiOverlayStyle get systemOverlay => const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light, systemNavigationBarColor: Colors.black, systemNavigationBarIconBrightness: Brightness.light, systemNavigationBarDividerColor: Colors.transparent);

  static ThemeData _base({required Brightness brightness}) {
    final dark = brightness == Brightness.dark;
    final background = dark ? backgroundColor : const Color(0xFFF3F3F5);
    final surface = dark ? surfaceColor : Colors.white;
    final card = dark ? cardColor : Colors.white;
    final primaryText = dark ? textPrimaryColor : const Color(0xFF141418);
    final secondaryText = dark ? textSecondaryColor : const Color(0xFF5C5C66);
    final border = dark ? borderColor : const Color(0x14000000);
    final themePrimary = switch (palette) {
      AppPalette.blue => primaryColor,
      AppPalette.red => const Color(0xFFE53935),
      AppPalette.purple => const Color(0xFF9C5CFF),
      AppPalette.green => const Color(0xFF35B86B),
    };
    return ThemeData(useMaterial3: true, brightness: brightness, visualDensity: VisualDensity.standard, scaffoldBackgroundColor: background, canvasColor: background, primaryColor: themePrimary, splashFactory: InkRipple.splashFactory, colorScheme: (dark ? const ColorScheme.dark() : const ColorScheme.light()).copyWith(primary: themePrimary, secondary: themePrimary, surface: surface, error: errorColor, onPrimary: Colors.white, onSurface: primaryText), appBarTheme: AppBarTheme(backgroundColor: background, surfaceTintColor: Colors.transparent, elevation: 0, scrolledUnderElevation: 0, centerTitle: false, titleTextStyle: TextStyle(color: primaryText, fontSize: 20, fontWeight: FontWeight.w700), iconTheme: IconThemeData(color: primaryText, size: 22), systemOverlayStyle: systemOverlay), textTheme: TextTheme(bodyLarge: TextStyle(color: primaryText, fontSize: 15, height: 1.45), bodyMedium: TextStyle(color: primaryText, fontSize: 13, height: 1.42), bodySmall: TextStyle(color: secondaryText, fontSize: 12, height: 1.35), titleLarge: TextStyle(color: primaryText, fontSize: 16, fontWeight: FontWeight.w700), titleMedium: TextStyle(color: primaryText, fontSize: 14, fontWeight: FontWeight.w600), labelMedium: TextStyle(color: secondaryText, fontSize: 11, fontWeight: FontWeight.w600)), cardTheme: CardTheme(color: card, elevation: 0, margin: EdgeInsets.zero, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium), side: BorderSide(color: border))), dividerTheme: DividerThemeData(color: border), iconTheme: IconThemeData(color: primaryText, size: 22), elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(backgroundColor: themePrimary, foregroundColor: Colors.white, minimumSize: const Size(48, 46), elevation: 0)), inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: surface, hintStyle: TextStyle(color: secondaryText), labelStyle: TextStyle(color: secondaryText)), switchTheme: SwitchThemeData(thumbColor: WidgetStatePropertyAll(Colors.white), trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? themePrimary : const Color(0xFF3A3A44)), trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent)), dialogTheme: DialogTheme(backgroundColor: surface, surfaceTintColor: Colors.transparent), bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface, modalBackgroundColor: surface), snackBarTheme: SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: dark ? elevatedColor : Colors.white));
  }
  static ThemeData get lightTheme => _base(brightness: Brightness.light);
  static ThemeData get darkTheme => _base(brightness: Brightness.dark);
}
