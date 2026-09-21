import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'poster_image.dart';

class DetailStatsCard extends StatelessWidget {
  final List<DetailStat> stats;
  const DetailStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedColor.withOpacity(.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.borderColor.withOpacity(.9)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            Expanded(child: _StatCell(stat: stats[i])),
            if (i < stats.length - 1)
              Container(width: 1, height: 42, color: AppTheme.borderColor),
          ],
        ],
      ),
    );
  }
}

class DetailStat {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const DetailStat({required this.value, required this.label, required this.icon, required this.color});
}

class _StatCell extends StatelessWidget {
  final DetailStat stat;
  const _StatCell({required this.stat});
  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(stat.value, style: TextStyle(color: stat.color, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(width: 5),
              Icon(stat.icon, color: stat.color, size: 17),
            ],
          ),
          const SizedBox(height: 5),
          Text(stat.label, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      );
}

class DetailTags extends StatelessWidget {
  final Iterable<dynamic> tags;
  const DetailTags({super.key, required this.tags});
  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: tags
            .map((tag) => tag is Map ? (tag['name'] ?? tag['title'] ?? tag['slug'] ?? '') : tag)
            .where((tag) => tag.toString().trim().isNotEmpty)
            .map((tag) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: AppTheme.elevatedColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Text(tag.toString(), style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 11, fontWeight: FontWeight.w600)),
                ))
            .toList(),
      );
}

class DetailSectionTitle extends StatelessWidget {
  final String title;
  const DetailSectionTitle(this.title, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 9),
        child: Text(title, style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 16, fontWeight: FontWeight.w800)),
      );
}

class RelatedContentRail extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final ValueChanged<Map<String, dynamic>> onTap;

  const RelatedContentRail({super.key, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DetailSectionTitle('مشابه ومقترح لك'),
        SizedBox(
          height: 212,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              return SizedBox(
                width: 126,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onTap(item),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: PosterImage(
                          url: item['image_url']?.toString(),
                          borderRadius: BorderRadius.circular(14),
                          width: 126,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(item['title']?.toString() ?? 'بدون عنوان', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
