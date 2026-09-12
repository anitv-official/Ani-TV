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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.cardColor.withOpacity(.97),
        border: const Border(top: BorderSide(color: AppTheme.borderColor)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: selected ? 22 : 8,
                          height: 3,
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: selected ? AppTheme.primaryColor : Colors.transparent,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        Icon(
                          selected ? item.active : item.icon,
                          size: 22,
                          color: selected ? AppTheme.primaryColor : AppTheme.textSecondaryColor,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1,
                            color: selected ? Colors.white : AppTheme.textSecondaryColor,
                            fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
