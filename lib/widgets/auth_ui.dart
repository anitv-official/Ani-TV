import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AuthUi {
  static InputDecoration fieldDecoration(String hint, {String? label, Widget? suffix, Widget? prefix, String? errorText}) => InputDecoration(
        hintText: hint,
        labelText: label,
        hintStyle: const TextStyle(color: AppTheme.textMutedColor),
        labelStyle: const TextStyle(color: AppTheme.textSecondaryColor),
        floatingLabelStyle: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w700),
        filled: true,
        fillColor: const Color(0xFF101B2D),
        prefixIcon: prefix,
        suffixIcon: suffix,
        errorText: errorText,
        errorStyle: const TextStyle(color: Color(0xFFFF7B86), fontSize: 11),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.borderColor.withOpacity(.9))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.borderColor.withOpacity(.9))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.6)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5964), width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFFF5964), width: 1.6)),
      );

  static ButtonStyle primaryButton({double radius = 16}) => ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppTheme.primaryColor.withOpacity(.42),
        disabledForegroundColor: Colors.white70,
        minimumSize: const Size.fromHeight(54),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      );

  static ButtonStyle secondaryButton({double radius = 16}) => OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        minimumSize: const Size.fromHeight(54),
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(.72)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      );
}

class AuthBrandHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool compact;
  const AuthBrandHeader({super.key, required this.title, this.subtitle, this.compact = false});

  @override
  Widget build(BuildContext context) => Column(children: [
        Image.asset('assets/images/anitv_logo_transparent.png', width: compact ? 112 : 148, height: compact ? 48 : 62, fit: BoxFit.contain),
        SizedBox(height: compact ? 12 : 18),
        Text(title, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: compact ? 24 : 28, height: 1.2, fontWeight: FontWeight.w900)),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle!, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14, height: 1.5)),
        ],
      ]);
}

class AuthProgress extends StatelessWidget {
  final int current;
  final int total;
  const AuthProgress({super.key, required this.current, required this.total});
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: total <= 0 ? 0 : current / total, minHeight: 7, backgroundColor: const Color(0xFF18263A), color: AppTheme.primaryColor))),
        const SizedBox(width: 12),
        Text('$current / $total', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12, fontWeight: FontWeight.w800)),
      ]);
}

class AuthTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback? onBack;
  const AuthTopBar({super.key, required this.title, this.onBack});
  @override
  Size get preferredSize => const Size.fromHeight(58);
  @override
  Widget build(BuildContext context) => AppBar(
        title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
        centerTitle: true,
        leading: IconButton(tooltip: 'رجوع', onPressed: onBack ?? () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white)),
        backgroundColor: AppTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      );
}

class AuthPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const AuthPanel({super.key, required this.child, this.padding = const EdgeInsets.all(18)});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: const Color(0xFF0B1626).withOpacity(.9), borderRadius: BorderRadius.circular(24), border: Border.all(color: AppTheme.borderColor.withOpacity(.85)), boxShadow: AppTheme.subtleShadow),
        child: child,
      );
}

class AuthStatusMessage extends StatelessWidget {
  final String message;
  final bool success;
  const AuthStatusMessage({super.key, required this.message, this.success = false});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: (success ? Colors.greenAccent : const Color(0xFFFF6670)).withOpacity(.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: (success ? Colors.greenAccent : const Color(0xFFFF6670)).withOpacity(.35))),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(success ? Icons.check_circle_outline : Icons.error_outline, color: success ? Colors.greenAccent : const Color(0xFFFF7B86), size: 18), const SizedBox(width: 8), Expanded(child: Text(message, style: TextStyle(color: success ? Colors.greenAccent : const Color(0xFFFFA1A8), fontSize: 12, height: 1.4))) ]),
      );
}

class AuthPageBackground extends StatelessWidget {
  final Widget child;
  const AuthPageBackground({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(color: AppTheme.backgroundColor),
        child: Stack(children: [
          Positioned(top: -100, right: -80, child: IgnorePointer(child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor.withOpacity(.07))))),
          Positioned(bottom: -120, left: -100, child: IgnorePointer(child: Container(width: 280, height: 280, decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryColor.withOpacity(.045)))),
          child,
        ]),
      );
}
