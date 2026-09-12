import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/app_theme.dart';

class CustomSideNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const CustomSideNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final radius = BorderRadius.horizontal(
      left: isRtl ? const Radius.circular(18) : Radius.zero,
      right: isRtl ? Radius.zero : const Radius.circular(18),
    );
    return Container(
      width: 76,
      decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface, borderRadius: radius, border: Border.all(color: Colors.white.withOpacity(.06))),
      child: SafeArea(
        left: !isRtl,
        right: isRtl,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavItem(0, 'assets/icons/home.svg', 'assets/icons/home_red.svg'),
            const SizedBox(height: 18),
            _buildNavItem(1, 'assets/icons/explore.svg', 'assets/icons/explore_red.svg'),
            const SizedBox(height: 18),
            _buildNavItem(2, 'assets/icons/favorite.svg', 'assets/icons/favorite_red.svg'),
            const SizedBox(height: 18),
            _buildNavItem(3, 'assets/icons/profile.svg', 'assets/icons/profile_red.svg'),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, String inactiveIcon, String activeIcon) {
    final active = currentIndex == index;
    return Semantics(
      button: true,
      selected: active,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: active ? AppTheme.primaryColor.withOpacity(.14) : Colors.transparent, borderRadius: BorderRadius.circular(14)),
          child: SvgPicture.asset(active ? activeIcon : inactiveIcon, width: 23, height: 23, colorFilter: active ? null : const ColorFilter.mode(AppTheme.textSecondaryColor, BlendMode.srcIn)),
        ),
      ),
    );
  }
}
