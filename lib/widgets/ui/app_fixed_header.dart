import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../app_navigation_drawer.dart';
import 'app_search_bar.dart';
import '../../screens/search_screen.dart';

/// Header shared by every content section. It is intentionally outside the
/// section's scrollable body so the brand, search entry point, and drawer
/// remain visible while cards and lists scroll.
class AppFixedHeader extends StatelessWidget {
  final String? title;
  final bool showBack;
  final Widget? trailing;

  const AppFixedHeader({
    super.key,
    this.title,
    this.showBack = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        decoration: BoxDecoration(
          color: AppTheme.backgroundColor.withOpacity(.94),
          border: const Border(bottom: BorderSide(color: AppTheme.borderColor)),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (showBack)
                  IconButton(
                    tooltip: 'رجوع',
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.maybePop(context),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                Image.asset(
                  'assets/images/anitv_logo_transparent.png',
                  width: 112,
                  height: 40,
                  fit: BoxFit.contain,
                ),
                const Spacer(),
                if (trailing != null) trailing!,
                const AppDrawerButton(),
              ],
            ),
            const SizedBox(height: 12),
            SearchLaunchField(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen(autoFocus: true)),
              ),
            ),
            if (title != null) ...[
              const SizedBox(height: 14),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  title!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class FixedHeaderScaffold extends StatelessWidget {
  final Widget body;
  final String? title;
  final bool showBack;

  const FixedHeaderScaffold({
    super.key,
    required this.body,
    this.title,
    this.showBack = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            AppFixedHeader(title: title, showBack: showBack),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }
}
