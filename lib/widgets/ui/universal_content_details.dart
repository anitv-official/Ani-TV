import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'poster_image.dart';

class UniversalMetaItem {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const UniversalMetaItem({required this.value, required this.label, required this.icon, this.color = Colors.white70});
}

class UniversalDetailsHero extends StatelessWidget {
  final String title;
  final String? alternativeTitle;
  final String? imageUrl;
  final String? backdropUrl;
  final String typeLabel;
  final String? status;
  final IconData fallbackIcon;
  final List<Widget> actions;
  final VoidCallback? onBack;

  const UniversalDetailsHero({
    super.key,
    required this.title,
    this.alternativeTitle,
    this.imageUrl,
    this.backdropUrl,
    required this.typeLabel,
    this.status,
    this.fallbackIcon = Icons.movie_outlined,
    this.actions = const [],
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final wide = constraints.maxWidth >= 720;
      final height = wide ? 360.0 : 390.0;
      return SizedBox(
        height: height,
        child: Stack(children: [
          Positioned.fill(child: _Backdrop(url: backdropUrl ?? imageUrl)),
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black.withOpacity(.35), AppTheme.backgroundColor.withOpacity(.74), AppTheme.backgroundColor])))),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
              child: Column(children: [
                Row(children: [
                  _CircleAction(icon: Icons.arrow_back_rounded, onTap: onBack ?? () => Navigator.maybePop(context)),
                  const Spacer(),
                  ...actions.map((action) => Padding(padding: const EdgeInsetsDirectional.only(start: 8), child: action)),
                ]),
                const Spacer(),
                if (wide)
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _Poster(url: imageUrl, fallbackIcon: fallbackIcon, width: 156, height: 224),
                    const SizedBox(width: 20),
                    Expanded(child: _TitleBlock(title: title, alternativeTitle: alternativeTitle, typeLabel: typeLabel, status: status)),
                  ])
                else
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _Poster(url: imageUrl, fallbackIcon: fallbackIcon, width: 128, height: 184),
                    const SizedBox(width: 14),
                    Expanded(child: _TitleBlock(title: title, alternativeTitle: alternativeTitle, typeLabel: typeLabel, status: status)),
                  ]),
              ]),
            ),
          ),
        ]),
      );
    });
  }
}

class _TitleBlock extends StatelessWidget {
  final String title;
  final String? alternativeTitle;
  final String typeLabel;
  final String? status;
  const _TitleBlock({required this.title, this.alternativeTitle, required this.typeLabel, this.status});

  @override
  Widget build(BuildContext context) {
    final alt = alternativeTitle?.trim() ?? '';
    final state = status?.trim() ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Wrap(spacing: 7, runSpacing: 6, children: [
        _Badge(label: typeLabel, color: AppTheme.primaryColor),
        if (state.isNotEmpty) _Badge(label: state, color: Colors.greenAccent),
      ]),
      const SizedBox(height: 9),
      Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 23, height: 1.12, fontWeight: FontWeight.w900)),
      if (alt.isNotEmpty && alt != title.trim()) ...[
        const SizedBox(height: 6),
        Text(alt, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.25)),
      ],
    ]);
  }
}

class UniversalMetadata extends StatelessWidget {
  final List<UniversalMetaItem> items;
  const UniversalMetadata({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final visible = items.where((item) => item.value.trim().isNotEmpty && item.value.trim() != '—').toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(color: AppTheme.elevatedColor.withOpacity(.82), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderColor)),
      child: Row(children: [for (var i = 0; i < visible.length; i++) ...[
        Expanded(child: Column(children: [Icon(visible[i].icon, color: visible[i].color, size: 18), const SizedBox(height: 5), Text(visible[i].value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: visible[i].color, fontSize: 15, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(visible[i].label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondaryColor, fontSize: 10, fontWeight: FontWeight.w600))])),
        if (i < visible.length - 1) Container(width: 1, height: 42, color: AppTheme.borderColor),
      ]]),
    );
  }
}

class UniversalGenreChips extends StatelessWidget {
  final Iterable<dynamic> genres;
  const UniversalGenreChips({super.key, required this.genres});

  @override
  Widget build(BuildContext context) {
    final values = genres.map((value) => value is Map ? (value['name'] ?? value['title'] ?? value['slug'] ?? '') : value).map((value) => value.toString().trim()).where((value) => value.isNotEmpty).toList();
    if (values.isEmpty) return const SizedBox.shrink();
    return SizedBox(height: 38, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: values.length, separatorBuilder: (_, __) => const SizedBox(width: 7), itemBuilder: (_, index) => Container(padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9), decoration: BoxDecoration(color: AppTheme.elevatedColor, borderRadius: BorderRadius.circular(22), border: Border.all(color: AppTheme.primaryColor.withOpacity(.5))), child: Text(values[index], style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w700)))));
  }
}

class UniversalDescription extends StatefulWidget {
  final String text;
  final String title;
  const UniversalDescription({super.key, required this.text, this.title = 'القصة'});
  @override State<UniversalDescription> createState() => _UniversalDescriptionState();
}

class _UniversalDescriptionState extends State<UniversalDescription> {
  bool expanded = false;
  @override
  Widget build(BuildContext context) {
    final text = widget.text.trim();
    if (text.isEmpty) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      AnimatedCrossFade(
        duration: const Duration(milliseconds: 180),
        crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        firstChild: Text(text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.65, fontSize: 13)),
        secondChild: Text(text, style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.65, fontSize: 13)),
      ),
      if (text.length > 240) Align(alignment: AlignmentDirectional.centerStart, child: TextButton.icon(onPressed: () => setState(() => expanded = !expanded), icon: Icon(expanded ? Icons.expand_less : Icons.expand_more, size: 18), label: Text(expanded ? 'عرض أقل' : 'عرض المزيد'))),
      const SizedBox(height: 14),
    ]);
  }
}

class UniversalSectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  const UniversalSectionHeader(this.title, {super.key, this.trailing, this.onTrailing});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)), if (trailing != null) TextButton(onPressed: onTrailing, child: Text(trailing!))]);
}

class _Poster extends StatelessWidget {
  final String? url;
  final IconData fallbackIcon;
  final double width;
  final double height;
  const _Poster({this.url, required this.fallbackIcon, required this.width, required this.height});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(18), child: PosterImage(url: url, width: width, height: height, fit: BoxFit.cover, fallbackIcon: fallbackIcon, borderRadius: BorderRadius.zero));
}

class _Backdrop extends StatelessWidget {
  final String? url;
  const _Backdrop({this.url});
  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) return const DecoratedBox(decoration: BoxDecoration(color: AppTheme.surfaceColor));
    return Image.network(value, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const DecoratedBox(decoration: BoxDecoration(color: AppTheme.surfaceColor)));
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(.65))), child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)));
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleAction({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => IconButton(onPressed: onTap, style: IconButton.styleFrom(backgroundColor: Colors.black.withOpacity(.48), foregroundColor: Colors.white), icon: Icon(icon));
}
