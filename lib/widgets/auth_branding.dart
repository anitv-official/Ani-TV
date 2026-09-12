import 'package:flutter/material.dart';

class AuthBranding extends StatefulWidget {
  const AuthBranding({super.key});
  @override
  State<AuthBranding> createState() => _AuthBrandingState();
}

class _AuthBrandingState extends State<AuthBranding> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600))..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (_, __) {
      final progress = Curves.easeOutCubic.transform(_controller.value);
      final glow = _controller.value > .55 ? (1 - ((_controller.value - .55) / .45)).clamp(0.0, 1.0) : 0.0;
      return SizedBox(
        height: 76,
        child: Center(
          child: ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
          child: Text('AniTV', style: TextStyle(color: const Color(0xFFE50914), fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 1.6, shadows: [Shadow(color: const Color(0xFFE50914).withOpacity(glow * .35), blurRadius: 10)])),
            ),
          ),
        ),
      );
    },
  );
}
