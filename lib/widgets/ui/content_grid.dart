import 'package:flutter/material.dart';

class ContentGrid extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final ScrollController? controller;
  final EdgeInsetsGeometry padding;
  final int? columns;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  const ContentGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.controller,
    this.padding = const EdgeInsets.fromLTRB(16, 8, 16, 24),
    this.columns,
    this.shrinkWrap = false,
    this.physics,
  });

  static int columnsFor(double width) {
    if (width > 1200) return 6;
    if (width > 900) return 5;
    if (width > 600) return 4;
    if (width >= 400) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final count = columns ?? columnsFor(constraints.maxWidth);
        return GridView.builder(
          controller: controller,
          shrinkWrap: shrinkWrap,
          physics: physics ?? (shrinkWrap ? const NeverScrollableScrollPhysics() : const BouncingScrollPhysics()),
          padding: padding,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            childAspectRatio: 0.64,
            crossAxisSpacing: 10,
            mainAxisSpacing: 12,
          ),
          itemCount: itemCount,
          itemBuilder: itemBuilder,
        );
      },
    );
  }
}

class HorizontalContentList extends StatelessWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final double itemWidth;

  const HorizontalContentList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.height = 214,
    this.itemWidth = 118,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) => SizedBox(width: itemWidth, child: itemBuilder(context, index)),
      ),
    );
  }
}
