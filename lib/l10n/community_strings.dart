import 'package:flutter/widgets.dart';

class CommunityStrings {
  final bool isArabic;
  const CommunityStrings._(this.isArabic);

  static CommunityStrings of(BuildContext context) =>
      CommunityStrings._(Localizations.localeOf(context).languageCode == 'ar');

  String get community => isArabic ? 'المجتمع' : 'Community';
  String get subtitle => isArabic
      ? 'شارك ما تحبه مع محبي AniTV'
      : 'Share what you love with AniTV fans';
  String get searchHint =>
      isArabic ? 'ابحث في منشورات المجتمع...' : 'Search community posts...';
  String get clearSearch => isArabic ? 'مسح البحث' : 'Clear search';
  String get createPost => isArabic ? 'إنشاء منشور' : 'Create a post';
  String get writeSomething =>
      isArabic ? 'اكتب شيئًا...' : "What's on your mind?";
  String get addImage => isArabic ? 'إضافة صورة' : 'Add image';
  String get removeImage => isArabic ? 'إزالة الصورة' : 'Remove image';
  String get publish => isArabic ? 'نشر' : 'Post';
  String get publishing => isArabic ? 'جارٍ النشر...' : 'Posting...';
  String get noPosts => isArabic ? 'لا توجد منشورات حتى الآن' : 'No posts yet';
  String get notifications => isArabic ? 'الإشعارات' : 'Notifications';
  String get noNotifications =>
      isArabic ? 'لا توجد إشعارات بعد' : 'No notifications yet';
  String get noNotificationsHint => isArabic
      ? 'ستظهر التفاعلات وطلبات الصداقة هنا.'
      : 'Reactions and friend requests will appear here.';
  String get noSearchResults => isArabic ? 'لا توجد نتائج' : 'No posts found';
  String get searchEmptyHint => isArabic
      ? 'جرّب كلمة أخرى أو امسح البحث.'
      : 'Try another word or clear your search.';
  String get firstPost => isArabic
      ? 'كن أول من يشارك شيئًا مع محبي AniTV.'
      : 'Be the first to share something with AniTV fans.';
  String get loadError =>
      isArabic ? 'حدث خطأ أثناء تحميل المنشورات' : 'Failed to load community.';
  String get retryHint => isArabic
      ? 'تحقق من اتصال الإنترنت وحاول مرة أخرى.'
      : 'Please check your connection and try again.';
  String get signInPost => isArabic
      ? 'سجّل الدخول لإنشاء منشور.'
      : 'Please sign in to create a post.';
  String get signInLike =>
      isArabic ? 'سجّل الدخول للإعجاب.' : 'Please sign in to like posts.';
  String get signInComment =>
      isArabic ? 'سجّل الدخول للتعليق.' : 'Please sign in to comment.';
  String get signInReport =>
      isArabic ? 'سجّل الدخول للإبلاغ.' : 'Please sign in to report posts.';
  String get copyText => isArabic ? 'نسخ النص' : 'Copy text';
  String get copied => isArabic ? 'تم نسخ نص المنشور.' : 'Post text copied.';
  String get deletePost => isArabic ? 'حذف المنشور' : 'Delete post';
  String get reportPost => isArabic ? 'الإبلاغ عن المنشور' : 'Report post';
  String get deleteQuestion => isArabic ? 'حذف المنشور؟' : 'Delete post?';
  String get cannotUndo =>
      isArabic ? 'لا يمكن التراجع عن هذا الإجراء.' : 'This cannot be undone.';
  String get cancel => isArabic ? 'إلغاء' : 'Cancel';
  String get delete => isArabic ? 'حذف' : 'Delete';
  String get deleteFailed =>
      isArabic ? 'تعذر حذف المنشور.' : 'Unable to delete post.';
  String get likeFailed =>
      isArabic ? 'تعذر تحديث الإعجاب.' : 'Unable to update like.';
  String get postPublished =>
      isArabic ? 'تم نشر المنشور بنجاح.' : 'Post published successfully.';
  String get publishFailed => isArabic
      ? 'تعذر نشر المنشور. حاول مرة أخرى.'
      : 'Failed to publish post. Please try again.';
  String get writeOrImage => isArabic
      ? 'اكتب نصًا أو أضف صورة أولًا.'
      : 'Write something or add an image first.';
  String get comments => isArabic ? 'التعليقات' : 'Comments';
  String get postAndComments =>
      isArabic ? 'المنشور والتعليقات' : 'Post & comments';
  String get noComments => isArabic
      ? 'لا توجد تعليقات بعد. ابدأ المحادثة.'
      : 'No comments yet. Start the conversation.';
  String get writeComment =>
      isArabic ? 'اكتب تعليقًا...' : 'Write a comment...';
  String get deleteComment => isArabic ? 'حذف التعليق' : 'Delete comment';
  String get commentsLoadFailed =>
      isArabic ? 'تعذر تحميل التعليقات.' : 'Failed to load comments.';
  String get commentFailed =>
      isArabic ? 'تعذر إضافة التعليق.' : 'Failed to add comment.';
  String get commentDeleteFailed =>
      isArabic ? 'تعذر حذف التعليق.' : 'Unable to delete comment.';
  String get reason => isArabic ? 'السبب' : 'Reason';
  String get details => isArabic ? 'التفاصيل' : 'Details';
  String get other => isArabic ? 'أخرى' : 'Other';
  String get spam => isArabic ? 'رسائل مزعجة' : 'Spam';
  String get harassment => isArabic ? 'مضايقة' : 'Harassment';
  String get inappropriate =>
      isArabic ? 'محتوى غير مناسب' : 'Inappropriate content';
  String get misleading => isArabic ? 'زائف أو مضلل' : 'Fake / misleading';
  String get tellMore =>
      isArabic ? 'أخبرنا المزيد (اختياري)' : 'Tell us more (optional)';
  String get sending => isArabic ? 'جارٍ الإرسال...' : 'Sending...';
  String get submitReport => isArabic ? 'إرسال البلاغ' : 'Submit report';
  String get reportSubmitted =>
      isArabic ? 'تم إرسال البلاغ.' : 'Report submitted.';
  String get reportFailed =>
      isArabic ? 'تعذر إرسال البلاغ.' : 'Unable to submit report.';
  String get imageRejected => isArabic
      ? 'الصورة غير مدعومة. اختر JPG أو PNG أو WEBP.'
      : 'Unsupported image. Choose JPG, PNG or WEBP.';
  String get oversized => isArabic
      ? 'حجم الصورة كبير (الحد الأقصى 10 ميجابايت).'
      : 'Image is too large (10 MB maximum).';
}

extension CommunityContext on BuildContext {
  CommunityStrings get communityStrings => CommunityStrings.of(this);
}

String communityReasonLabel(CommunityStrings strings, String key) =>
    switch (key) {
      'Spam' => strings.spam,
      'Harassment' => strings.harassment,
      'Inappropriate content' => strings.inappropriate,
      'Fake / misleading' => strings.misleading,
      _ => strings.other,
    };
