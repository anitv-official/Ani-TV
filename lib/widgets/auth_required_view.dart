import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/primary_button.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';

class AuthRequiredView extends StatelessWidget {
  final String title;
  final String message;
  const AuthRequiredView({super.key, this.title = 'الميزة تتطلب حسابًا', this.message = 'سجّل الدخول أو أنشئ حسابًا لاستخدام هذه الميزة وحفظ بياناتك بأمان.'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 82, height: 82, decoration: BoxDecoration(color: AppTheme.surfaceColor, shape: BoxShape.circle, border: Border.all(color: AppTheme.borderColor)), child: const Icon(Icons.lock_outline_rounded, color: AppTheme.primaryColor, size: 38)),
            const SizedBox(height: 22),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14, height: 1.5)),
            const SizedBox(height: 24),
            PrimaryButton(expanded: true, label: 'تسجيل الدخول', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())), style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52), side: const BorderSide(color: AppTheme.borderColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: const Text('إنشاء حساب', style: TextStyle(color: Colors.white, fontSize: 16))),
          ],
        ),
      ),
    );
  }
}
