import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';
import 'app_section.dart';

class AppNavigationDrawer extends StatelessWidget {
  final ValueChanged<AppSection>? onSectionSelected;
  final AppSection currentSection;

  const AppNavigationDrawer({super.key, this.onSectionSelected, this.currentSection = AppSection.latest});

  void _select(BuildContext context, AppSection section) {
    Navigator.pop(context);
    onSectionSelected?.call(section);
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();
    final width = MediaQuery.sizeOf(context).width;
    return Drawer(
      width: (width * .82).clamp(280.0, 360.0).toDouble(),
      backgroundColor: AppTheme.backgroundColor,
      surfaceTintColor: Colors.transparent,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => _select(context, AppSection.account),
              child: _ProfileHeader(state: state),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, bottom: 8),
              child: Text('اكتشف', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.primaryColor, letterSpacing: .8)),
            ),
            _item(context, Icons.home_rounded, 'الأحدث', () => _select(context, AppSection.latest), selected: currentSection == AppSection.latest),
            _item(context, Icons.movie_outlined, 'لائحة الأنمي', () => _select(context, AppSection.anime), selected: currentSection == AppSection.anime),
            _item(context, Icons.menu_book_outlined, 'لائحة المانجا', () => _select(context, AppSection.manga), selected: currentSection == AppSection.manga),
            _item(context, Icons.live_tv_rounded, 'لائحة الدراما', () => _select(context, AppSection.drama), selected: currentSection == AppSection.drama),
            _item(context, Icons.auto_stories_rounded, 'لائحة الروايات', () => _select(context, AppSection.novels), selected: currentSection == AppSection.novels),
            _item(context, Icons.forum_outlined, 'المجتمع', () => _select(context, AppSection.community), selected: currentSection == AppSection.community),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12, bottom: 8),
              child: Text('مكتبتك', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppTheme.primaryColor, letterSpacing: .8)),
            ),
            _item(context, Icons.favorite_rounded, 'المفضلات', () => _select(context, AppSection.favorites), selected: currentSection == AppSection.favorites),
            _item(context, Icons.download_for_offline_rounded, 'التنزيلات', () => _select(context, AppSection.downloads), selected: currentSection == AppSection.downloads),
            _item(context, Icons.settings_outlined, 'الإعدادات', () => _select(context, AppSection.settings), selected: currentSection == AppSection.settings),
            _item(context, Icons.info_outline_rounded, 'حول AniTV', () => _select(context, AppSection.about), selected: currentSection == AppSection.about),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool selected = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ListTile(
        onTap: onTap,
        minVerticalPadding: 10,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        tileColor: selected ? AppTheme.primaryColor.withOpacity(.14) : null,
        leading: Icon(icon, color: selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor),
        title: Text(label, style: TextStyle(color: selected ? AppTheme.textPrimaryColor : AppTheme.textSecondaryColor, fontWeight: selected ? FontWeight.w800 : FontWeight.w600)),
        trailing: selected ? const Icon(Icons.chevron_left_rounded, color: AppTheme.primaryColor) : null,
      ),
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
      decoration: BoxDecoration(
        gradient: AppTheme.glassGradient,
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.primaryColor.withOpacity(.18)),
        boxShadow: AppTheme.subtleShadow,
      ),
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
  Widget build(BuildContext context) => Builder(builder: (context) => IconButton(tooltip: 'القائمة', icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(context).openEndDrawer()));
}

class AppDrawerScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  const AppDrawerScaffold({super.key, required this.body, this.bottomNavigationBar});
  @override
  Widget build(BuildContext context) => Scaffold(endDrawer: const AppNavigationDrawer(), backgroundColor: AppTheme.backgroundColor, body: body, bottomNavigationBar: bottomNavigationBar);
}
