import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CustomSideNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const CustomSideNavBar({Key? key, required this.currentIndex, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
        gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [const Color(0xFF1A0000).withOpacity(.8), Colors.black.withOpacity(.9)]),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.5), blurRadius: 10, offset: const Offset(5, 0))],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea(
            right: false,
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              _buildNavItem(0, 'assets/icons/home.svg', 'assets/icons/home_red.svg'),
              const SizedBox(height: 30),
              _buildNavItem(1, 'assets/icons/explore.svg', 'assets/icons/explore_red.svg'),
              const SizedBox(height: 30),
              _buildNavItem(2, 'assets/icons/favorite.svg', 'assets/icons/favorite_red.svg'),
              const SizedBox(height: 30),
              _buildNavItem(3, 'assets/icons/profile.svg', 'assets/icons/profile_red.svg'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String inactiveIcon, String activeIcon) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isActive ? 1.1 : 1,
        duration: const Duration(milliseconds: 220),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SvgPicture.asset(isActive ? activeIcon : inactiveIcon, width: 30, height: 30, colorFilter: isActive ? null : const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
        ),
      ),
    );
  }
}
