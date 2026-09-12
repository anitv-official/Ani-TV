import 'package:flutter/material.dart';

class AppTheme {
  // Netflix & Manga inspired color palette
  static const Color primaryColor = Color(0xFFE50914); // Netflix Red
  static const Color accentColor = Color(0xFFF47521);  // Orange
  static const Color backgroundColor = Color(0xFF141414); // Dark background
  static const Color cardColor = Color(0xFF1F1F1F); // Slightly lighter dark
  static const Color errorColor = Color(0xFFB00020);
  static const Color textPrimaryColor = Colors.white;
  static const Color textSecondaryColor = Color(0xFFB3B3B3);
  
  // Enhanced color palette for cinematic feel
  static const Color surfaceColor = Color(0xFF252525); // Surface for elevated elements
  static const Color highlightColor = Color(0xFFE50914); // Highlight color
  static const Color glassColor = Color(0x33FFFFFF); // Glass effect overlay
  
  // Border radius constants for consistency
  static const double radiusSmall = 10.0;
  static const double radiusMedium = 13.0;
  static const double radiusLarge = 16.0;
  static const double radiusXLarge = 20.0;
  
  // Shadow constants for depth
  static List<BoxShadow> get subtleShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 6,
      offset: Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  
  static List<BoxShadow> get mediumShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.1),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];
  
  static List<BoxShadow> get heavyShadow => [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.15),
      blurRadius: 32,
      offset: Offset(0, 16),
    ),
  ];
  
  // Gradient overlays for cinematic effect
  static LinearGradient get primaryGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryColor.withOpacity(0.8),
      primaryColor.withOpacity(0.6),
      accentColor.withOpacity(0.4),
    ],
  );
  
  static LinearGradient get darkGradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Colors.transparent,
      Colors.black.withOpacity(0.3),
      Colors.black.withOpacity(0.7),
    ],
  );
  
  static LinearGradient get glassGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white.withOpacity(0.1),
      Colors.white.withOpacity(0.05),
    ],
  );

  // Light theme (though app will primarily use dark theme)
  static ThemeData lightTheme = ThemeData(
    primaryColor: primaryColor,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      surface: Colors.white,
    ),
    scaffoldBackgroundColor: Colors.white,
    cardColor: Colors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white, 
        fontSize: 20, 
        fontWeight: FontWeight.bold
      ),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: accentColor,
      indicatorSize: TabBarIndicatorSize.tab,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: accentColor,
      foregroundColor: Colors.white,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: Colors.black87),
      bodyMedium: TextStyle(color: Colors.black87),
      titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      titleSmall: TextStyle(color: Colors.black54),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      ),
    ),
  );

  // Dark theme (Netflix inspired)
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    visualDensity: VisualDensity.compact,
    primaryColor: primaryColor,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      error: errorColor,
      surface: surfaceColor,
    ),
    scaffoldBackgroundColor: backgroundColor,
    cardColor: surfaceColor,
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.5,
      ),
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorColor: accentColor,
      indicatorSize: TabBarIndicatorSize.tab,
      labelStyle: TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: backgroundColor,
      selectedItemColor: primaryColor,
      unselectedItemColor: textSecondaryColor,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: surfaceColor,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusLarge)),
      titleTextStyle: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: textSecondaryColor, fontSize: 14, height: 1.45),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: surfaceColor,
      modalBackgroundColor: surfaceColor,
      showDragHandle: true,
      dragHandleColor: Colors.white38,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXLarge))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMedium)),
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
    ),
    dividerTheme: DividerThemeData(color: Colors.white.withOpacity(.08), thickness: 1, space: 1),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: <TargetPlatform, PageTransitionsBuilder>{
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      elevation: 8,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: Colors.white,
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
      ),
      displayMedium: TextStyle(
        color: Colors.white,
        fontSize: 28,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.25,
      ),
      headlineLarge: TextStyle(
        color: Colors.white,
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.15,
      ),
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      titleMedium: TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        color: textSecondaryColor,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      bodyLarge: TextStyle(
        color: Colors.white,
        fontSize: 15,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        color: Colors.white,
        fontSize: 13,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.25,
        height: 1.4,
      ),
      bodySmall: TextStyle(
        color: textSecondaryColor,
        fontSize: 12,
        fontWeight: FontWeight.normal,
        letterSpacing: 0.4,
        height: 1.3,
      ),
      labelLarge: TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: textSecondaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: primaryColor.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        minimumSize: const Size(0, 42),
        padding: EdgeInsets.symmetric(vertical: 10, horizontal: 18),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: BorderSide(color: primaryColor, width: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        minimumSize: const Size(0, 40),
        padding: EdgeInsets.symmetric(vertical: 9, horizontal: 18),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSmall),
        ),
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        textStyle: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: textSecondaryColor.withOpacity(0.3), width: 1),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: accentColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
        borderSide: BorderSide(color: errorColor, width: 2),
      ),
      labelStyle: TextStyle(color: textSecondaryColor),
      hintStyle: TextStyle(color: textSecondaryColor.withOpacity(0.7)),
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
    cardTheme: CardTheme(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      color: surfaceColor,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: surfaceColor,
      selectedColor: primaryColor,
      disabledColor: Colors.grey.withOpacity(0.3),
      labelStyle: TextStyle(color: Colors.white),
      secondaryLabelStyle: TextStyle(color: Colors.white),
      brightness: Brightness.dark,
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radiusSmall),
      ),
    ),
  );
}
