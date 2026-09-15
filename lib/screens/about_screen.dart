import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_version_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/ui/app_fixed_header.dart';

class AboutScreen extends StatefulWidget {
  final bool embedded;
  const AboutScreen({super.key, this.embedded = false});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '—';
  String _build = '—';
  bool _checkingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final version = await AppVersionService.getCurrentVersion();
    final build = await AppVersionService.getBuildNumber();
    if (!mounted) return;
    setState(() {
      _version = version;
      _build = build;
    });
  }

  Future<void> _open(String url, String errorMessage) async {
    final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
    }
  }

  Future<void> _checkForUpdate() async {
    if (_checkingUpdate) return;
    setState(() => _checkingUpdate = true);
    try {
      final available = await AppVersionService.isUpdateAvailable();
      if (!mounted) return;
      if (available) {
        final opened = await AppVersionService.openDownloadUrl();
        if (mounted && !opened) _showMessage('يتوفر تحديث جديد، لكن تعذر فتح رابط التنزيل.');
      } else {
        _showMessage('أنت تستخدم أحدث إصدار.');
      }
    } catch (_) {
      if (mounted) _showMessage('تعذر التحقق من التحديث. تحقق من اتصال الإنترنت.');
    } finally {
      if (mounted) setState(() => _checkingUpdate = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: widget.embedded ? null : const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            if (!widget.embedded) const AppFixedHeader(title: 'حول AniTV'),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.surfaceColor, AppTheme.primaryColor.withOpacity(.12)]),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(children: [
                      Image.asset('assets/images/anitv_logo_transparent.png', width: 150, height: 72, fit: BoxFit.contain),
                      const SizedBox(height: 10),
                      const Text('AniTV', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 5),
                      const Text('مشاهدة الأنمي والدراما وقراءة المانجا', textAlign: TextAlign.center, style: TextStyle(color: AppTheme.textSecondaryColor)),
                    ]),
                  ),
                  const SizedBox(height: 18),
                  _infoCard(Icons.info_outline, 'إصدار التطبيق', '$_version  •  Build $_build'),
                  const SizedBox(height: 12),
                  _actionCard(Icons.system_update_alt_rounded, 'التحقق من وجود تحديث', _checkingUpdate ? 'جارٍ التحقق...' : 'استخدام نظام التحديث الحالي', _checkingUpdate ? null : _checkForUpdate),
                  const SizedBox(height: 12),
                  _actionCard(Icons.privacy_tip_outlined, 'سياسة الخصوصية', 'اطّلع على سياسة الخصوصية الرسمية', () => _open('https://anitv-tau.vercel.app/privacy', 'تعذر فتح سياسة الخصوصية.')),
                  const SizedBox(height: 12),
                  _actionCard(Icons.security_outlined, 'الخصوصية والأمان', 'لا يحتوي التطبيق على مفاتيح سرية أو بيانات اعتماد إدارية', null),
                  const SizedBox(height: 12),
                  _actionCard(Icons.public_rounded, 'الموقع الرسمي', 'زيارة موقع AniTV الرسمي', () => _open('https://anitv-tau.vercel.app', 'تعذر فتح الموقع الرسمي.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String title, String value) => _baseCard(icon, title, value, null);

  Widget _actionCard(IconData icon, String title, String subtitle, VoidCallback? onTap) => _baseCard(icon, title, subtitle, onTap);

  Widget _baseCard(IconData icon, String title, String subtitle, VoidCallback? onTap) => Card(
        color: AppTheme.surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17), side: const BorderSide(color: AppTheme.borderColor)),
        child: ListTile(
          onTap: onTap,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          leading: Icon(icon, color: AppTheme.primaryColor, size: 27),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
          subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.35))),
          trailing: onTap == null ? null : const Icon(Icons.open_in_new_rounded, color: AppTheme.textMutedColor, size: 19),
        ),
      );
}
