import 'dart:ui';
import 'package:flutter/material.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const CustomBottomNavBar({Key? key, required this.currentIndex, required this.onTap}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            height: 76,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF171219).withOpacity(.92),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withOpacity(.10)),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(.42), blurRadius: 22, offset: const Offset(0, 10))],
            ),
            child: Row(children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
              _buildNavItem(1, Icons.explore_outlined, Icons.explore, 'استكشاف'),
              _buildNavItem(2, Icons.favorite_border_rounded, Icons.favorite_rounded, 'المفضلة'),
              _buildNavItem(3, Icons.person_outline_rounded, Icons.person_rounded, 'الملف الشخصي'),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isActive = currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          padding: const EdgeInsets.symmetric(vertical: 5),
          decoration: BoxDecoration(color: isActive ? const Color(0xFFE53935).withOpacity(.18) : Colors.transparent, borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedScale(
              scale: isActive ? 1.08 : 1,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: Icon(isActive ? activeIcon : inactiveIcon, size: 30, color: isActive ? const Color(0xFFE53935) : Colors.white70),
            ),
            const SizedBox(height: 1),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(color: isActive ? const Color(0xFFE53935) : Colors.white70, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
          ]),
        ),
      ),
    );
  }
}
