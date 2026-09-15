class NewsItem {
  final String id;
  final String source;
  final String sourceArticleId;
  final String sourceUrl;
  final String canonicalUrl;
  final String titleOriginal;
  final String titleArabic;
  final String summaryOriginal;
  final String summaryArabic;
  final String imageUrl;
  final String category;
  final List<String> tags;
  final String relatedType;
  final String relatedItemId;
  final DateTime? publishedAt;
  final DateTime? fetchedAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  const NewsItem({
    required this.id,
    required this.source,
    required this.sourceArticleId,
    required this.sourceUrl,
    required this.canonicalUrl,
    required this.titleOriginal,
    required this.titleArabic,
    required this.summaryOriginal,
    required this.summaryArabic,
    required this.imageUrl,
    required this.category,
    required this.tags,
    required this.relatedType,
    required this.relatedItemId,
    required this.publishedAt,
    required this.fetchedAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
  });

  factory NewsItem.fromMap(Map<String, dynamic> map, {bool likedByMe = false}) {
    DateTime? date(dynamic value) => DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    List<String> tags(dynamic value) => value is List ? value.map((e) => e.toString()).where((e) => e.isNotEmpty).toList() :
        value is String ? value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList() : const [];
    int number(dynamic value) => value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? 0;
    return NewsItem(
      id: map['id']?.toString() ?? map[r'$id']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      sourceArticleId: map['sourceArticleId']?.toString() ?? '',
      sourceUrl: map['sourceUrl']?.toString() ?? '',
      canonicalUrl: map['canonicalUrl']?.toString() ?? map['sourceUrl']?.toString() ?? '',
      titleOriginal: map['titleOriginal']?.toString() ?? '',
      titleArabic: map['titleArabic']?.toString() ?? map['titleOriginal']?.toString() ?? '',
      summaryOriginal: map['summaryOriginal']?.toString() ?? '',
      summaryArabic: map['summaryArabic']?.toString() ?? map['summaryOriginal']?.toString() ?? '',
      imageUrl: map['imageUrl']?.toString() ?? '',
      category: map['category']?.toString() ?? 'أخبار مهمة',
      tags: tags(map['tags']),
      relatedType: map['relatedType']?.toString() ?? '',
      relatedItemId: map['relatedItemId']?.toString() ?? '',
      publishedAt: date(map['publishedAt']),
      fetchedAt: date(map['fetchedAt']),
      likeCount: number(map['likeCount']),
      commentCount: number(map['commentCount']),
      likedByMe: likedByMe || map['likedByMe'] == true,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id, 'source': source, 'sourceArticleId': sourceArticleId, 'sourceUrl': sourceUrl,
    'canonicalUrl': canonicalUrl, 'titleOriginal': titleOriginal, 'titleArabic': titleArabic,
    'summaryOriginal': summaryOriginal, 'summaryArabic': summaryArabic, 'imageUrl': imageUrl,
    'category': category, 'tags': tags, 'relatedType': relatedType, 'relatedItemId': relatedItemId,
    'publishedAt': publishedAt?.toIso8601String(), 'fetchedAt': fetchedAt?.toIso8601String(),
    'likeCount': likeCount, 'commentCount': commentCount, 'likedByMe': likedByMe,
  };

  NewsItem copyWith({int? likeCount, int? commentCount, bool? likedByMe}) => NewsItem(
    id: id, source: source, sourceArticleId: sourceArticleId, sourceUrl: sourceUrl, canonicalUrl: canonicalUrl,
    titleOriginal: titleOriginal, titleArabic: titleArabic, summaryOriginal: summaryOriginal,
    summaryArabic: summaryArabic, imageUrl: imageUrl, category: category, tags: tags,
    relatedType: relatedType, relatedItemId: relatedItemId, publishedAt: publishedAt,
    fetchedAt: fetchedAt, likeCount: likeCount ?? this.likeCount, commentCount: commentCount ?? this.commentCount,
    likedByMe: likedByMe ?? this.likedByMe,
  );
}

const newsCategories = <String>['الكل', 'الأحدث', 'الأكثر تفاعلًا', 'أنمي', 'مانجا', 'أفلام', 'مسلسلات', 'دراما', 'Streaming', 'أخبار مهمة'];
