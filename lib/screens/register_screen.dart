import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/auth_branding.dart';
import 'login_screen.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isLoading = true);
    try {
      final email = _emailController.text.trim();
      await context.read<AppStateProvider>().register(
        email: email,
        password: _passwordController.text,
        name: _nameController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: email)),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      ToastUtils.show(authErrorMessage(error, registering: true), backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppTheme.textSecondaryColor),
      filled: true,
      fillColor: AppTheme.surfaceColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      suffixIcon: suffix,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.errorColor, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.errorColor, width: 2)),
      errorStyle: const TextStyle(color: AppTheme.errorColor, height: 1.1),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('إنشاء حساب'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthBranding(),
                const Text('إنشاء حساب جديد', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                const Text('أنشئ حسابك لحفظ المفضلة والسجل', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 14)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('الاسم الظاهر'),
                  validator: (value) => value == null || value.trim().length < 2 ? 'أدخل اسمًا من حرفين على الأقل' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('البريد الإلكتروني'),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty || !email.contains('@')) return 'أدخل بريدًا إلكترونيًا صحيحًا';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('كلمة المرور', suffix: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondaryColor), onPressed: () => setState(() => _obscurePassword = !_obscurePassword))),
                  validator: (value) => (value == null || value.length < 8) ? 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmController,
                  obscureText: _obscureConfirm,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _register(),
                  style: const TextStyle(color: Colors.white),
                  decoration: _decoration('تأكيد كلمة المرور', suffix: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondaryColor), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))),
                  validator: (value) => value != _passwordController.text ? 'كلمتا المرور غير متطابقتين' : null,
                ),
                const SizedBox(height: 26),
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('إنشاء الحساب', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: const Text('لديك حساب؟ تسجيل الدخول', style: TextStyle(color: Colors.white, fontSize: 15)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
