import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Placeholder page kept in the navigation after the YouTube source removal.
class YoutubeScreen extends StatelessWidget {
  final bool embedded;

  const YoutubeScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              'لائحة يوتيوب',
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.ondemand_video_rounded,
                    size: 64,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'صفحة يوتيوب',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimaryColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'مصدر يوتيوب غير متاح حاليًا.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );

    if (embedded) return content;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(child: content),
    );
  }
}
