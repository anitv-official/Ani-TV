import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';
import '../utils/toast_utils.dart';
import '../widgets/auth_branding.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;
  const EmailVerificationScreen({super.key, required this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _loading = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _sendLink();
  }

  Future<void> _sendLink() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await context.read<AppStateProvider>().sendEmailVerification();
      if (mounted) ToastUtils.show('تم إرسال رابط التأكيد إلى بريدك الإلكتروني.', backgroundColor: Colors.green);
    } catch (error) {
      if (mounted) ToastUtils.show(authErrorMessage(error, registering: false), backgroundColor: AppTheme.errorColor);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _checkVerification() async {
    setState(() => _loading = true);
    try {
      final provider = context.read<AppStateProvider>();
      await provider.refreshEmailVerification();
      if (!mounted) return;
      if (provider.emailVerified) {
        ToastUtils.show('تم تأكيد البريد الإلكتروني بنجاح.', backgroundColor: Colors.green);
        Navigator.of(context).pop(true);
      } else {
        ToastUtils.show('لم يتم تأكيد البريد بعد. افتح الرابط المرسل ثم حاول مرة أخرى.', backgroundColor: AppTheme.errorColor);
      }
    } catch (error) {
      if (mounted) ToastUtils.show('تعذر التحقق الآن. تأكد من اتصال الإنترنت وحاول مرة أخرى.', backgroundColor: AppTheme.errorColor);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundColor,
        title: const Text('تأكيد البريد الإلكتروني'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.of(context).maybePop()),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthBranding(),
              const Icon(Icons.mark_email_read_outlined, size: 72, color: AppTheme.primaryColor),
              const SizedBox(height: 22),
              const Text('تحقق من بريدك الإلكتروني', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text('أرسلنا رابط تأكيد إلى بريدك الإلكتروني. افتح الرابط لتأكيد ملكية البريد قبل المتابعة.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 15, height: 1.5)),
              const SizedBox(height: 12),
              Text(widget.email, textAlign: TextAlign.center, textDirection: TextDirection.ltr, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 30),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _checkVerification,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _loading ? const CircularProgressIndicator(color: Colors.white) : const Text('تحقّق من حالة البريد', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _sending ? null : _sendLink,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: AppTheme.borderColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14)),
                child: _sending ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('إعادة إرسال رابط التأكيد'),
              ),
              const SizedBox(height: 18),
              const Text('يمكنك العودة إلى تسجيل الدخول إذا أردت استخدام حساب آخر.', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textMutedColor, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
