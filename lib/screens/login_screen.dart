import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/auth_ui.dart';
import 'home_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifier = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false, _obscure = true, _remember = false;
  int _step = 0;

  @override
  void initState() { super.initState(); _loadSavedEmail(); }
  @override
  void dispose() { _identifier.dispose(); _password.dispose(); super.dispose(); }
  Future<void> _loadSavedEmail() async { final prefs = await SharedPreferences.getInstance(); final value = prefs.getString('remembered_email'); if (mounted && value != null) setState(() { _identifier.text = value; _remember = true; }); }

  void _next() { if (_step == 0) { if (_identifier.text.trim().isEmpty) { _show('أدخل البريد الإلكتروني أو اسم المستخدم'); return; } setState(() => _step = 1); } else { _login(); } }
  Future<void> _login() async {
    if (_password.text.isEmpty) { _show('أدخل كلمة المرور'); return; }
    setState(() => _loading = true);
    try {
      final provider = context.read<AppStateProvider>();
      final identifier = _identifier.text.trim();
      final isEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(identifier);
      if (!isEmail) { await provider.loginWithUsername(username: identifier, password: _password.text); } else { await provider.login(email: identifier, password: _password.text); }
      final prefs = await SharedPreferences.getInstance();
      if (_remember) { await prefs.setString('remembered_email', identifier); } else { await prefs.remove('remembered_email'); }
      if (!mounted) return;
      if (!provider.emailVerified) { Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: identifier)), (_) => false); } else { Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const HomeScreen()), (_) => false); }
    } catch (error) { if (mounted) ToastUtils.show(authErrorMessage(error, registering: false), backgroundColor: AppTheme.errorColor); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _forgotPassword() async { try { final opened = await launchUrl(Uri.parse('https://anitv-tau.vercel.app/reset-password'), mode: LaunchMode.externalApplication); if (!opened && mounted) _show('تعذر فتح صفحة استعادة كلمة المرور.'); } catch (_) { if (mounted) _show('تعذر فتح صفحة استعادة كلمة المرور.'); } }
  void _show(String message) => ToastUtils.show(message, backgroundColor: AppTheme.errorColor);

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: const AuthTopBar(title: 'مستخدم سابق'),
        body: AuthPageBackground(child: SafeArea(child: Form(child: ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 32), children: [
          const AuthBrandHeader(title: 'مرحبًا بعودتك', subtitle: 'خطوة واحدة تفصلك عن متابعة عالمك المفضل'),
          const SizedBox(height: 24),
          AuthPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AuthProgress(current: _step + 1, total: 2),
            const SizedBox(height: 24),
            AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: _step == 0 ? _identifierStep() : _passwordStep()),
            const SizedBox(height: 24),
            Row(children: [if (_step > 0) Expanded(child: OutlinedButton(onPressed: _loading ? null : () => setState(() => _step = 0), style: AuthUi.secondaryButton(), child: const Text('رجوع'))), if (_step > 0) const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: _loading ? null : _next, style: AuthUi.primaryButton(), child: _loading ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_step == 0 ? 'متابعة' : 'تسجيل الدخول', style: const TextStyle(fontWeight: FontWeight.bold))))]),
            if (_step == 1) Align(alignment: AlignmentDirectional.center, child: TextButton(onPressed: _loading ? null : _forgotPassword, child: const Text('نسيت كلمة المرور؟'))),
          ])),
        ]))),
      );

  Widget _identifierStep() => Column(key: const ValueKey('identifier'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('البريد الإلكتروني أو اسم المستخدم', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextFormField(controller: _identifier, autofocus: true, textDirection: TextDirection.ltr, keyboardType: TextInputType.emailAddress, style: const TextStyle(color: Colors.white), decoration: AuthUi.fieldDecoration('example@email.com'), onFieldSubmitted: (_) => _next()),
        const SizedBox(height: 10),
        CheckboxListTile(value: _remember, onChanged: (v) => setState(() => _remember = v ?? false), contentPadding: EdgeInsets.zero, activeColor: AppTheme.primaryColor, title: const Text('تذكر البريد الإلكتروني', style: TextStyle(color: AppTheme.textSecondaryColor))),
      ]);

  Widget _passwordStep() => Column(key: const ValueKey('password'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('كلمة المرور', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        TextFormField(controller: _password, autofocus: true, obscureText: _obscure, textInputAction: TextInputAction.done, onFieldSubmitted: (_) => _next(), style: const TextStyle(color: Colors.white), decoration: AuthUi.fieldDecoration('كلمة المرور', suffix: IconButton(tooltip: _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور', icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondaryColor), onPressed: () => setState(() => _obscure = !_obscure)))),
      ]);
}
