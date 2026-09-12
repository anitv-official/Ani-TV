import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/ui/primary_button.dart';

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
      if (mounted) ToastUtils.show(authErrorMessage(error, registering: false), backgroundColor: Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    appBar: AppBar(title: const Text('استعادة كلمة المرور')),
    body: Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('أنشئ كلمة مرور جديدة', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text('يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.', style: TextStyle(color: AppTheme.textSecondaryColor), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        TextFormField(controller: _password, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'), validator: (value) => value == null || value.length < 8 ? 'أدخل 8 أحرف على الأقل' : null),
        const SizedBox(height: 16),
        TextFormField(controller: _confirm, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'), validator: (value) => value != _password.text ? 'كلمتا المرور غير متطابقتين' : null),
        const SizedBox(height: 28),
        PrimaryButton(expanded: true, label: 'حفظ كلمة المرور', loading: _loading, onPressed: _submit),
      ]),
    ),
  );
}
