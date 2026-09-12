import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppScaffoldHeader extends StatelessWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;

  const AppScaffoldHeader({
    super.key,
    required this.title,
    this.showBack = false,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            if (showBack)
              IconButton(
                tooltip: 'رجوع',
                onPressed: () => Navigator.maybePop(context),
                icon: const Icon(Icons.arrow_back_rounded),
              )
            else
              const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ),
            ...?actions,
          ],
        ),
      ),
    );
  }
}

class AppPage extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const AppPage({super.key, required this.child, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor ?? AppTheme.backgroundColor,
      body: SafeArea(child: child),
    );
  }
}
