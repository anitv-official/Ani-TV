import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../services/appwrite_service.dart';
import '../theme/app_theme.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تغيير كلمة المرور بنجاح')));
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(authErrorMessage(error, registering: false))));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.backgroundColor,
    appBar: AppBar(title: const Text('استعادة كلمة المرور'), backgroundColor: AppTheme.backgroundColor),
    body: Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(24), children: [
        const Text('أنشئ كلمة مرور جديدة', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        const SizedBox(height: 12),
        const Text('يجب أن تتكون كلمة المرور من 8 أحرف على الأقل.', style: TextStyle(color: Colors.white70), textAlign: TextAlign.center),
        const SizedBox(height: 32),
        TextFormField(controller: _password, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'), validator: (value) => value == null || value.length < 8 ? 'أدخل 8 أحرف على الأقل' : null),
        const SizedBox(height: 16),
        TextFormField(controller: _confirm, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور'), validator: (value) => value != _password.text ? 'كلمتا المرور غير متطابقتين' : null),
        const SizedBox(height: 28),
        ElevatedButton(onPressed: _loading ? null : _submit, child: _loading ? const CircularProgressIndicator() : const Text('حفظ كلمة المرور')),
      ]),
    ),
  );
}
