import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyMoviesScreen extends StatelessWidget {
  final bool embedded;
  const EmptyMoviesScreen({super.key, this.embedded = false});

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text('لائحة الأفلام والمسلسلات', style: TextStyle(color: AppTheme.textPrimaryColor, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
        ),
        const Expanded(child: SizedBox.shrink()),
      ],
    );
    if (embedded) return content;
    return Scaffold(backgroundColor: AppTheme.backgroundColor, body: SafeArea(child: content));
  }
}
