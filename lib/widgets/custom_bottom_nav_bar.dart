import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const CustomBottomNavBar({super.key, required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, IconData active, String label})>[
      (icon: Icons.home_outlined, active: Icons.home_rounded, label: 'الرئيسية'),
      (icon: Icons.explore_outlined, active: Icons.explore_rounded, label: 'استكشاف'),
      (icon: Icons.favorite_border_rounded, active: Icons.favorite_rounded, label: 'المفضلة'),
      (icon: Icons.person_outline_rounded, active: Icons.person_rounded, label: 'حسابي'),
    ];
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Container(
        height: 62,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(.98),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(.08)),
          boxShadow: AppTheme.mediumShadow,
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = index == currentIndex;
            return Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: item.label,
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(14),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primaryColor.withOpacity(.14) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(selected ? item.active : item.icon, size: 21, color: selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor),
                        const SizedBox(height: 3),
                        Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, height: 1, color: selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor, fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
