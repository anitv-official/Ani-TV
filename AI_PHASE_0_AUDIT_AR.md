# PHASE 0 — تدقيق جاهزية دمج AI في AniTV

**التاريخ:** 23 سبتمبر 2026
**الفرع:** `main`
**الالتزام المفحوص:** `8b6b799`
**النطاق:** فهم المشروع قبل إضافة أي كود AI. لم تُنفذ تغييرات وظيفية في هذه المرحلة.

## النتيجة

المشروع تطبيق Flutter Android عربي يستخدم `Provider` لإدارة الحالة، ومحولات مصادر موحدة للأنمي والدراما والمانجا والفيديو، وخدمات مستقلة للحسابات والتنزيلات والمجتمع. البنية الحالية مناسبة لإضافة AI كطبقة orchestration فوق `SourceRegistry` و`DownloadService` وواجهات التنقل الحالية، بشرط عدم جعل AI يتعامل مباشرة مع أي مصدر أو مشغل أو API.

لا يوجد حاليًا تكامل OpenRouter أو مزود AI داخل المشروع. لا توجد حاجة إلى API key في PHASE 0. سيظهر احتياج OpenRouter في PHASE 1 فقط، ولن يوضع المفتاح في Git أو داخل ملف مصدر.

## خريطة المعمارية الحالية

### المحتوى والمصادر

`SourceRegistry` هو نقطة الدمج الحالية للمصادر. العقد الأساسي موجود في `lib/sources/source_base.dart` عبر `ContentSource`، ويعرّف البحث، والأحدث، والتفاصيل، وروابط التشغيل، وصور الفصول. السجل يضيف إعادة محاولة، مهلة 35 ثانية، تخزينًا مؤقتًا محدودًا، ودمجًا يتحمل فشل مصدر منفرد.

المصادر المدمجة حاليًا هي:

| النوع | المصادر |
|---|---|
| أنمي | Anime Slayer، Animefy، Anime Witcher، Anime3rb |
| دراما وأفلام | Drama Slayer، Wecima، Kormoz، EgyDead، Krmzy، Afl aam، Akwam، FaselHD |
| مانجا | Manga Swat، MangaTime، MangaMello |
| فيديو | YouTube |

تعاد البيانات حاليًا على هيئة `Map<String, dynamic>`، ولا توجد نماذج موحدة typed للتفاصيل أو الحلقة أو الفصل أو خيار التشغيل. يوجد `DownloadTask` typed للتنزيل فقط، ويحوّل الحالة القديمة المخزنة في SharedPreferences إلى نموذج قابل للقراءة.

### مسار البحث

الشاشة `SearchScreen` تستدعي `ApiService.searchAll`، التي تفوض إلى `SourceRegistry.searchAll`. النتائج تحمل حقولًا مثل `title`, `url`, `image_url`, `type`, `category`, `source`, و`source_id`. يوجه التطبيق نتيجة الأنمي أو الدراما إلى شاشة التفاصيل الحالية، ونتيجة المانجا إلى `ComicDetailsScreen`، ونتيجة YouTube إلى `YouTubeWatchScreen`.

يوجد مسار قديم للتصنيفات في `ApiService`: الدالتان `fetchGenres` و`fetchGenreContent` تعيدان بيانات فارغة. لن يعتمد AI على هذا المسار قبل إصلاحه أو إرجاع حالة عدم الدعم بصورة صريحة.

### التفاصيل والتشغيل

يتم تحميل تفاصيل الأنمي والدراما والفيلم عبر `ApiService.fetchAnimeDetails` ثم `SourceRegistry.details`. يتم حل روابط التشغيل عبر `ApiService.fetchEpisodeStreams` ثم `SourceRegistry.streams`. طبقة السجل تتحقق من الروابط وتمنع كثيرًا من تمرير صفحات player غير المباشرة للمشغل الأصلي.

المشغل الحالي هو `VideoPlayerScreen`. لا يجوز استبداله. مسار AI المستقبلي سيكون:

```text
AI Controller
  -> Tool Registry
  -> Content/Playback abstraction
  -> SourceRegistry.streams
  -> VideoPlayerScreen الحالي
```

### المانجا والفصول

يتم تحميل التفاصيل عبر `ApiService.fetchComicDetails` ثم `SourceRegistry.details`. صور الفصل تمر عبر `ApiService.fetchChapterImages` ثم `SourceRegistry.chapterImages`. القارئ الحالي هو `MangaReaderScreen`، ويدعم التمرير، ووضع الصفحة، والتكبير، وحفظ الموضع، والتنقل للفصل التالي عند توفر بيانات التنقل.

مسار AI المستقبلي سيكون:

```text
AI Controller
  -> search/get chapter tool
  -> SourceRegistry.chapterImages
  -> MangaReaderScreen الحالي
```

### التنزيلات

`DownloadService` مسؤول عن طابور تنزيل الفيديو، والمهل، والاستكمال باستخدام ملفات `.part`، والإيقاف، والاستئناف، والإلغاء، والإشعارات، واستعادة المهام بعد إغلاق التطبيق. يدعم أيضًا حفظ صور فصول المانجا داخل التخزين المحلي. شاشة العرض الحالية هي `DownloadsScreen`، ويوجد نموذج `DownloadTask` في `lib/models/download_task.dart`.

لا يجوز إنشاء Download Manager بديل. مسار AI المستقبلي سيكون:

```text
AI Controller
  -> download tool
  -> resolve real stream or chapter images
  -> DownloadService الحالي
  -> DownloadsScreen الحالية
```

### الحساب والحالة والتنقل

`AppStateProvider` يدير جلسة المستخدم، المفضلة، السجل، الإعدادات، والمزامنة المحلية والسحابية. الضيف لا يملك سجلًا دائمًا وفق السلوك الحالي. التنقل يستخدم `Navigator` و`MaterialPageRoute` من الشاشات نفسها، مع `appNavigatorKey` لمعالجة الروابط العميقة والإشعارات.

لا توجد dependency injection مستقلة. الاعتماديات تُنشأ غالبًا عبر singletons أو استدعاءات static، مثل `SourceRegistry`, `DownloadService`, `ApiService`, و`AppwriteService`. يجب أن تستخدم اختبارات AI fake adapters بدل الاتصالات الحقيقية.

### HTTP والإعدادات والأمان

يستخدم المشروع `http` للاتصالات العامة، وتوجد مكتبات Appwrite وSupabase وFirebase. لا يوجد `OpenRouterService` حاليًا. ملف `pubspec.yaml` يعلن Dart SDK من `3.3.0` إلى أقل من `4.0.0`، وGitHub Actions يستخدم Flutter `3.29.3` مع Java 17.

لن توضع مفاتيح OpenRouter داخل GitHub أو Dart source. وبما أن التطبيق Mobile client، فإن أي مفتاح يمرر إلى APK يمكن استخراجه من التطبيق؛ لذلك يجب توثيق هذا الخطر. في PHASE 1 ستُستخدم configuration قابلة للتغيير مثل `--dart-define` للتطوير فقط، مع عدم اعتبارها حماية كاملة للمفتاح. يظل الحل الإنتاجي الآمن بحاجة إلى وسيط خادمي موثوق، لكن لن يُنشأ Backend مدفوع ضمن هذه المهمة.

## الخريطة المطلوبة لتكامل AI

```text
AI UI
  -> AI Controller / Orchestrator
  -> AI Tool Registry
  -> Content, Playback, and Download abstractions
  -> SourceRegistry / AppStateProvider / DownloadService
  -> Existing sources and APIs
  -> Real content
```

```text
AI
  -> play_episode
  -> playback abstraction
  -> SourceRegistry.streams
  -> existing VideoPlayerScreen
```

```text
AI
  -> download_episode or download_chapter
  -> existing DownloadService
  -> existing internal downloader
  -> DownloadsScreen
```

## فجوات يجب احترامها في المراحل التالية

1. لا توجد نماذج typed موحدة للمحتوى والحلقة والفصل وخيار التشغيل. يجب ألا تحل أدوات AI هذا النقص بخرائط خاصة بها؛ إما تستخدم العقد الحالية بحذر أو تضيف نماذج مشتركة صغيرة دون كسر المصادر.
2. البحث العام موجود، لكن تصنيفات `fetchGenres` و`fetchGenreContent` غير منفذة. أي tool للتصنيفات يجب أن يعيد `unsupported` بدل اختلاق بيانات.
3. المصادر التي لا تعيد stream أو chapter images يجب أن تعيد سبب فشل واضحًا.
4. نتائج الأدوات يجب أن تحمل الرابط والمعرف الحقيقيين الموجودين في نتيجة المصدر، مع `source_id` وعدم إنشاء IDs أو URLs مصطنعة.
5. لا يجوز تنفيذ تشغيل أو تنزيل بمجرد النص النهائي من AI. يجب أن يعيد النظام Action موثوقًا، ويربطه بنتيجة حقيقية، ويعرض زرًا أو مسارًا صريحًا للتنفيذ.
6. يجب أن يكون تنفيذ الأدوات قابلاً للإلغاء أو منع التكرار عندما يرسل المستخدم رسائل متتابعة بسرعة.
7. يجب عدم إرسال بيانات الحساب أو كلمات المرور أو مفاتيح الخدمات أو محتوى غير ضروري إلى OpenRouter.

## نتيجة فحص المرحلة

تمت مراجعة البنية الحالية بعد دمج `feature/unified-source-extensions` في `main`. توجد GitHub Actions للتحليل والاختبارات وبناء APK. في هذه المرحلة لم تُضف ملفات Dart وظيفية ولم يُطلب API key.

الانتقال إلى PHASE 1 مسموح بعد تنفيذ تحقق المرحلة على GitHub. ستحتاج PHASE 1 إلى إعداد OpenRouter قابل للتغيير، ولن أطلب المفتاح إلا عند بلوغ خطوة تشغيل تكامل OpenRouter الحقيقي أو اختبار الطلب الحي. اختبارات الوحدة لن تعتمد على OpenRouter الحقيقي.
