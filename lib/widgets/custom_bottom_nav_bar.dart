import 'package:flutter/material.dart';
import 'dart:ui'; // For ClipRect and BackdropFilter

class CustomBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      // margin removed for docked look
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)), // Rounded top only
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF1A0000).withOpacity(0.8), // Very dark red/black with opacity for glass
            const Color(0xFF000000).withOpacity(0.9), // Black
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 10,
            offset: const Offset(0, -5), // Shadow upwards
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: SafeArea( // Added SafeArea to handle system gesture area
            top: false,
            child: Container(
              padding: const EdgeInsets.only(top: 6, bottom: 4, left: 8, right: 8),
              color: Colors.black.withOpacity(0.2),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: (false)
                        ? 500
                        : double.infinity,
                  ),
                  child: Row(
                    children: [
                      _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'الرئيسية'),
                      _buildNavItem(1, Icons.search_rounded, Icons.search, 'بحث'),
                      _buildNavItem(2, Icons.explore_outlined, Icons.explore, 'استكشاف'),
                      _buildNavItem(3, Icons.favorite_border_rounded, Icons.favorite_rounded, 'المفضلة'),
                      _buildNavItem(4, Icons.person_outline_rounded, Icons.person_rounded, 'الملف الشخصي'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData inactiveIcon, IconData activeIcon, String label) {
    final isActive = currentIndex == index;
    
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isActive ? activeIcon : inactiveIcon, size: 24, color: isActive ? const Color(0xFFE53935) : Colors.white70),
              const SizedBox(height: 2),
              Flexible(
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                  style: TextStyle(color: isActive ? const Color(0xFFE53935) : Colors.white70, fontSize: 10, fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
