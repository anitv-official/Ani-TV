import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/auth_branding.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Timer? _usernameTimer;
  bool _loading = false, _checkingUsername = false, _obscure = true, _obscureConfirm = true;
  bool? _usernameAvailable;
  String? _usernameMessage, _country, _imagePath;
  DateTime? _birthDate;
  static const _countries = <String>['السعودية', 'مصر', 'الإمارات', 'الكويت', 'قطر', 'الأردن', 'العراق', 'المغرب', 'الجزائر', 'تونس', 'ليبيا', 'فلسطين', 'اليمن', 'عُمان', 'البحرين', 'سوريا', 'لبنان', 'أخرى'];

  @override
  void dispose() {
    _usernameTimer?.cancel();
    for (final c in [_name, _email, _username, _password, _confirm]) c.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();
    final normalized = UsernameValidation.normalize(value);
    setState(() { _usernameAvailable = null; _usernameMessage = null; });
    if (normalized.isEmpty) return;
    if (normalized.length < 3) { setState(() => _usernameMessage = 'يجب أن يتكون Username من 3 أحرف على الأقل'); return; }
    if (!UsernameValidation.isValid(normalized)) { setState(() => _usernameMessage = 'استخدم الأحرف الإنجليزية الصغيرة والأرقام و _ فقط'); return; }
    setState(() { _checkingUsername = true; _usernameMessage = 'جارٍ التحقق...'; });
    _usernameTimer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final available = await AppwriteService.instance.isUsernameAvailable(normalized);
        if (!mounted || _username.text.trim().toLowerCase() != normalized) return;
        setState(() { _usernameAvailable = available; _checkingUsername = false; _usernameMessage = available ? 'اسم المستخدم متوفر' : 'اسم المستخدم مأخوذ بالفعل'; });
      } catch (error) {
        debugPrint('Username availability check failed: $error');
        if (mounted) setState(() { _checkingUsername = false; _usernameMessage = 'تعذر التحقق من اسم المستخدم'; });
      }
    });
  }

  Future<void> _chooseBirthDate() async {
    final picked = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime.now(), initialDate: DateTime.now().subtract(const Duration(days: 365 * 18)), helpText: 'اختر تاريخ الميلاد');
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _chooseImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: false);
      final path = result?.files.single.path;
      if (path != null && path.isNotEmpty) setState(() => _imagePath = path);
    } catch (error) {
      debugPrint('Profile image selection failed: $error');
      if (mounted) ToastUtils.show('تعذر اختيار الصورة. يمكنك المتابعة بدون صورة.', backgroundColor: AppTheme.errorColor);
    }
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_usernameAvailable != true) { ToastUtils.show(_usernameMessage ?? 'تحقق من توفر اسم المستخدم أولًا.', backgroundColor: AppTheme.errorColor); return; }
    if (_birthDate == null || _country == null) { ToastUtils.show('اختر تاريخ الميلاد والدولة.', backgroundColor: AppTheme.errorColor); return; }
    setState(() => _loading = true);
    final email = _email.text.trim();
    try {
      await context.read<AppStateProvider>().register(
        email: email, password: _password.text, name: _name.text.trim(), username: _username.text.trim().toLowerCase(),
        birthDate: _birthDate!.toIso8601String().split('T').first, country: _country!, profileImagePath: _imagePath,
      );
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: email)), (_) => false);
    } catch (error) {
      if (mounted) ToastUtils.show(authErrorMessage(error, registering: true), backgroundColor: AppTheme.errorColor);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint, hintStyle: const TextStyle(color: AppTheme.textSecondaryColor), filled: true, fillColor: AppTheme.surfaceColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16), suffixIcon: suffix,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.errorColor)),
    errorStyle: const TextStyle(color: AppTheme.errorColor),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    appBar: AppBar(title: const Text('إنشاء حساب'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop())),
    body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(24, 18, 24, 32), child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const AuthBranding(),
      const Text('إنشاء حساب جديد', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
      const SizedBox(height: 24),
      TextFormField(controller: _username, onChanged: _onUsernameChanged, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white), decoration: _decoration('Username', suffix: _checkingUsername ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null), validator: (v) => !UsernameValidation.isValid(v ?? '') ? 'Username غير صالح' : null),
      if (_usernameMessage != null) Padding(padding: const EdgeInsets.only(top: 6, right: 4), child: Text(_usernameMessage!, style: TextStyle(color: _usernameAvailable == true ? Colors.greenAccent : AppTheme.errorColor, fontSize: 12))),
      const SizedBox(height: 14),
      TextFormField(controller: _name, style: const TextStyle(color: Colors.white), decoration: _decoration('الاسم الظاهر'), validator: (v) => v == null || v.trim().length < 2 ? 'أدخل اسمًا من حرفين على الأقل' : null),
      const SizedBox(height: 14),
      TextFormField(controller: _email, keyboardType: TextInputType.emailAddress, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white), decoration: _decoration('البريد الإلكتروني'), validator: (v) => v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()) ? 'أدخل بريدًا إلكترونيًا صحيحًا' : null),
      const SizedBox(height: 14),
      TextFormField(controller: _password, obscureText: _obscure, style: const TextStyle(color: Colors.white), decoration: _decoration('كلمة المرور', suffix: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondaryColor), onPressed: () => setState(() => _obscure = !_obscure))), validator: (v) => v == null || v.length < 8 ? 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل' : null),
      const SizedBox(height: 14),
      TextFormField(controller: _confirm, obscureText: _obscureConfirm, style: const TextStyle(color: Colors.white), decoration: _decoration('تأكيد كلمة المرور', suffix: IconButton(icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondaryColor), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm))), validator: (v) => v != _password.text ? 'كلمتا المرور غير متطابقتين' : null),
      const SizedBox(height: 14),
      OutlinedButton.icon(onPressed: _chooseBirthDate, icon: const Icon(Icons.cake_outlined), label: Text(_birthDate == null ? 'اختيار تاريخ الميلاد' : 'تاريخ الميلاد: ${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}')),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(value: _country, dropdownColor: AppTheme.surfaceColor, decoration: _decoration('الدولة'), items: _countries.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) => setState(() => _country = v), validator: (v) => v == null ? 'اختر الدولة' : null),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _chooseImage, icon: const Icon(Icons.photo_library_outlined), label: Text(_imagePath == null ? 'اختيار صورة البروفايل (اختياري)' : 'تغيير صورة البروفايل')),
      if (_imagePath != null) Padding(padding: const EdgeInsets.only(top: 10), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(_imagePath!), height: 150, fit: BoxFit.cover))),
      const SizedBox(height: 24),
      SizedBox(height: 54, child: ElevatedButton(onPressed: _loading ? null : _register, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))), child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('إنشاء الحساب', style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)))),
      TextButton(onPressed: () => Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const LoginScreen())), child: const Text('لديك حساب؟ تسجيل الدخول', style: TextStyle(color: Colors.white))),
    ]))),
  );
}
