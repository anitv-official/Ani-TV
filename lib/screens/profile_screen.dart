import 'package:flutter/material.dart';
import 'dart:io';
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
import 'sources_screen.dart';
import 'downloads_screen.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String username = '';
  String email = '';
  bool isLoggedIn = false;
  bool isDarkMode = true; // Default to dark as per design
  bool isLoading = true;
  bool _streamCellular = false;
  bool _showMatureContent = false;
  bool _notificationsEnabled = true;
  String? _avatarPath;

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
        email = appStateProvider.email;
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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _streamCellular = prefs.getBool('stream_cellular') ?? false;
      _showMatureContent = prefs.getBool('show_mature_content') ?? false;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _avatarPath = prefs.getString('profile_avatar_path');
    });
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    final path = result?.files.single.path;
    if (path == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('profile_avatar_path', path);
    if (mounted) setState(() => _avatarPath = path);
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  void _showErrorDialog(String title, String message) {
    CustomErrorDialog.show(
      context,
      title: title,
      message: message,
      onRetry: _loadUserData,
    );
  }

  Future<void> _logout() async {
    try {
      final appStateProvider = Provider.of<AppStateProvider>(context, listen: false);
      await appStateProvider.logout();

      ToastUtils.show('تم تسجيل الخروج بنجاح', backgroundColor: AppTheme.accentColor);

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LandingScreen()),
        (route) => false,
      );
    } catch (e) {
      _showErrorDialog('خطأ في تسجيل الخروج', 'تعذر تسجيل الخروج. حاول مرة أخرى.');
    }
  }

  void _showSourcesDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: const Text('مصادر التطبيق', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('مصادر المحتوى المفعّلة', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ...SourceRegistry.all.map((source) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(source.kind == 'anime' ? Icons.movie_outlined : Icons.menu_book_outlined,
                    color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('${source.name} (${source.kind == 'anime' ? 'أنمي' : 'مانجا'})',
                    style: const TextStyle(color: Colors.white))),
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
        backgroundColor: AppTheme.cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
        content: Text(message, style: TextStyle(color: Colors.grey[300])),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسنًا'))],
      ),
    );
  }

  void _showEditValueDialog({required String title, required String initial, required ValueChanged<String> onSave, bool obscure = false}) {
    final controller = TextEditingController(text: initial);
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text(title, style: const TextStyle(color: Colors.white)),
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
        backgroundColor: AppTheme.cardColor,
        title: const Text('تغيير كلمة المرور', style: TextStyle(color: Colors.white)),
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
              if (mounted) ToastUtils.show('تم تغيير كلمة المرور', backgroundColor: AppTheme.accentColor);
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
      initial: username,
      onSave: (value) async {
        if (value.length < 2) return;
        try {
          await context.read<AppStateProvider>().updateProfileName(value);
          if (mounted) setState(() => username = value);
          if (mounted) ToastUtils.show('تم تحديث الاسم', backgroundColor: AppTheme.accentColor);
        } catch (error) {
          if (mounted) _showInfoDialog('تعذر تحديث الاسم', authErrorMessage(error, registering: false));
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: isLoading
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
                child: Column(
                  children: [
                    // Header Title
                    Center(
                      child: Text(
                        'الملف الشخصي',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Neutral avatar: no profile image is shown unless Appwrite provides one.
                    GestureDetector(
                      onTap: _pickAvatar,
                      child: CircleAvatar(
                        radius: 64,
                        backgroundColor: AppTheme.surfaceColor,
                        backgroundImage: _avatarPath != null && File(_avatarPath!).existsSync() ? FileImage(File(_avatarPath!)) : null,
                        child: _avatarPath == null || !File(_avatarPath!).existsSync() ? Icon(Icons.person_outline, size: 72, color: AppTheme.textSecondaryColor) : null,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(username.isEmpty ? 'زائر' : username, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton.icon(onPressed: _pickAvatar, icon: const Icon(Icons.edit, size: 16), label: const Text('تغيير صورة الملف الشخصي')),

                    const SizedBox(height: 40),

                    if (!isLoggedIn)
                      _buildSectionContainer(
                        children: [
                          const ListTile(
                            leading: Icon(Icons.person_outline, color: Colors.white70),
                            title: Text('زائر', style: TextStyle(color: Colors.white)),
                            subtitle: Text('سجّل الدخول للوصول إلى ملفك الشخصي', style: TextStyle(color: Colors.white60)),
                          ),
                          _buildMenuItem('تسجيل الدخول', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()))),
                          _buildMenuItem('إنشاء حساب', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen()))),
                        ],
                      )
                    else
                      _buildSectionContainer(
                        children: [
                          _buildMenuItem('بيانات الحساب', trailing: email, onTap: () => _showInfoDialog('بيانات الحساب', 'اسم المستخدم: ${username.isEmpty ? 'غير متوفر' : username}\nالبريد الإلكتروني: ${email.isEmpty ? 'غير متوفر' : email}')),
                          _buildMenuItem('تعديل الاسم الظاهر', onTap: _showEditNameDialog),
                          _buildMenuItem('تغيير كلمة المرور', onTap: _showChangePasswordDialog),
                          _buildMenuItem('المصادر', onTap: _showSourcesDialog),
                        ],
                      ),

                    const SizedBox(height: 24),

                    // Preferences Title
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
                        child: Text(
                          'التفضيلات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    // Preferences Section
                    _buildSectionContainer(
                      children: [
                        _buildMenuItem('المصادر', onTap: _showSourcesDialog),
                        _buildMenuItem('التنزيلات', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()))),
                        _buildSwitchItem('إشعارات التحديث', _notificationsEnabled, (val) { setState(() => _notificationsEnabled = val); _savePreference('notifications_enabled', val); }),
                        _buildSwitchItem('استخدام بيانات الهاتف', _streamCellular, (val) { setState(() => _streamCellular = val); _savePreference('stream_cellular', val); }),
                        _buildSwitchItem('عرض محتوى البالغين (+18)', _showMatureContent, (val) { setState(() => _showMatureContent = val); _savePreference('show_mature_content', val); }),
                      ],
                    ),

                    const SizedBox(height: 40),

                    // Account action
                    Center(
                      child: ElevatedButton(
                        onPressed: isLoggedIn
                            ? _showLogoutDialog
                            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen())),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor, // merah
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 40, // lebar tombol
                            vertical: 14,   // tinggi tombol
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999), // pill shape
                          ),
                        ),
                        child: Text(
                          isLoggedIn ? 'تسجيل الخروج' : 'تسجيل الدخول',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 130),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildMenuItem(String title, {String? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[200],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            Row(
              children: [
                if (trailing != null) ...[
                  Text(
                    trailing,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.grey[600],
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchItem(String title, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[200],
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: AppTheme.primaryColor, // Red track
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Colors.grey[700],
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
        content: Text('هل أنت متأكد من تسجيل الخروج؟', style: TextStyle(color: Colors.grey[400])),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _logout();
            },
            child: Text('تسجيل الخروج', style: TextStyle(color: const Color(0xFFE53935))),
          ),
        ],
      ),
    );
  }
}
