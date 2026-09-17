import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class DetailStatsCard extends StatelessWidget {
  final List<DetailStat> stats;
  const DetailStatsCard({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
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
        child: Text(title, style: const TextStyle(color: AppTheme.textPrimaryColor, fontSize: 18, fontWeight: FontWeight.w800)),
      );
}
