import 'package:flutter/material.dart';
import '../sources/source_base.dart';
import '../sources/source_presentation.dart';
import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import '../widgets/app_navigation_drawer.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/ui/state_views.dart';
import '../widgets/ui/source_icon.dart';
import 'sources_screen.dart';

class ExtensionsScreen extends StatelessWidget {
  final bool embedded;
  const ExtensionsScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final sources = SourceRegistry.extensionSources;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: embedded ? null : const AppNavigationDrawer(),
      body: SafeArea(
        child: Column(children: [
          if (!embedded) const AppFixedHeader(title: 'الإضافات'),
          Expanded(
            child: sources.isEmpty
                ? const ExtensionsEmptyView()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    itemCount: sources.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (_, index) => _SourceExtensionCard(source: sources[index]),
                  ),
          ),
        ]),
      ),
    );
  }
}

class _SourceExtensionCard extends StatelessWidget {
  final ContentSource source;
  const _SourceExtensionCard({required this.source});

  @override
  Widget build(BuildContext context) {
    final availability = SourcePresentation.availability(source.id);
    final enabled = availability.isEnabled;
    final accent = availability == SourceAvailability.available ? Colors.greenAccent : Colors.orangeAccent;
    return InkWell(
      onTap: enabled ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => sourceContentPage(source))) : null,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: enabled ? AppTheme.borderColor : Colors.redAccent.withOpacity(.25)),
          boxShadow: AppTheme.subtleShadow,
        ),
        child: Row(children: [
          SourceIcon(source: source, size: 58),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(source.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(SourcePresentation.kindLabel(source.kind), style: TextStyle(color: AppTheme.textSecondaryColor)),
            const SizedBox(height: 8),
            Row(children: [
              Icon(availability == SourceAvailability.available ? Icons.check_circle : Icons.info_outline, size: 16, color: accent),
              const SizedBox(width: 5),
              Text(availability.label, style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 4),
            Text(SourcePresentation.statusMessage(source.id, source.kind), maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: AppTheme.textMutedColor, fontSize: 11)),
          ])),
          Icon(enabled ? Icons.chevron_left_rounded : Icons.block_rounded, color: enabled ? AppTheme.primaryColor : AppTheme.textMutedColor),
        ]),
      ),
    );
  }
}

class ExtensionsEmptyView extends StatelessWidget {
  const ExtensionsEmptyView({super.key});
  @override
  Widget build(BuildContext context) => const EmptyState(icon: Icons.extension_off_outlined, title: 'لا توجد إضافات متاحة');
}
