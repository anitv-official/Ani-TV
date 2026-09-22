import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_branding.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 42, 24, 30),
          children: [
            const AuthBranding(),
            const SizedBox(height: 30),
            const Text('ابدأ رحلتك مع AniTV', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            const Text('اختر الطريقة المناسبة للمتابعة', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 15)),
            const SizedBox(height: 34),
            _ChoiceCard(icon: Icons.person_add_alt_1_rounded, title: 'مستخدم جديد', subtitle: 'أنشئ حسابك بخطوات بسيطة', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()))),
            const SizedBox(height: 14),
            _ChoiceCard(icon: Icons.login_rounded, title: 'مستخدم سابق', subtitle: 'سجّل الدخول إلى حسابك', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false),
              icon: const Icon(Icons.visibility_outlined, color: AppTheme.textSecondaryColor),
              label: const Text('المتابعة كزائر', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 15)),
            ),
            const SizedBox(height: 16),
            const Text('أو', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
            const SizedBox(height: 10),
            const _FacebookChoiceButton(),
          ],
        ),
      ),
    );
  }
}

class _FacebookChoiceButton extends StatefulWidget {
  const _FacebookChoiceButton();

  @override
  State<_FacebookChoiceButton> createState() => _FacebookChoiceButtonState();
}

class _FacebookChoiceButtonState extends State<_FacebookChoiceButton> {
  bool _loading = false;

  Future<void> _openFacebook() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      final url = await context.read<AppStateProvider>().facebookOAuthUrl();
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تسجيل الدخول باستخدام Facebook.')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(error, registering: false))));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        onPressed: _loading ? null : _openFacebook,
        tooltip: 'التسجيل باستخدام Facebook',
        icon: _loading
            ? const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.facebook, size: 30, color: Colors.white),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFF1877F2),
          disabledBackgroundColor: const Color(0xFF1877F2).withOpacity(.55),
          fixedSize: const Size(64, 64),
          shape: const CircleBorder(),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _ChoiceCard({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surfaceColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(.15), shape: BoxShape.circle), child: Icon(icon, color: AppTheme.primaryColor)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13))])),
              const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.textSecondaryColor, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
