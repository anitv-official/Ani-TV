import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'poster_image.dart';
import 'source_badge.dart';

class ContentCard extends StatelessWidget {
  final String? title;
  final String? imageUrl;
  final String? badge;
  final VoidCallback? onTap;
  final Widget? overlay;
  final bool compactTitle;

  const ContentCard({
    super.key,
    this.title,
    this.imageUrl,
    this.badge,
    this.onTap,
    this.overlay,
    this.compactTitle = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                      border: Border.all(color: AppTheme.borderColor),
                      boxShadow: AppTheme.subtleShadow,
                    ),
                    child: PosterImage(
                      url: imageUrl,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                    ),
                  ),
                  if (badge != null && badge!.trim().isNotEmpty)
                    Positioned.directional(
                      textDirection: Directionality.of(context),
                      top: 6,
                      start: 6,
                      child: SourceBadge(label: badge),
                    ),
                  if (overlay != null) overlay!,
                ],
              ),
            ),
            const SizedBox(height: 7),
            SizedBox(
              height: compactTitle ? 18 : 31,
              child: Text(
                title ?? '',
                maxLines: compactTitle ? 1 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 12,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AnimeCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback? onTap;

  const AnimeCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      title: item['title']?.toString(),
      imageUrl: (item['image_url'] ?? item['image'])?.toString(),
      badge: item['source']?.toString(),
      onTap: onTap,
    );
  }
}

class MangaCard extends StatelessWidget {
  final dynamic item;
  final VoidCallback? onTap;

  const MangaCard({super.key, required this.item, this.onTap});

  @override
  Widget build(BuildContext context) {
    return ContentCard(
      title: item['title']?.toString(),
      imageUrl: (item['image_url'] ?? item['image'])?.toString(),
      badge: (item['type'] ?? item['source'])?.toString(),
      onTap: onTap,
    );
  }
}
