import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';
import '../widgets/custom_error_dialog.dart';
import '../screens/home_screen.dart';
import '../providers/app_state_provider.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import 'register_screen.dart';
import '../utils/toast_utils.dart';
import '../services/api_service.dart';
import '../services/app_version_service.dart';
import 'splash_screen.dart';

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
  String _apiBaseUrl = '';
  String _appVersionUrl = '';
  
  bool _streamCellular = false;
  bool _showMatureContent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppStateProvider>(context, listen: false).initialize();
    });
    _loadUserData();
    _loadApiConfig();
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
    });
  }

  Future<void> _savePreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _loadApiConfig() async {
    setState(() {
      _apiBaseUrl = ApiService.getBaseUrl();
      _appVersionUrl = AppVersionService.getBaseUrl();
    });
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
        MaterialPageRoute(builder: (context) => LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      _showErrorDialog('خطأ في تسجيل الخروج', 'تعذر تسجيل الخروج. حاول مرة أخرى.');
    }
  }

  void _showEditApiDialog() {
    final apiController = TextEditingController(text: _apiBaseUrl);
    final appVersionController = TextEditingController(text: _appVersionUrl);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardColor,
        title: Text('تعديل روابط الخدمات', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: apiController,
              decoration: InputDecoration(
                labelText: 'رابط واجهة API الأساسي',
                labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondaryColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
              style: TextStyle(color: Colors.white),
            ),
            SizedBox(height: 12),
            TextField(
              controller: appVersionController,
              decoration: InputDecoration(
                labelText: 'رابط التحديثات',
                labelStyle: TextStyle(color: AppTheme.textSecondaryColor),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.textSecondaryColor)),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
              ),
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: TextStyle(color: AppTheme.textSecondaryColor)),
          ),
          TextButton(
            onPressed: () async {
              final apiUrl = apiController.text.trim();
              final verUrl = appVersionController.text.trim();
              if (apiUrl.isNotEmpty) await ApiService.setBaseUrl(apiUrl);
              if (verUrl.isNotEmpty) await AppVersionService.setBaseUrl(verUrl);
              setState(() {
                _apiBaseUrl = ApiService.getBaseUrl();
                _appVersionUrl = AppVersionService.getBaseUrl();
              });
              ApiService.clearCache();
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => SplashScreen()),
                (route) => false,
              );
            },
            child: Text('حفظ', style: TextStyle(color: AppTheme.primaryColor)),
          ),
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

  void _showChangePasswordDialog() => _showEditValueDialog(
    title: 'تغيير كلمة المرور', initial: '', obscure: true,
    onSave: (value) { if (value.length < 6) { _showInfoDialog('كلمة المرور قصيرة', 'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل.'); } else { _showInfoDialog('تغيير كلمة المرور', 'لا يمكن تغيير كلمة المرور من هذا الإصدار لأن المصادقة الحالية لا توفر هذه العملية.'); } },
  );

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
                    
                    // Avatar
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: SvgPicture.asset(
                        'assets/images/anime_profile.svg',
                        fit: BoxFit.contain,
                      ),
                    ),
                    
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
                          _buildMenuItem('الاشتراك', onTap: () => _showInfoDialog('الاشتراك', 'ستتوفر خطط الاشتراك قريبًا.')),
                          _buildMenuItem('تغيير البريد الإلكتروني', trailing: email, onTap: _showChangeEmailDialog),
                          _buildMenuItem('تغيير كلمة المرور', onTap: _showChangePasswordDialog),
                          _buildMenuItem('إعدادات واجهة API', onTap: _showEditApiDialog),
                        ],
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Preferences Title
                    Align(
                      alignment: Alignment.centerLeft,
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
                        _buildMenuItem('لغة الصوت', trailing: 'اليابانية', onTap: () => _showInfoDialog('لغة الصوت', 'اختيار اللغة محفوظ محليًا.')),
                        _buildMenuItem('لغة الترجمة', trailing: 'الإنجليزية', onTap: () => _showInfoDialog('لغة الترجمة', 'اختيار اللغة محفوظ محليًا.')),
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
                          backgroundColor: const Color(0xFFE53935), // merah
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
                    const SizedBox(height: 20),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionContainer({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
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
            activeTrackColor: const Color(0xFFE53935), // Red track
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
