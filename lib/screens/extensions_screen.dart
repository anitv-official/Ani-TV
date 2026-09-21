import 'package:flutter/material.dart';
import '../extensions/extension_base.dart';
import '../extensions/extension_catalog.dart';
import '../theme/app_theme.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/state_views.dart';
import 'sources_screen.dart';

class ExtensionsScreen extends StatelessWidget {
  final bool embedded;
  const ExtensionsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final extensions = ExtensionCatalog.all;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: embedded ? null : const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            if (!embedded) const AppFixedHeader(title: 'الإضافات'),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: extensions.length,
                separatorBuilder: (_, __) => const SizedBox(height: 14),
                itemBuilder: (context, index) => _ExtensionCard(extension: extensions[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExtensionCard extends StatelessWidget {
  final AniExtension extension;
  const _ExtensionCard({required this.extension});

  @override
  Widget build(BuildContext context) {
    final enabled = extension.status.isAvailable;
    return InkWell(
      onTap: enabled
          ? () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => sourceContentPage(extension)),
              )
          : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: enabled ? AppTheme.borderColor : Colors.orange.withOpacity(.25)),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Row(
          children: [
            _ExtensionIcon(extension: extension),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(extension.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text(extension.contentLabel, style: TextStyle(color: AppTheme.textSecondaryColor)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(extension.status == ExtensionStatus.available ? Icons.check_circle : Icons.info_outline, size: 16, color: extension.status == ExtensionStatus.available ? Colors.greenAccent : Colors.orangeAccent),
                      const SizedBox(width: 5),
                      Text(extension.status.label, style: TextStyle(color: extension.status == ExtensionStatus.available ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(extension.statusMessage, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: AppTheme.textMutedColor, fontSize: 11)),
                ],
              ),
            ),
            Icon(enabled ? Icons.chevron_left_rounded : Icons.lock_outline_rounded, color: enabled ? AppTheme.primaryColor : AppTheme.textMutedColor),
          ],
        ),
      ),
    );
  }
}

class _ExtensionIcon extends StatelessWidget {
  final AniExtension extension;
  const _ExtensionIcon({required this.extension});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 58,
        height: 58,
        color: AppTheme.primaryColor.withOpacity(.12),
        child: Image.network(
          extension.iconUrl,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(extension.id == 'youtube' ? Icons.ondemand_video_rounded : Icons.extension_rounded, color: AppTheme.primaryColor, size: 30),
        ),
      ),
    );
  }
}

class ExtensionsEmptyView extends StatelessWidget {
  const ExtensionsEmptyView({super.key});
  @override
  Widget build(BuildContext context) => const EmptyState(icon: Icons.extension_off_outlined, title: 'لا توجد إضافات متاحة');
}
