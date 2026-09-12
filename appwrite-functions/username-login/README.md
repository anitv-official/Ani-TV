# AniTV Username Login Function

هذه هي Appwrite Cloud Function المسؤولة عن تسجيل الدخول باستخدام `username + password` دون كشف البريد الإلكتروني للتطبيق ودون تخزين كلمة المرور.

## الملفات

- Entrypoint: `src/main.js`
- Runtime: **Node.js 22**
- Function ID المقترح: `username-login`

## Environment Variables

أضف القيم التالية إلى إعدادات Function في Appwrite Cloud. لا تضع `APPWRITE_API_KEY` في Flutter أو GitHub:

| Variable | القيمة |
|---|---|
| `APPWRITE_ENDPOINT` | `https://nyc.cloud.appwrite.io/v1` |
| `APPWRITE_PROJECT_ID` | `6aa4295900094d600163` |
| `APPWRITE_API_KEY` | API key server-side بصلاحيات `databases.read` و`users.read` و`sessions.write` فقط |
| `APPWRITE_DATABASE_ID` | `6aa58db9001a5f53312d` |
| `APPWRITE_PROFILES_TABLE_ID` | `6aa58dec001acc5ce962` |

لا تسجل كلمة المرور أو قيم الطلب في logs. الـAPI key يجب أن يبقى Secret داخل Appwrite Function.

## الربط مع Appwrite Cloud

1. أنشئ Function باسم `Username Login` بمعرف `username-login`.
2. اختر Runtime: Node.js 22.
3. اجعل Entrypoint هو `src/main.js`.
4. ارفع محتويات هذا المجلد كـsource/deployment.
5. أضف Environment Variables السابقة.
6. فعّل HTTP execution للتطبيق، واضبط صلاحية التنفيذ للمستخدمين الضيوف (`Any`) لأن التحقق يتم داخل Function. لا تمنح Function صلاحيات كتابة قاعدة البيانات أو إدارة المستخدمين.
7. تأكد أن `username_unique` موجود على Profiles وأن `userId` يطابق Appwrite User ID.
8. اضبط `APPWRITE_USERNAME_LOGIN_FUNCTION_ID=username-login` عند بناء Flutter إن كان معرف Function مختلفًا.

## البروتوكول

Request body:

```json
{"username":"lord_48291","password":"..."}
```

نجاح:

```json
{"ok":true,"userId":"...","secret":"...","expire":"..."}
```

يستخدم التطبيق `userId + secret` مع Appwrite Client SDK عبر `account.createSession`، ثم يعيد تحميل بيانات الحساب والمفضلة كالمعتاد. لا تُعاد قيمة البريد الإلكتروني.

فشل اسم المستخدم أو كلمة المرور يعيد نفس الرسالة العامة `Invalid username or password.` لتقليل كشف الحسابات.
