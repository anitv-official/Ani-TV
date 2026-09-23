import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/auth_ui.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController(), _email = TextEditingController(), _username = TextEditingController(), _password = TextEditingController(), _confirm = TextEditingController();
  Timer? _timer;
  int _step = 0;
  bool _loading = false, _checking = false, _obscure = true, _obscureConfirm = true;
  bool? _available;
  String? _message, _country, _imagePath;
  DateTime? _birthDate;
  static const countries = ['السعودية', 'مصر', 'الإمارات', 'الكويت', 'قطر', 'الأردن', 'العراق', 'المغرب', 'الجزائر', 'تونس', 'ليبيا', 'فلسطين', 'اليمن', 'عُمان', 'البحرين', 'سوريا', 'لبنان', 'أخرى'];

  @override void dispose() { _timer?.cancel(); for (final controller in [_name, _email, _username, _password, _confirm]) controller.dispose(); super.dispose(); }
  void _usernameChanged(String value) {
    _timer?.cancel();
    final normalized = UsernameValidation.normalize(value);
    setState(() { _available = null; _message = null; });
    if (normalized.isEmpty) return;
    if (!UsernameValidation.isValid(normalized)) { setState(() => _message = 'استخدم الأحرف الإنجليزية الصغيرة والأرقام و _ فقط'); return; }
    setState(() { _checking = true; _message = 'جارٍ التحقق...'; });
    _timer = Timer(const Duration(milliseconds: 450), () async {
      try {
        final available = await AppwriteService.instance.isUsernameAvailable(normalized);
        if (!mounted || UsernameValidation.normalize(_username.text) != normalized) return;
        setState(() { _checking = false; _available = available; _message = available ? 'اسم المستخدم متاح' : 'اسم المستخدم مستخدم بالفعل'; });
      } catch (_) { if (mounted) setState(() { _checking = false; _message = 'تعذر التحقق من اسم المستخدم'; }); }
    });
  }
  Future<void> _date() async { final date = await showDatePicker(context: context, firstDate: DateTime(1900), lastDate: DateTime.now(), initialDate: DateTime.now().subtract(const Duration(days: 6570)), helpText: 'اختر تاريخ الميلاد'); if (date != null) setState(() => _birthDate = date); }
  Future<void> _image() async { try { final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false); if (result?.files.single.path != null) setState(() => _imagePath = result!.files.single.path); } catch (_) { if (mounted) ToastUtils.show('تعذر اختيار الصورة، يمكنك المتابعة بدونها.', backgroundColor: AppTheme.errorColor); } }
  bool _validStep() { switch (_step) { case 0: return _email.text.trim().isNotEmpty && RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim()); case 1: return UsernameValidation.isValid(_username.text) && _available == true; case 2: return _name.text.trim().length >= 2; case 3: return _password.text.length >= 8; case 4: return _confirm.text == _password.text && _confirm.text.isNotEmpty; case 5: return _birthDate != null; case 6: return _country != null; default: return true; } }
  void _next() { if (!_validStep()) { ToastUtils.show(_step == 1 ? (_message ?? 'تحقق من اسم المستخدم') : 'أكمل هذه الخطوة بشكل صحيح', backgroundColor: AppTheme.errorColor); return; } if (_step < 6) setState(() => _step++); else _register(); }
  Future<void> _register() async {
    setState(() => _loading = true);
    final email = _email.text.trim();
    try {
      final result = await context.read<AppStateProvider>().register(email: email, password: _password.text, name: _name.text.trim(), username: _username.text.trim().toLowerCase(), birthDate: _birthDate!.toIso8601String().split('T').first, country: _country!, profileImagePath: _imagePath);
      if (!mounted) return;
      ToastUtils.show(result.warning ?? 'تم إنشاء الحساب بنجاح. تحقق من بريدك الإلكتروني للمتابعة.', backgroundColor: Colors.green);
      if (context.read<AppStateProvider>().emailVerified) { Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false); } else { Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => EmailVerificationScreen(email: email)), (_) => false); }
    } catch (error) { if (mounted) ToastUtils.show(authErrorMessage(error, registering: true), backgroundColor: AppTheme.errorColor); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: const AuthTopBar(title: 'مستخدم جديد'),
        body: AuthPageBackground(child: SafeArea(child: ListView(padding: const EdgeInsets.fromLTRB(22, 18, 22, 32), children: [
          const AuthBrandHeader(title: 'إنشاء حساب جديد', subtitle: 'أكمل بياناتك خطوة بخطوة'),
          const SizedBox(height: 24),
          AuthPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            AuthProgress(current: _step + 1, total: 7),
            const SizedBox(height: 24),
            AnimatedSwitcher(duration: const Duration(milliseconds: 260), child: _body()),
            const SizedBox(height: 24),
            Row(children: [if (_step > 0) Expanded(child: OutlinedButton(onPressed: _loading ? null : () => setState(() => _step--), style: AuthUi.secondaryButton(), child: const Text('رجوع'))), if (_step > 0) const SizedBox(width: 10), Expanded(child: ElevatedButton(onPressed: _loading ? null : _next, style: AuthUi.primaryButton(), child: _loading ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Text(_step == 6 ? 'إنشاء الحساب' : 'متابعة', style: const TextStyle(fontWeight: FontWeight.bold))))]),
          ])),
        ]))),
      );

  Widget _body() {
    switch (_step) {
      case 0: return _field('البريد الإلكتروني', _email, keyboard: TextInputType.emailAddress);
      case 1: return Column(key: const ValueKey(1), crossAxisAlignment: CrossAxisAlignment.stretch, children: [const Text('Username', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 10), TextField(controller: _username, onChanged: _usernameChanged, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white), decoration: AuthUi.fieldDecoration('username', suffix: _checking ? const Padding(padding: EdgeInsets.all(14), child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))) : null)), if (_message != null) Padding(padding: const EdgeInsets.only(top: 8), child: AuthStatusMessage(message: _message!, success: _available == true))]);
      case 2: return _field('الاسم الظاهر', _name);
      case 3: return _field('كلمة المرور', _password, obscure: _obscure, suffix: IconButton(tooltip: _obscure ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور', icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondaryColor), onPressed: () => setState(() => _obscure = !_obscure)));
      case 4: return _field('تأكيد كلمة المرور', _confirm, obscure: _obscureConfirm, suffix: IconButton(tooltip: _obscureConfirm ? 'إظهار كلمة المرور' : 'إخفاء كلمة المرور', icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility, color: AppTheme.textSecondaryColor), onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm)));
      case 5: return _choice(key: 'date', icon: Icons.cake_outlined, label: _birthDate == null ? 'اختيار تاريخ الميلاد' : 'تاريخ الميلاد: ${_birthDate!.year}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}', onTap: _date);
      case 6: return Column(key: const ValueKey(6), crossAxisAlignment: CrossAxisAlignment.stretch, children: [DropdownButtonFormField<String>(value: _country, dropdownColor: AppTheme.surfaceColor, decoration: AuthUi.fieldDecoration('الدولة'), items: countries.map((country) => DropdownMenuItem(value: country, child: Text(country))).toList(), onChanged: (value) => setState(() => _country = value)), const SizedBox(height: 14), _choice(key: 'image', icon: Icons.photo_library_outlined, label: _imagePath == null ? 'اختيار صورة البروفايل (اختياري)' : 'تغيير صورة البروفايل', onTap: _image), if (_imagePath != null) Padding(padding: const EdgeInsets.only(top: 12), child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.file(File(_imagePath!), height: 150, fit: BoxFit.cover))) ]);
      default: return const SizedBox.shrink();
    }
  }
  Widget _field(String label, TextEditingController controller, {TextInputType? keyboard, bool obscure = false, Widget? suffix}) => Column(key: ValueKey(label), crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)), const SizedBox(height: 10), TextField(controller: controller, autofocus: true, keyboardType: keyboard, obscureText: obscure, textDirection: keyboard == TextInputType.emailAddress ? TextDirection.ltr : null, style: const TextStyle(color: Colors.white), decoration: AuthUi.fieldDecoration(label, suffix: suffix))]);
  Widget _choice({required String key, required IconData icon, required String label, required VoidCallback onTap}) => OutlinedButton.icon(key: ValueKey(key), onPressed: onTap, icon: Icon(icon), label: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(label)), style: AuthUi.secondaryButton());
}
