import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../widgets/auth_branding.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'email_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _useUsername = false;

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remembered_email');
    if (!mounted || email == null || email.isEmpty) return;
    _emailController.text = email;
    setState(() => _rememberMe = true);
  }

  Future<void> _login() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppStateProvider>();
      if (_useUsername) {
        await provider.loginWithUsername(username: _emailController.text.trim(), password: _passwordController.text);
      } else {
        await provider.login(email: _emailController.text.trim(), password: _passwordController.text);
      }
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remembered_email', _emailController.text.trim());
      } else {
        await prefs.remove('remembered_email');
      }
      if (!mounted) return;
      if (!provider.emailVerified) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: _emailController.text.trim())),
          (_) => false,
        );
        return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ToastUtils.show(authErrorMessage(error, registering: false), backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loginWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final provider = context.read<AppStateProvider>();
      await provider.loginWithGoogle();
      if (!mounted) return;
      if (!provider.emailVerified) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: provider.email)),
          (_) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
        );
      }
    } catch (error) {
      if (mounted) ToastUtils.show(authErrorMessage(error, registering: false), backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final uri = Uri.parse('https://anitv-manga-lord.vercel.app/reset-password');
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && mounted) {
        ToastUtils.show('تعذر فتح صفحة استعادة كلمة المرور. حاول مرة أخرى.', backgroundColor: Colors.red);
      }
    } catch (_) {
      if (mounted) {
        ToastUtils.show('تعذر فتح صفحة استعادة كلمة المرور. حاول مرة أخرى.', backgroundColor: Colors.red);
      }
    }
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondaryColor),
      filled: true,
      fillColor: AppTheme.surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: const BorderSide(color: AppTheme.errorColor, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMedium), borderSide: const BorderSide(color: AppTheme.errorColor, width: 1.5)),
      errorStyle: const TextStyle(color: AppTheme.errorColor, height: 1.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('تسجيل الدخول'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthBranding(),
                const Text('مرحبًا بعودتك', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('سجّل الدخول لمتابعة المشاهدة والقراءة', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(child: ChoiceChip(label: const Text('البريد الإلكتروني'), selected: !_useUsername, onSelected: (_) => setState(() => _useUsername = false))),
                    const SizedBox(width: 10),
                    Expanded(child: ChoiceChip(label: const Text('Username'), selected: _useUsername, onSelected: (_) => setState(() => _useUsername = true))),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: _useUsername ? TextInputType.text : TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration(_useUsername ? 'Username' : 'البريد الإلكتروني'),
                  validator: (value) => value == null || value.trim().isEmpty ? (_useUsername ? 'أدخل Username' : 'أدخل البريد الإلكتروني') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _login(),
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('كلمة المرور', suffix: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondaryColor), onPressed: () => setState(() => _obscurePassword = !_obscurePassword))),
                  validator: (value) => value == null || value.isEmpty ? 'أدخل كلمة المرور' : null,
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: _rememberMe,
                  onChanged: (value) => setState(() => _rememberMe = value ?? false),
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: AppTheme.primaryColor,
                  title: const Text('تذكر البريد الإلكتروني', style: TextStyle(color: AppTheme.textSecondaryColor)),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(onPressed: _isLoading ? null : _forgotPassword, child: const Text('نسيت كلمة المرور؟')),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 46,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall))),
                    child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('تسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : _loginWithGoogle,
                  icon: const Text('G', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  label: const Text('Sign in with Google', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.borderColor),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusSmall)),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: const Text('ليس لديك حساب؟ إنشاء حساب', style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
