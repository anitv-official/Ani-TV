import 'package:flutter/widgets.dart';

class AppStrings {
  final Locale locale;
  const AppStrings(this.locale);
  bool get isArabic => locale.languageCode == 'ar';
  String get appearance => isArabic ? 'المظهر' : 'Appearance';
  String get darkMode => isArabic ? 'الوضع الداكن' : 'Dark mode';
  String get darkModeOn => isArabic ? 'واجهة داكنة' : 'Dark interface';
  String get lightModeOn => isArabic ? 'واجهة بيضاء وفاتحة' : 'Light interface';
  String get themes => isArabic ? 'الثيمات' : 'Themes';
  String get blueTheme => isArabic ? 'الثيم الأزرق' : 'Blue';
  String get redTheme => isArabic ? 'الثيم الأحمر' : 'Red';
  String get purpleTheme => isArabic ? 'الثيم البنفسجي' : 'Purple';
  String get greenTheme => isArabic ? 'الثيم الأخضر' : 'Green';
  String get language => isArabic ? 'اللغة' : 'Language';
  String get arabic => isArabic ? 'العربية' : 'Arabic';
  String get english => isArabic ? 'الإنجليزية' : 'English';
  String get selectLanguage => isArabic ? 'اختيار اللغة' : 'Select language';
  String get selectTheme => isArabic ? 'اختيار الثيم' : 'Select theme';
}

extension AppStringsContext on BuildContext {
  AppStrings get strings => AppStrings(Localizations.localeOf(this));
}

enum AppPalette { blue, red, purple, green }

extension AppPaletteLabels on AppPalette {
  String label(AppStrings strings) => switch (this) {
        AppPalette.blue => strings.blueTheme,
        AppPalette.red => strings.redTheme,
        AppPalette.purple => strings.purpleTheme,
        AppPalette.green => strings.greenTheme,
      };
}

AppPalette appPaletteFromString(String? value) => AppPalette.values.firstWhere(
      (item) => item.name == value,
      orElse: () => AppPalette.blue,
    );

String appPaletteName(AppPalette palette) => palette.name;
Locale appLocale(String? code) => Locale(code == 'en' ? 'en' : 'ar');
