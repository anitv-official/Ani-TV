import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../screens/downloads_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/favorites_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sources_screen.dart';
import '../theme/app_theme.dart';

class AppNavigationDrawer extends StatelessWidget {
  const AppNavigationDrawer({super.key});

  void _open(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: (width * .82).clamp(280.0, 360.0).toDouble(),
      backgroundColor: AppTheme.backgroundColor,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () => _open(context, ProfileScreen()),
              child: _ProfileHeader(state: state),
            ),
            const SizedBox(height: 14),
            const Divider(color: AppTheme.borderColor),
            _item(context, Icons.home_rounded, 'الأحدث', () => Navigator.pop(context), selected: true),
            _item(context, Icons.movie_outlined, 'لائحة الأنمي', () => _open(context, const ExploreScreen(initialIsAnime: true))),
            _item(context, Icons.menu_book_outlined, 'لائحة المانجا', () => _open(context, const ExploreScreen(initialIsAnime: false))),
            _item(context, Icons.live_tv_outlined, 'الأفلام والمسلسلات', () => _open(context, const SourcesScreen())),
            _item(context, Icons.theater_comedy_outlined, 'الدراما', () => _open(context, const SourcesScreen())),
            const SizedBox(height: 10),
            const Divider(color: AppTheme.borderColor),
            _item(context, Icons.favorite_rounded, 'المفضلات', () => _open(context, const FavoritesScreen())),
            _item(context, Icons.download_for_offline_rounded, 'التنزيلات', () => _open(context, const DownloadsScreen())),
            _item(context, Icons.hub_outlined, 'المصادر', () => _open(context, const SourcesScreen())),
            _item(context, Icons.settings_outlined, 'الإعدادات', () => _open(context, ProfileScreen())),
            _item(context, Icons.info_outline_rounded, 'حول', () => _open(context, ProfileScreen())),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool selected = false}) {
    return ListTile(
      onTap: onTap,
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      tileColor: selected ? AppTheme.primaryColor.withOpacity(.14) : null,
      leading: Icon(icon, color: selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor),
      title: Text(label, style: TextStyle(color: selected ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
      trailing: selected ? const Icon(Icons.chevron_left_rounded, color: AppTheme.primaryColor) : null,
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final AppStateProvider state;
  const _ProfileHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    final name = state.displayName.trim();
    final username = state.username.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor)),
      child: Row(children: [
        _Avatar(future: state.profileImageBytes),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name.isEmpty ? 'حساب AniTV' : name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(state.isLoggedIn ? (username.isEmpty ? 'حساب متصل' : '@$username') : 'تسجيل الدخول لإدارة الحساب', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
        ])),
        const Icon(Icons.chevron_left_rounded, color: AppTheme.textMutedColor),
      ]),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Future<Uint8List>? future;
  const _Avatar({required this.future});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(radius: 28, backgroundColor: AppTheme.primaryColor.withOpacity(.18), child: const Icon(Icons.person_outline_rounded, color: AppTheme.primaryColor, size: 28));
    if (future == null) return fallback;
    return FutureBuilder<Uint8List>(future: future, builder: (_, snapshot) => snapshot.hasData ? CircleAvatar(radius: 28, backgroundImage: MemoryImage(snapshot.data!)) : fallback);
  }
}

class AppDrawerButton extends StatelessWidget {
  const AppDrawerButton({super.key});
  @override
  Widget build(BuildContext context) => Builder(builder: (context) => IconButton(tooltip: 'القائمة', icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(context).openDrawer()));
}

class AppDrawerScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  const AppDrawerScaffold({super.key, required this.body, this.bottomNavigationBar});
  @override
  Widget build(BuildContext context) => Scaffold(drawer: const AppNavigationDrawer(), backgroundColor: AppTheme.backgroundColor, body: body, bottomNavigationBar: bottomNavigationBar);
}
