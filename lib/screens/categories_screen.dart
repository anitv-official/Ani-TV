import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_fixed_header.dart';
import '../widgets/app_navigation_drawer.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatelessWidget {
  final bool initialIsAnime;
  const CategoriesScreen({super.key, this.initialIsAnime = true});

  static const _categories = <_Category>[
    _Category('الأنمي', 'أكثر من 5,432 عمل', Icons.movie_rounded, 'https://anslayer.com/favicon.ico'),
    _Category('المانجا', 'أكثر من 3,210 عمل', Icons.menu_book_rounded, 'https://mangatime.org/favicon.ico'),
    _Category('المانهوا', 'أكثر من 4,215 عمل', Icons.auto_stories_rounded, 'https://anime3rb.com/favicon.ico'),
    _Category('المانها الصينية', 'أكثر من 1,832 عمل', Icons.book_rounded, 'https://mangamello.com/favicon.ico'),
    _Category('الروايات', 'أكثر من 4,726 عمل', Icons.auto_stories_rounded, 'https://novelupdates.com/favicon.ico'),
    _Category('الأفلام', 'أكثر من 2,108 عمل', Icons.local_movies_rounded, 'https://wecima.show/favicon.ico'),
    _Category('المسلسلات', 'أكثر من 1,543 عمل', Icons.live_tv_rounded, 'https://kormoz.com/favicon.ico'),
    _Category('الدراما', 'أكثر من 987 عمل', Icons.theaters_rounded, 'https://drslayer.com/favicon.ico'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      endDrawer: const AppNavigationDrawer(),
      body: SafeArea(child: Column(children: [
        const AppFixedHeader(title: 'التصنيفات', showBack: true),
        const Padding(padding: EdgeInsets.fromLTRB(16, 8, 16, 14), child: Align(alignment: AlignmentDirectional.centerStart, child: Text('اختر نوع المحتوى الذي تريد استكشافه', style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 13))),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          final columns = constraints.maxWidth >= 900 ? 2 : 1;
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: columns, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: columns == 1 ? 3.2 : 2.9),
            itemCount: _categories.length,
            itemBuilder: (_, index) => _CategoryCard(category: _categories[index]),
          );
        })),
      ])),
    );
  }
}

class _Category {
  final String title;
  final String count;
  final IconData icon;
  final String image;
  const _Category(this.title, this.count, this.icon, this.image);
}

class _CategoryCard extends StatelessWidget {
  final _Category category;
  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen(autoFocus: true))),
        borderRadius: BorderRadius.circular(18),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(color: AppTheme.surfaceColor, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppTheme.borderColor), boxShadow: AppTheme.subtleShadow),
          child: Stack(children: [
            Positioned.fill(child: Opacity(opacity: .18, child: Image.network(category.image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()))),
            Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: AlignmentDirectional.centerStart, end: AlignmentDirectional.centerEnd, colors: [AppTheme.surfaceColor.withOpacity(.96), AppTheme.surfaceColor.withOpacity(.68), Colors.transparent])))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), child: Row(children: [
              Container(width: 48, height: 48, decoration: BoxDecoration(color: AppTheme.primaryColor.withOpacity(.16), borderRadius: BorderRadius.circular(14), border: Border.all(color: AppTheme.primaryColor.withOpacity(.35))), child: Icon(category.icon, color: AppTheme.primaryColor, size: 24)),
              const SizedBox(width: 13),
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(category.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), const SizedBox(height: 4), Text(category.count, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11))])),
              const Icon(Icons.chevron_left_rounded, color: Colors.white70),
            ])),
          ]),
        ),
      );
}
