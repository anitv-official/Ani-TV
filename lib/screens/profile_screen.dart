import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appwrite/appwrite.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../providers/app_state_provider.dart';
import 'landing_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../utils/toast_utils.dart';
import '../sources/source_registry.dart';
import '../services/appwrite_service.dart';
import '../services/fcm_service.dart';
import '../services/app_version_service.dart';
import '../services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'sources_screen.dart';
import 'downloads_screen.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/ui/primary_button.dart';
import '../widgets/ui/setting_tile.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/auth_required_view.dart';

class ProfileScreen extends StatefulWidget {
  final bool embedded;
  final bool settingsOnly;

  const ProfileScreen({super.key, this.embedded = false, this.settingsOnly = false});

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String username = '';
  String displayName = '';
  String email = '';
  String birthDate = '';
  String country = '';
  bool isLoggedIn = false;
  bool isDarkMode = true;
  bool isLoading = true;
  bool _streamCellular = false;
  bool _showMatureContent = false;
  bool _notificationsEnabled = true;
  String? _avatarPath;
  bool _isDeletingAccount = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    _loadUserData();
    _loadPreferences();
  }

  Future<void> _loadUserData() async {
    setState(() => isLoading = true);
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.initialize();
      setState(() {
        username = appStateProvider.username;
        displayName = appStateProvider.displayName;
        email = appStateProvider.email;
        birthDate = appStateProvider.birthDate;
        country = appStateProvider.country;
        isLoggedIn = appStateProvider.isLoggedIn;
        isDarkMode = appStateProvider.isDarkMode;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      _showErrorDialog('خطأ في تحميل الملف الشخصي', 'تعذر تحميل بيانات المستخدم. حاول مرة أخرى.');
    }
  }

  Future<void> _loadPreferences() async {
    final provider = context.read<AppStateProvider>();
    await provider.initialize();
    final userId = provider.userId;
    final prefs = await SharedPreferences.getInstance();
    final scope = userId == null ? 'guest' : 'user_$userId';
    if (!mounted) return;
    setState(() {
      _streamCellular = prefs.getBool('stream_cellular_$scope') ?? false;
      _showMatureContent = prefs.getBool('show_mature_content_$scope') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled_$scope') ?? true;
      _avatarPath = prefs.getString(userId == null ? 'profile_avatar_path' : 'profile_avatar_path_$userId');
    });
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;
    final userId = context.read<AppStateProvider>().userId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userId == null ? 'profile_avatar_path' : 'profile_avatar_path_$userId', path);
    if (mounted) setState(() => _avatarPath = path);
    final provider = context.read<AppStateProvider>();
    if (provider.isLoggedIn) {
      try {
        await provider.updateProfileImage(path);
        if (mounted) setState(() {});
      } catch (_) {
        if (mounted) _showInfoDialog('تعذر تحديث صورة الملف الشخصي', 'تم الاحتفاظ بالصورة على الجهاز، وسنحاول مزامنتها لاحقًا.');
      }
    }
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = context.read<AppStateProvider>().userId;
    final scope = userId == null ? 'guest' : 'user_$userId';
    await prefs.setBool('${key}_$scope', value);
  }

  Future<void> _confirmLocalAction(String title, String message, Future<void> Function() action) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('متابعة')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await action();
      if (mounted) ToastUtils.show('تم تنفيذ العملية', backgroundColor: AppTheme.accentColor);
    }
  }

  Future<void> _clearLocalHistory() => _confirmLocalAction('مسح سجل المشاهدة', 'سيتم حذف سجل المشاهدة المحلي فقط، ولن تتأثر المفضلة أو بيانات الحساب.', () async {
    final provider = context.read<AppStateProvider>();
    await provider.clearHistory(true);
    await provider.clearHistory(false);
  });

  Future<void> _clearLocalCache() => _confirmLocalAction('مسح الكاش', 'سيتم مسح البيانات المؤقتة وإعادة تحميلها عند الحاجة.', () async {
    ApiService.clearCache();
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith('cache_'))) {
      await prefs.remove(key);
    }
  });

  Future<void> _resetPreferences() => _confirmLocalAction('إعادة ضبط الإعدادات', 'سيتم إعادة التفضيلات المحلية فقط. لن يتم حذف الحساب أو المفضلة أو التنزيلات.', () async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().where((key) => key.startsWith('stream_cellular_') || key.startsWith('show_mature_content_') || key.startsWith('notifications_enabled_') || key.startsWith('dark_mode_'))) {
      await prefs.remove(key);
    }
    if (mounted) setState(() { _streamCellular = false; _showMatureContent = false; _notificationsEnabled = true; isDarkMode = true; });
  });

  Future<void> _showDiagnostics() async {
    final checks = <String, String>{};
    try {
      final result = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 4));
      checks['الإنترنت'] = result.isNotEmpty ? '✓ يعمل' : '⚠ يحتاج إلى انتباه';
    } catch (_) { checks['الإنترنت'] = '✕ خطأ'; }
    try {
      final provider = context.read<AppStateProvider>();
      await provider.initialize();
      checks['الجلسة'] = provider.isLoggedIn ? '✓ يعمل' : '⚠ زائر';
      checks['المفضلة'] = provider.isLoggedIn ? '✓ ${provider.favoriteAnime.length + provider.favoriteComics.length} عنصر' : '⚠ غير متاح للزائر';
    } catch (_) { checks['Appwrite'] = '✕ خطأ'; }
    try {
      checks['المصادر'] = SourceRegistry.all.isNotEmpty ? '✓ ${SourceRegistry.all.length} مصدر' : '✕ لا توجد مصادر';
      final prefs = await SharedPreferences.getInstance();
      checks['التخزين المحلي'] = '✓ ${prefs.getKeys().length} مفتاح';
      checks['الإشعارات'] = _notificationsEnabled ? '✓ مفعّلة' : '⚠ معطّلة';
    } catch (_) { checks['التخزين المحلي'] = '✕ خطأ'; }
    if (!mounted) return;
    final report = checks.entries.map((entry) => '${entry.key}: ${entry.value}').join('\n');
    showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('مركز تشخيص AniTV'),
      content: SelectableText(report),
      actions: [
        TextButton(onPressed: () { Clipboard.setData(ClipboardData(text: report)); ToastUtils.show('تم نسخ التقرير', backgroundColor: AppTheme.accentColor); }, child: const Text('نسخ التقرير')),
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إغلاق')),
      ],
    ));
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(context, title: title, message: message, onRetry: _loadUserData);
  }

  Future<void> _logout() async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.logout();
      ToastUtils.show('تم تسجيل الخروج بنجاح', backgroundColor: AppTheme.primaryColor);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LandingScreen()),
        (route) => false,
      );
    } catch (e) {
      _showErrorDialog('خطأ في تسجيل الخروج', 'تعذر تسجيل الخروج. حاول مرة أخرى.');
    }
  }

  Future<void> _deleteAccountFlow() async {
    var readWarning = false;
    var acceptTerms = false;
    final proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('حذف الحساب نهائيًا'),
          content: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('تحذير: حذف الحساب عملية نهائية ولا يمكن التراجع عنها.'),
            const SizedBox(height: 10),
            const Text('بعد حذف حسابك لن تتمكن من الوصول إليه مرة أخرى، وسيتم حذف بيانات الحساب التي يديرها التطبيق من الخدمة السحابية.'),
            const SizedBox(height: 12),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: readWarning, onChanged: (v) => setDialogState(() => readWarning = v ?? false), title: const Text('أقر أنني قرأت التحذير'), controlAffinity: ListTileControlAffinity.leading),
            CheckboxListTile(contentPadding: EdgeInsets.zero, value: acceptTerms, onChanged: (v) => setDialogState(() => acceptTerms = v ?? false), title: const Text('أوافق على جميع الشروط المتعلقة بحذف الحساب'), controlAffinity: ListTileControlAffinity.leading),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
            ElevatedButton(onPressed: readWarning && acceptTerms ? () => Navigator.pop(dialogContext, true) : null, child: const Text('المتابعة')),
          ],
        ),
      ),
    );
    if (proceed != true || !mounted) return;
    final password = await _showPasswordConfirmation();
    if (password == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('هل تريد حذف حسابك نهائيًا؟'),
        content: const Text('سيتم حذف حسابك والبيانات المرتبطة به التي يديرها AniTV. هذه العملية لا يمكن التراجع عنها.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('حذف الحساب نهائيًا', style: TextStyle(color: AppTheme.primaryColor))),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeletingAccount = true);
    try {
      await context.read<AppStateProvider>().deleteAccount(password: password);
      if (!mounted) return;
      ToastUtils.show('تم حذف الحساب نهائيًا', backgroundColor: AppTheme.primaryColor);
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LandingScreen()), (route) => false);
    } catch (error) {
      if (mounted) _showInfoDialog('تعذر حذف الحساب', _accountDeletionMessage(error));
    } finally {
      if (mounted) setState(() => _isDeletingAccount = false);
    }
  }

  Future<String?> _showPasswordConfirmation() async {
    final password = TextEditingController();
    final confirmation = TextEditingController();
    String? error;
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          title: const Text('تأكيد كلمة المرور'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: password, obscureText: true, autofocus: true, decoration: const InputDecoration(labelText: 'كلمة المرور')),
            TextField(controller: confirmation, obscureText: true, decoration: const InputDecoration(labelText: 'تأكيد كلمة المرور')),
            if (error != null) Padding(padding: const EdgeInsets.only(top: 10), child: Text(error!, style: const TextStyle(color: AppTheme.primaryColor))),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('إلغاء')),
            ElevatedButton(onPressed: () {
              if (password.text.isEmpty || confirmation.text.isEmpty) {
                setDialogState(() => error = 'يرجى إدخال كلمة المرور وتأكيدها.');
              } else if (password.text != confirmation.text) {
                setDialogState(() => error = 'كلمتا المرور غير متطابقتين.');
              } else {
                Navigator.pop(dialogContext, password.text);
              }
            }, child: const Text('متابعة')),
          ],
        ),
      ),
    );
  }

  String _accountDeletionMessage(Object error) {
    if (error is AccountDeletionException && error.code == 'NO_EMAIL') return 'هذا الحساب لا يملك كلمة مرور محلية. لا يمكن تنفيذ الحذف بأمان من هذا الإصدار.';
    if (error is AccountDeletionException && (error.code == 'INVALID_CREDENTIALS' || error.code == 'AUTHENTICATION_REQUIRED')) return 'تعذر التحقق من كلمة المرور أو هوية الحساب.';
    if (error is AppwriteException && error.code == 401) return 'تعذر التحقق من كلمة المرور.';
    return 'تعذر حذف الحساب حاليًا. تحقق من اتصال الإنترنت وحاول مرة أخرى.';
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://anitv-manga-lord.vercel.app/privacy');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      _showErrorDialog('الخصوصية والأمان', 'تعذر فتح سياسة الخصوصية. حاول مرة أخرى.');
    }
  }

  Future<void> _showAboutDialog() async {
    final version = await AppVersionService.getCurrentVersion();
    final buildNumber = await AppVersionService.getBuildNumber();
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حول AniTV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('AniTV', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('الإصدار الحالي: $version', style: const TextStyle(color: AppTheme.textSecondaryColor)),
            Text('Version Code: $buildNumber', style: const TextStyle(color: AppTheme.textSecondaryColor)),
            const Text('توافق Android: 5.0 وما بعده', style: TextStyle(color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 18),
            const Text('الخصوصية والأمان', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined, color: AppTheme.primaryColor),
              title: const Text('سياسة الخصوصية', style: TextStyle(color: Colors.white)),
              subtitle: const Text('عرض السياسة الرسمية', style: TextStyle(color: AppTheme.textSecondaryColor)),
              onTap: _openPrivacyPolicy,
            ),
            const Text('الأمان: لا يحتوي التطبيق على مفاتيح API خاصة أو أسرار OAuth.', style: TextStyle(color: AppTheme.textMutedColor, fontSize: 12)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق'))],
      ),
    );
  }

  void _showSourcesDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مصادر التطبيق'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('مصادر المحتوى المفعّلة', style: TextStyle(color: AppTheme.textSecondaryColor, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...SourceRegistry.all.map((source) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(source.kind == 'anime' ? Icons.movie_outlined : Icons.menu_book_outlined, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${source.name} (${source.kind == 'anime' ? 'أنمي' : 'مانجا'})', style: const TextStyle(color: Colors.white))),
              ]),
            )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesScreen()));
            },
            child: const Text('تصفح المصادر'),
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا')),
        ],
      ),
    );
  }

  void _showInfoDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
      ),
    );
  }

  void _showEditValueDialog({required String title, required String initial, required ValueChanged<String> onSave, bool obscure = false}) {
    final controller = TextEditingController(text: initial);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, obscureText: obscure, autofocus: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'القيمة الجديدة')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () { onSave(controller.text.trim()); Navigator.pop(context); }, child: const Text('حفظ')),
        ],
      ),
    );
  }

  void _showChangeEmailDialog() {
    _showInfoDialog(
      'تغيير البريد الإلكتروني',
      'لا يمكن تغيير البريد الإلكتروني من هذا الإصدار لأن العملية تحتاج إلى إعادة التحقق من كلمة المرور عبر خدمة الحساب.',
    );
  }

  void _showChangePasswordDialog() {
    final oldController = TextEditingController();
    final newController = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: oldController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'كلمة المرور الحالية')),
          TextField(controller: newController, obscureText: true, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(onPressed: () async {
            if (newController.text.length < 8) return;
            try {
              await context.read<AppStateProvider>().updatePassword(password: newController.text, oldPassword: oldController.text);
              if (mounted) Navigator.pop(context);
              if (mounted) ToastUtils.show('تم تغيير كلمة المرور', backgroundColor: AppTheme.primaryColor);
            } catch (error) {
              if (mounted) _showInfoDialog('تعذر تغيير كلمة المرور', authErrorMessage(error, registering: false));
            }
          }, child: const Text('حفظ')),
        ],
      ),
    );
  }

  void _showEditNameDialog() {
    _showEditValueDialog(
      title: 'تعديل الاسم الظاهر',
      initial: displayName,
      onSave: (value) async {
        if (value.length < 2) return;
        try {
          await context.read<AppStateProvider>().updateProfileName(value);
          if (mounted) setState(() => displayName = value);
          if (mounted) ToastUtils.show('تم تحديث الاسم', backgroundColor: AppTheme.primaryColor);
        } catch (error) {
          if (mounted) _showInfoDialog('تعذر تحديث الاسم', authErrorMessage(error, registering: false));
        }
      },
    );
  }

  void _showEditUsernameDialog() {
    _showEditValueDialog(
      title: 'تغيير Username',
      initial: username,
      onSave: (value) async {
        final normalized = value.replaceFirst('@', '').trim().toLowerCase();
        if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalized)) {
          _showInfoDialog('Username غير صالح', 'استخدم من 3 إلى 24 حرفًا إنجليزيًا صغيرًا أو رقمًا أو _ فقط.');
          return;
        }
        try {
          await context.read<AppStateProvider>().updateUsername(normalized);
          if (mounted) setState(() => username = normalized);
          if (mounted) ToastUtils.show('تم تحديث Username', backgroundColor: AppTheme.primaryColor);
        } catch (error) {
          if (mounted) _showInfoDialog('تعذر تحديث Username', error.toString().replaceFirst('Exception: ', ''));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoading && !isLoggedIn && !widget.settingsOnly) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundColor,
      endDrawer: widget.embedded ? null : const AppNavigationDrawer(),
        body: SafeArea(
          child: Column(
            children: [
              if (!widget.embedded) const AppFixedHeader(title: 'الحساب'),
              Expanded(child: AuthRequiredView(title: 'أنشئ حسابك للوصول إلى الملف الشخصي', message: 'تسجيل الدخول مطلوب للبريد الإلكتروني والملف الشخصي والإعدادات المرتبطة بالحساب.')),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: isLoading
            ? const LoadingView(message: 'جارٍ تحميل الحساب...', size: 64)
            : Column(
                children: [
                  if (!widget.embedded) AppFixedHeader(title: widget.settingsOnly ? 'الإعدادات' : 'الحساب'),
                  Expanded(child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                    children: [
                  if (widget.embedded) _embeddedTitle(),
                  if (!widget.settingsOnly) _buildProfileCard(),
                  const SizedBox(height: 12),
                  if (!widget.settingsOnly) SettingsGroup(
                    title: 'الحساب',
                    children: isLoggedIn
                        ? [
                            SettingTile(icon: Icons.person_outline, title: 'بيانات الحساب', subtitle: email.isEmpty ? 'غير متوفر' : email, onTap: () => _showInfoDialog('بيانات الحساب', 'Username: ${username.isEmpty ? 'غير متوفر' : username}\nالاسم الظاهر: ${displayName.isEmpty ? 'غير متوفر' : displayName}\nالبريد الإلكتروني: ${email.isEmpty ? 'غير متوفر' : email}\nتاريخ الميلاد: ${birthDate.isEmpty ? 'غير متوفر' : birthDate}\nالدولة: ${country.isEmpty ? 'غير متوفر' : country}\n\nتاريخ الميلاد والدولة ثابتان بعد إنشاء الحساب ولا يمكن تعديلهما.')),
                            SettingTile(icon: Icons.edit_outlined, title: 'تعديل الاسم الظاهر', subtitle: displayName.isEmpty ? 'غير متوفر' : displayName, onTap: _showEditNameDialog),
                            SettingTile(icon: Icons.alternate_email, title: 'تغيير Username', subtitle: username.isEmpty ? 'غير متوفر' : '@$username', onTap: _showEditUsernameDialog),
                            SettingTile(icon: Icons.lock_outline, title: 'تغيير كلمة المرور', onTap: _showChangePasswordDialog),
                            SettingTile(icon: Icons.email_outlined, title: 'تغيير البريد الإلكتروني', onTap: _showChangeEmailDialog),
                            SettingTile(icon: Icons.delete_forever_outlined, title: 'حذف الحساب', subtitle: 'حذف نهائي لا يمكن التراجع عنه', onTap: _isDeletingAccount ? null : _deleteAccountFlow),
                          ]
                        : [
                            SettingTile(icon: Icons.login_rounded, title: 'تسجيل الدخول', subtitle: 'للوصول إلى ملفك الشخصي', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()))),
                            SettingTile(icon: Icons.person_add_alt_1_outlined, title: 'إنشاء حساب', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen()))),
                          ],
                  ),
                  if (widget.settingsOnly) const SizedBox(height: 8),
                  if (widget.settingsOnly) SettingsGroup(
                    title: 'المظهر واللغة',
                    children: [
                      SettingSwitchTile(
                        icon: Icons.dark_mode_outlined,
                        title: 'الوضع الداكن',
                        subtitle: 'واجهة داكنة مع لمسة حمراء',
                        value: isDarkMode,
                        onChanged: (val) async {
                          setState(() => isDarkMode = val);
                          await context.read<AppStateProvider>().updateUserData(isDarkMode: val);
                        },
                      ),
                      const SettingTile(icon: Icons.language, title: 'اللغة', value: 'العربية'),
                    ],
                  ),
                  if (widget.settingsOnly) const SizedBox(height: 18),
                  if (widget.settingsOnly) SettingsGroup(
                    title: 'الإشعارات',
                    children: [
                      SettingSwitchTile(icon: Icons.notifications_outlined, title: 'إشعارات التحديث', value: _notificationsEnabled, onChanged: (val) async { setState(() => _notificationsEnabled = val); await _savePreference('notifications_enabled', val); await FcmService.instance.setNotificationsEnabled(val); }),
                    ],
                  ),
                  if (widget.settingsOnly) const SizedBox(height: 18),
                  if (widget.settingsOnly) SettingsGroup(
                    title: 'التخزين والتشغيل',
                    children: [
                      SettingSwitchTile(icon: Icons.signal_cellular_alt, title: 'استخدام بيانات الهاتف', subtitle: 'السماح بالتشغيل عبر الشبكة الخلوية', value: _streamCellular, onChanged: (val) { setState(() => _streamCellular = val); _savePreference('stream_cellular', val); }),
                      SettingSwitchTile(icon: Icons.visibility_outlined, title: 'عرض محتوى البالغين', subtitle: 'محتوى +18', value: _showMatureContent, onChanged: (val) { setState(() => _showMatureContent = val); _savePreference('show_mature_content', val); }),
                    ],
                  ),
                  if (widget.settingsOnly) const SizedBox(height: 18),
                  if (widget.settingsOnly) SettingsGroup(
                    title: 'البيانات المحلية',
                    children: [
                      SettingTile(icon: Icons.cleaning_services_outlined, title: 'مسح الكاش', subtitle: 'حذف البيانات المؤقتة فقط', onTap: _clearLocalCache),
                      SettingTile(icon: Icons.history_rounded, title: 'مسح سجل المشاهدة', subtitle: 'لا يؤثر على المفضلة أو الحساب', onTap: _clearLocalHistory),
                      SettingTile(icon: Icons.download_outlined, title: 'التنزيلات', subtitle: 'فتح صفحة التنزيلات الحالية', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()))),
                      SettingTile(icon: Icons.hub_outlined, title: 'إدارة المصادر', subtitle: 'عرض المصادر المفعّلة حاليًا', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SourcesScreen()))),
                    ],
                  ),
                  if (widget.settingsOnly) const SizedBox(height: 18),
                  if (widget.settingsOnly) SettingsGroup(
                    title: 'الأدوات',
                    children: [
                      SettingTile(icon: Icons.health_and_safety_outlined, title: 'مركز تشخيص AniTV', subtitle: 'فحص الاتصال والجلسة والمصادر والتخزين', onTap: _showDiagnostics),
                      SettingTile(icon: Icons.restore_rounded, title: 'إعادة ضبط الإعدادات', subtitle: 'إعادة التفضيلات المحلية فقط', onTap: _resetPreferences),
                    ],
                  ),
                  const SizedBox(height: 28),
                  if (!widget.settingsOnly) PrimaryButton(
                    expanded: true,
                    label: isLoggedIn ? 'تسجيل الخروج' : 'تسجيل الدخول',
                    onPressed: isLoggedIn ? _showLogoutDialog : () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())),
                  ),
                  const SizedBox(height: 24),
                    ],
                  )),
                ],
              ),
      ),
    );
  }

  Widget _embeddedTitle() => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Icon(widget.settingsOnly ? Icons.tune_rounded : Icons.person_outline_rounded, color: AppTheme.primaryColor, size: 24),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.settingsOnly ? 'إعدادات التطبيق' : 'إدارة الحساب', style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
              ],
            ),
          ],
        ),
      );

  Widget _buildProfileCard() {
    final hasAvatar = _avatarPath != null && File(_avatarPath!).existsSync();
    final cloudAvatarBytes = context.watch<AppStateProvider>().profileImageBytes;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _pickAvatar,
            child: CircleAvatar(
              radius: 34,
              backgroundColor: AppTheme.elevatedColor,
              backgroundImage: hasAvatar ? FileImage(File(_avatarPath!)) : null,
              child: hasAvatar
                  ? null
                  : (cloudAvatarBytes == null
                      ? const Icon(Icons.person_outline, size: 34, color: AppTheme.textSecondaryColor)
                      : FutureBuilder<Uint8List>(
                          future: cloudAvatarBytes,
                          builder: (context, snapshot) => snapshot.hasData
                              ? ClipOval(child: Image.memory(snapshot.data!, width: 68, height: 68, fit: BoxFit.cover))
                              : const Icon(Icons.person_outline, size: 34, color: AppTheme.textSecondaryColor),
                        )),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(displayName.isEmpty ? (username.isEmpty ? 'زائر' : username) : displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                if (isLoggedIn && username.isNotEmpty)
                  Text('@$username', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.w700)),
                Text(
                  isLoggedIn ? (email.isEmpty ? 'حساب متصل' : email) : 'سجّل الدخول لإدارة حسابك',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12),
                ),
                if (isLoggedIn && (birthDate.isNotEmpty || country.isNotEmpty))
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'تاريخ الميلاد: ${birthDate.isEmpty ? 'غير متوفر' : birthDate} · الدولة: ${country.isEmpty ? 'غير متوفر' : country}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11),
                    ),
                  ),
                TextButton(
                  onPressed: _pickAvatar,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 32)),
                  child: const Text('تغيير الصورة'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: const Text('تسجيل الخروج', style: TextStyle(color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }
}
