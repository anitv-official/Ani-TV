import 'package:flutter/material.dart';
import '../../sources/source_base.dart';
import '../../sources/source_presentation.dart';
import '../../theme/app_theme.dart';

class SourceIcon extends StatelessWidget {
  final ContentSource source;
  final double size;
  const SourceIcon({super.key, required this.source, this.size = 50});

  @override
  Widget build(BuildContext context) {
    final fallback = source.kind == 'manga' ? Icons.menu_book_rounded : source.kind == 'anime' ? Icons.ondemand_video_rounded : Icons.movie_rounded;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: size,
        height: size,
        color: AppTheme.primaryColor.withOpacity(.12),
        child: Image.network(
          SourcePresentation.iconFor(source.id, source.hosts),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(fallback, color: AppTheme.primaryColor, size: size * .52),
        ),
      ),
    );
  }
}
