import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class SourceBadge extends StatelessWidget {
  final String? label;
  final bool compact;

  const SourceBadge({super.key, this.label, this.compact = true});

  @override
  Widget build(BuildContext context) {
    final text = (label ?? '').trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(.92),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text.toUpperCase(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white,
          fontSize: compact ? 9 : 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}
