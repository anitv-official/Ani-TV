# AniTV Username Login Function

هذه هي Appwrite Cloud Function المسؤولة عن تسجيل الدخول باستخدام `username + password` دون كشف البريد الإلكتروني للتطبيق ودون تخزين كلمة المرور.

## الملفات

- Entrypoint: `src/main.js`
- Runtime: **Node.js 22**
- Function ID الحالي في التطبيق: `6aa5ed04000f66117651`

## Environment Variables

أضف القيم التالية إلى إعدادات Function في Appwrite Cloud. لا تضع `APPWRITE_API_KEY` في Flutter أو GitHub:

| Variable | القيمة |
|---|---|
| `APPWRITE_ENDPOINT` | `https://nyc.cloud.appwrite.io/v1` |
| `APPWRITE_PROJECT_ID` | `6aa4295900094d600163` |
| `APPWRITE_API_KEY` | API key server-side بصلاحيات `databases.read`, `databases.write`, `users.read`, `users.write`, `files.write`, و`sessions.write` فقط |
| `APPWRITE_DATABASE_ID` | `6aa58db9001a5f53312d` |
| `APPWRITE_PROFILES_TABLE_ID` | `6aa58dec001acc5ce962` |
| `APPWRITE_FAVORITES_TABLE_ID` | `6aa58e3a003b23556872` |
| `APPWRITE_PROFILE_IMAGES_BUCKET_ID` | `6aa592fc0003195a524b` |

لا تسجل كلمة المرور أو قيم الطلب في logs. الـAPI key يجب أن يبقى Secret داخل Appwrite Function.

## الربط مع Appwrite Cloud

1. افتح Function باسم `Username Login` ومعرف `6aa5ed04000f66117651`.
2. اختر Runtime: Node.js 22.
3. اجعل Entrypoint هو `src/main.js`.
4. ارفع محتويات هذا المجلد كـsource/deployment.
5. أضف Environment Variables السابقة.
6. فعّل HTTP execution للتطبيق، واضبط صلاحية التنفيذ للمستخدمين الضيوف (`Any`) لأن تسجيل الدخول وفحص Username عامان. مسار حذف الحساب يرفض أي طلب لا يحتوي على `x-appwrite-user-id` مطابقًا لـ`userId`، لذلك لا يمكن استدعاؤه من جلسة غير مصادق عليها.
7. تأكد أن أعمدة Profiles هي `userId`, `username`, `profileImageId`, و`updatedAt`، وأن قيمة `userId` داخل بيانات الـDocument تطابق Appwrite User `$id`.
8. اضبط `APPWRITE_USERNAME_LOGIN_FUNCTION_ID=username-login` عند بناء Flutter إن كان معرف Function مختلفًا.

## البروتوكول

Request body:

```json
{"username":"lord_48291","password":"..."}
```

لفحص توفر Username قبل التسجيل، يستخدم التطبيق نفس Function بطلب عام لا يتضمن كلمة مرور:

```json
{"action":"check_username","username":"lord_48291"}
```

وتعيد Function:

```json
{"ok":true,"available":true}
```

يمكن إرسال `currentDocumentId` عند تغيير Username لاستثناء صف المستخدم نفسه من نتيجة «مأخوذ». هذا الفحص يتم بصلاحية الخادم داخل Function لأن Profiles Table خاصة ولا ينبغي فتح قراءتها للضيوف.

### حذف الحساب

يستخدم التطبيق نفس الـFunction بطلب متزامن:

```json
{"action":"delete_account","userId":"current-user-id","password":"..."}
```

لا تثق Function في `userId` وحده؛ يجب أن يرسله Appwrite Runtime أيضًا في `x-appwrite-user-id`، ويجب أن تتطابق القيمتان. بعد إعادة التحقق من كلمة المرور، تتحقق Function من ملكية Profile وFavorites وتحذف صورة الملف التابعة للمستخدم والمفضلة والـProfile ثم تحذف Appwrite User عبر Server SDK. العملية قابلة لإعادة المحاولة، ولا تسجل كلمة المرور أو Tokens. حسابات Google/OAuth التي لا تملك كلمة مرور محلية تُرفض بأمان حتى يتوفر مسار إعادة تحقق OAuth.

نجاح:

```json
{"ok":true,"userId":"...","secret":"...","expire":"..."}
```

تبحث Function في بيانات الـDocuments وتطبّع `username` محليًا لأن `Query.equal` حساس لحالة الأحرف، ثم تقرأ `profile.data.userId` (وليس خاصية أعلى من Document). بعد ذلك يتحقق Appwrite من كلمة المرور عبر `Account.createEmailPasswordSession` باستخدام البريد الداخلي للمستخدم، وتعيد Function `userId + secret` فقط. يستخدم التطبيق القيمتين مع `account.createSession` ثم يحمّل الملف الشخصي والمفضلة من Appwrite. لا تُعاد قيمة البريد الإلكتروني.

فشل اسم المستخدم أو كلمة المرور يعيد نفس الرسالة العامة `Invalid username or password.` لتقليل كشف الحسابات.
