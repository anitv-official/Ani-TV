import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../download_action_button.dart';
import 'poster_image.dart';

class EpisodeTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? description;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Future<bool> Function()? onDownload;

  const EpisodeTile({
    super.key,
    required this.title,
    this.subtitle,
    this.description,
    this.imageUrl,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PosterImage(
                url: imageUrl,
                width: 118,
                height: 68,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 68,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                      ],
                      if (description != null && description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(description!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textMutedColor, fontSize: 11, height: 1.25)),
                      ],
                    ],
                  ),
                ),
              ),
              if (onDownload != null) DownloadActionButton(onDownload: onDownload!),
            ],
          ),
        ),
      ),
    );
  }
}

class ChapterTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? imageUrl;
  final VoidCallback? onTap;
  final Future<bool> Function()? onDownload;

  const ChapterTile({
    super.key,
    required this.title,
    this.subtitle,
    this.imageUrl,
    this.onTap,
    this.onDownload,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              PosterImage(
                url: imageUrl,
                width: 58,
                height: 72,
                fallbackIcon: Icons.menu_book_outlined,
                borderRadius: BorderRadius.circular(10),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              if (onDownload != null) DownloadActionButton(size: 20, onDownload: onDownload!),
            ],
          ),
        ),
      ),
    );
  }
}
