import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_scaffold_header.dart';
import '../widgets/ui/segmented_toggle.dart';
import 'search_screen.dart';

class CategoriesScreen extends StatefulWidget {
  final bool initialIsAnime;
  const CategoriesScreen({Key? key, this.initialIsAnime = true}) : super(key: key);

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  late bool _isAnimeSelected;

  @override
  void initState() {
    super.initState();
    _isAnimeSelected = widget.initialIsAnime;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppScaffoldHeader(
              title: 'التصنيفات',
              showBack: true,
              actions: [
                IconButton(
                  tooltip: 'بحث',
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen(autoFocus: true))),
                  icon: const Icon(Icons.search_rounded),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: SegmentedToggle(
                labels: const ['أنمي', 'مانجا'],
                index: _isAnimeSelected ? 0 : 1,
                onChanged: (i) => setState(() => _isAnimeSelected = i == 0),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int crossAxisCount;
                  if (constraints.maxWidth > 1200) {
                    crossAxisCount = 6;
                  } else if (constraints.maxWidth > 900) {
                    crossAxisCount = 5;
                  } else if (constraints.maxWidth > 600) {
                    crossAxisCount = 3;
                  } else {
                    crossAxisCount = 2;
                  }
                  return GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: 8,
                    itemBuilder: (context, index) => _buildCategoryCard(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(.16),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_isAnimeSelected ? Icons.movie_outlined : Icons.menu_book_outlined, color: AppTheme.primaryColor, size: 20),
          ),
          const Spacer(),
          const Text('تصنيف', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(_isAnimeSelected ? 'قريباً للأنمي' : 'قريباً للمانجا', style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12)),
        ],
      ),
    );
  }
}
