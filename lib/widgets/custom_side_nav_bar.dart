import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomSideNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const CustomSideNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final items = <({IconData icon, IconData active, String label})>[
      (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'الرئيسية'),
      (icon: Icons.explore_outlined, active: Icons.explore_rounded, label: 'استكشاف'),
      (icon: Icons.favorite_border_rounded, active: Icons.favorite_rounded, label: 'المفضلة'),
      (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'حسابي'),
    ];
    return Container(
      width: 88,
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        border: Border(
          left: isRtl ? const BorderSide(color: AppTheme.borderColor) : BorderSide.none,
          right: isRtl ? BorderSide.none : const BorderSide(color: AppTheme.borderColor),
        ),
      ),
      child: SafeArea(
        left: !isRtl,
        right: isRtl,
        child: Column(
          children: [
            const SizedBox(height: 18),
            const Text('AniTV', style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.w900, fontSize: 14)),
            const Spacer(),
            for (var i = 0; i < items.length; i++) ...[
              _item(items[i].icon, items[i].active, items[i].label, i),
              const SizedBox(height: 10),
            ],
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, IconData active, String label, int index) {
    final selected = currentIndex == index;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 64,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryColor.withOpacity(.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? AppTheme.primaryColor.withOpacity(.35) : Colors.transparent),
          ),
          child: Column(
            children: [
              Icon(selected ? active : icon, color: selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: selected ? Colors.white : AppTheme.textSecondaryColor, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
