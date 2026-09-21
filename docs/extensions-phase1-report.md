# تقرير المرحلة الأولى من نظام Extensions في AniTV

## النتيجة العامة

أضيف إلى AniTV عقد موحد لنظام Extensions فوق بنية `ContentSource` الحالية. يحتوي النظام على ثلاثة Providers فقط: **Anime Witcher** و**EgyDead** و**YouTube**. أضيفت صفحة عربية باسم **الإضافات** إلى التنقل الرئيسي، وتظهر فيها بطاقات احترافية تعرض اسم المصدر ونوع المحتوى والحالة وإمكانية فتح صفحة المصدر.

لم يُستبدل مشغل الفيديو الحالي. تمر روابط التشغيل الناتجة من الـProvider إلى العقد الموجود في AniTV عبر `stream_url` و`direct_stream_urls` و`headers`. يحتفظ المشغل باختيار الجودة عندما يرسل المصدر جودة رقمية أو تسمية `Auto`.

## الملفات الجديدة

| المسار | الدور |
|---|---|
| `lib/extensions/extension_base.dart` | عقد Extension وحالة المصدر والبيانات الوصفية |
| `lib/extensions/extension_catalog.dart` | تسجيل Providers المرحلة الأولى |
| `lib/extensions/providers/extension_http.dart` | أدوات HTTP وتحليل JSON المتوازن والروابط |
| `lib/extensions/providers/anime_witcher_extension.dart` | تكامل Algolia وFirestore مع Anime Witcher |
| `lib/extensions/providers/egydead_extension.dart` | تحليل كتالوج وتفاصيل وروابط EgyDead |
| `lib/extensions/providers/youtube_extension.dart` | تحليل ytInitialData وبيانات المشغل وروابط progressive |
| `lib/screens/extensions_screen.dart` | واجهة صفحة الإضافات وبطاقات المصادر |
| `test/extensions_test.dart` | اختبارات التسجيل وتوجيه روابط المصادر |
| `docs/extensions-phase1-report.md` | هذا التقرير |

## Anime Witcher

يستخدم الـProvider الجديد Algolia للصفحة الرئيسية والبحث، ثم يستخدم Firestore REST لقراءة ملخص الحلقات وسجلات السيرفرات. لم يتم الاعتماد على محلل HTML القديم. يتم إنشاء روابط تفاصيل تحتوي على نتيجة Algolia المشفرة كبيانات احتياطية، وتُحوّل حلقات Firestore إلى قائمة حلقات مسطحة متوافقة مع شاشة AniTV.

تُقرأ روابط السيرفرات من `servers2/all_servers` وتُرتب حسب الجودة الرقمية. تُمرر الروابط الناتجة إلى المشغل مع `Referer` و`User-Agent`. لم يُدمج `loadExtractor` الخاص بـCloudstream، لذلك فالسيرفرات التي تحتاج extractor خارجي أو استخراج subtitles لا تُعد مدعومة native بعد.

## EgyDead

يستخدم الـProvider الجديد طلبات HTML متوافقة مع سلوك المصدر الأصلي. يعالج الصفحة الرئيسية والبحث وبطاقات `/film/` وصفحات الحلقات، ويستخرج روابط الحلقات من بنية HTML. في صفحة المشاهدة يرسل POST `View=1` ثم يستخدم fallback إلى GET، ويجمع روابط `m3u8` و`mp4` وبعض روابط embed مع headers تشمل `Referer` و`User-Agent` و`Accept-Language`.

صُنّف المصدر **متاحاً جزئياً** لأن Cloudflare solver الموجود في Provider الأصلي يعتمد على Android WebView مخفي، ولأن `loadExtractor` في Cloudstream غير موجود داخل AniTV. لم يتم اعتبار صفحة embed العادية رابطاً native مؤكداً، ولا توجد ادعاءات بدعم كامل للجودة أو subtitles لهذا المصدر.

## YouTube

يستخدم الـProvider الجديد صفحة YouTube وبيانات `ytInitialData` لاستخراج نتائج البحث والترندات، مع دعم renderers متعددة مثل `videoRenderer` و`gridVideoRenderer` و`compactVideoRenderer`. وتُقرأ تفاصيل الفيديو من `ytInitialPlayerResponse` مع fallback إلى Open Graph metadata.

في التشغيل، تُجمع الصيغ progressive التي تحتوي على `url` مباشر، وتُحوّل جودة الفيديو إلى `direct_stream_urls`. يمرر AniTV روابط الجودة إلى مشغله الحالي، الذي يرتبها رقمياً ويختار الأعلى. لم يُنفذ DASH المحلي أو NewPipe أو Innertube continuation المتقدم أو subtitles لأن ذلك يتطلب Android bridge أو عقد مشغل أوسع من العقد الحالي.

## مسار التشغيل

```text
Extension Provider
  ↓
ContentSource maps
  ↓
SourceRegistry.streams()
  ↓
stream_url / direct_stream_urls / headers
  ↓
VideoPlayerScreen
  ↓
video_player / Chewie
```

يدعم المشغل الحالي روابط MP4 وM3U8 والروابط المباشرة التي يسمح بها `SourceRegistry`. أما الروابط التي تحتاج Cloudstream extractor أو DASH مع headers لكل BaseURL أو subtitles خارجية، فتحتاج مرحلة لاحقة قبل إعلان الدعم الكامل.

## واجهة المستخدم

أضيف قسم `extensions` إلى `AppSection`، وأضيف عنصر **الإضافات** إلى القائمة الجانبية. تفتح الصفحة المصدر المختار باستخدام `SourceContentScreen` الموجودة، ولا تستخدم WebView كصفحة المصدر الأساسية. لا تحتوي البطاقات على زر Test Source أو أدوات Debug.

## الاختبارات والتحقق

أضيفت اختبارات تتحقق من وجود Providers الثلاثة ومن توجيه روابط Anime Witcher وEgyDead وYouTube عبر `SourceRegistry`. تم تنفيذ `git diff --check` بنجاح، ودُفع الالتزام التالي إلى الفرع `main`:

`7d68e59 feat: add extensions system with Anime Witcher, EgyDead and YouTube`

بدأ GitHub Actions تشغيل فحصي `Android Build and Verify` و`Function Quality` على هذا الالتزام. لم يكن Flutter مثبتاً في بيئة العمل المحلية، لذلك لم يتم تشغيل `flutter analyze` أو `flutter test` محلياً.

## حدود المرحلة التالية

يتطلب الوصول إلى parity كامل مع Cloudstream تنفيذ Android bridge لـNewPipe/YouTube وCloudflare solver لـEgyDead، أو إعادة كتابة extractors المقابلة بـDart. كما يحتاج دعم subtitles وDASH إلى توسيع عقد `VideoPlayerScreen` بعناية، دون كسر مصادر AniTV الحالية.

## References

[1]: https://github.com/Abodabodd/re-3arabi "المستودع الأصلي لإضافات Cloudstream"
[2]: https://raw.githubusercontent.com/Abodabodd/re-3arabi/refs/heads/main/repo.json "بيانات مستودع re-3arabi"
[3]: https://github.com/anitv-official/Ani-TV "مستودع AniTV"
[4]: https://firestore.googleapis.com/v1/projects/animewitcher-1c66d/databases/(default)/documents/Settings/constants "إعدادات Anime Witcher العامة"
[5]: https://www.youtube.com "موقع YouTube وبيانات صفحات الفيديو"
[6]: https://tv10.egydead.live/ "موقع EgyDead الحالي"
