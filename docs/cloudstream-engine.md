# CloudStream Engine

يعمل هذا الفرع (`feature/cloudstream-engine`) على نقل تنفيذ إضافات `.cs3` إلى طبقة Android مع إبقاء واجهات AniTV الحالية كما هي. النسخة السابقة محفوظة في الوسم `pre-cloudstream-engine`.

## المرحلة الحالية

توجد قناة `com.anitv.app/cloudstream` وخدمة Flutter مقابلة لها، ويعتمد Android على artifact `com.github.recloudstream.cloudstream:library-android:4.8.0`. ينفذ المحرك حاليًا:

- فحص حجم ملف الإضافة قبل التعامل معه.
- قراءة `manifest.json` من أرشيف CS3.
- التحقق من اسم الإضافة، اسم صنفها، وإصدارها.
- حساب SHA-256 مرة أخرى بعد التنزيل.
- جعل الملف للقراءة فقط قبل تحميله.
- تحميل صنف الإضافة عبر `DexClassLoader` داخل `codeCacheDir` مع عزل مسار الـ Dex المحسّن.
- تسجيل مزودي الإضافة في `APIHolder` ثم تنفيذ `providers` و`search` و`load` و`loadLinks`.
- إرجاع حالة التحميل إلى Flutter بدل إسقاط التطبيق عند غياب توافق CloudStream.

العمليات المتاحة عبر MethodChannel هي `engineInfo` و`listInstalledPlugins` و`inspectPlugin` و`loadPlugin`.

## حد أمني متعمد

ملف CS3 يحتوي كودًا تنفيذيًا، وليس بيانات JSON. لذلك لا يقوم التطبيق بتشغيله لمجرد تنزيله؛ يتم فحصه أولًا، ولا يُسمح إلا بأرشيف ZIP صغير يحتوي Manifest صالحًا. إذا كان ملف الإضافة صحيحًا لكن CloudStream API غير موجودة داخل التطبيق، يعيد المحرك حالة `runtime: unavailable` بدل تنفيذ كود غير متوافق.

## التحقق

يجب أن يثبت GitHub Actions أن artifact يمكنه تجميع مكتبة CloudStream مع AniTV. بعد التثبيت على جهاز Android، يجب تحميل إضافة Faselhd ثم استدعاء `providers` للتأكد من تسجيلها قبل تجربة `search` و`load` و`loadLinks`.
