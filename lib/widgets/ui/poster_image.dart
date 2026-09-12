import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class PosterImage extends StatelessWidget {
  final String? url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;

  const PosterImage({
    super.key,
    this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.movie_outlined,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(AppTheme.radiusSmall);
    final imageUrl = (url ?? '').trim();
    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        width: width,
        height: height,
        child: imageUrl.isEmpty
            ? _fallback()
            : CachedNetworkImage(
                imageUrl: imageUrl,
                fit: fit,
                width: width ?? double.infinity,
                height: height,
                placeholder: (_, __) => Container(color: AppTheme.elevatedColor),
                errorWidget: (_, __, ___) => _fallback(),
              ),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppTheme.elevatedColor,
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: AppTheme.textMutedColor, size: 28),
    );
  }
}
