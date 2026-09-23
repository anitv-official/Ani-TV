import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/auth_ui.dart';

class PasswordResetScreen extends StatefulWidget {
  final String userId;
  final String secret;
  const PasswordResetScreen({super.key, required this.userId, required this.secret});

  @override
  State<PasswordResetScreen> createState() => _PasswordResetScreenState();
}

class _PasswordResetScreenState extends State<PasswordResetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await context.read<AppStateProvider>().completePasswordRecovery(
        userId: widget.userId,
        secret: widget.secret,
        password: _password.text,
      );
      if (!mounted) return;
      ToastUtils.show('تم تغيير كلمة المرور بنجاح', backgroundColor: Colors.green);
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ToastUtils.show(authErrorMessage(error, registering: false), backgroundColor: Color(0xFF1976D2));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    appBar: const AuthTopBar(title: 'استعادة كلمة المرور'),
    body: AuthPageBackground(child: SafeArea(child: Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.fromLTRB(22, 20, 22, 32), children: [
        const AuthBrandHeader(title: 'أنشئ كلمة مرور جديدة', subtitle: 'يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.'),
        const SizedBox(height: 24),
        AuthPanel(child: Column(children: [
          TextFormField(controller: _password, obscureText: true, style: const TextStyle(color: Colors.white), decoration: AuthUi.fieldDecoration('كلمة المرور الجديدة', suffix: const Icon(Icons.lock_outline, color: AppTheme.textSecondaryColor)), validator: (value) => value == null || value.length < 8 ? 'أدخل 8 أحرف على الأقل' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _confirm, obscureText: true, style: const TextStyle(color: Colors.white), decoration: AuthUi.fieldDecoration('تأكيد كلمة المرور', suffix: const Icon(Icons.lock_outline, color: AppTheme.textSecondaryColor)), validator: (value) => value != _password.text ? 'كلمتا المرور غير متطابقتين' : null),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _loading ? null : _submit, style: AuthUi.primaryButton(), child: _loading ? const SizedBox(width: 21, height: 21, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('حفظ كلمة المرور'))),
        ])),
      ]),
    ))),
  );
}
