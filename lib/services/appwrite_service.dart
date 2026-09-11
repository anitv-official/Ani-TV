import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

/// Shared Appwrite client for AniTV authentication and future Appwrite services.
class AppwriteService {
  AppwriteService._internal() {
    client
      ..setEndpoint(_endpoint)
      ..setProject(_projectId);
    account = Account(client);
  }

  static final AppwriteService instance = AppwriteService._internal();

  static const String _endpoint = 'https://nyc.cloud.appwrite.io/v1';
  static const String _projectId = '6aa4295900094d600163';

  final Client client = Client();
  late final Account account;

  Future<models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } on AppwriteException catch (error) {
      if (error.code == 401) return null;
      rethrow;
    }
  }

  Future<models.User> register({
    required String email,
    required String password,
    required String name,
  }) async {
    await account.create(
      userId: ID.unique(),
      email: email,
      password: password,
      name: name,
    );
    await account.createEmailPasswordSession(email: email, password: password);
    return account.get();
  }

  Future<models.User> login({
    required String email,
    required String password,
  }) async {
    await account.createEmailPasswordSession(email: email, password: password);
    return account.get();
  }

  Future<void> logout() async {
    await account.deleteSession(sessionId: 'current');
  }

  Future<void> ping() async {
    await client.ping();
  }

  Future<models.User> updateName(String name) async {
    return account.updateName(name: name.trim());
  }

  Future<models.User> updatePassword({required String password, required String oldPassword}) async {
    return account.updatePassword(password: password, oldPassword: oldPassword);
  }

  Future<void> sendPasswordRecovery(String email, String redirectUrl) async {
    await account.createRecovery(email: email.trim(), url: redirectUrl);
  }

  Future<models.Token> completePasswordRecovery({
    required String userId,
    required String secret,
    required String password,
  }) async {
    return account.updateRecovery(userId: userId, secret: secret, password: password);
  }
}

String authErrorMessage(Object error, {required bool registering}) {
  if (error is AppwriteException) {
    switch (error.code) {
      case 401:
        return registering
            ? 'تعذر إنشاء الحساب بالبيانات المدخلة.'
            : 'بيانات الدخول غير صحيحة.';
      case 409:
        return 'هذا البريد الإلكتروني مستخدم بالفعل.';
      case 400:
        return registering
            ? 'تحقق من البريد الإلكتروني وكلمة المرور.'
            : 'تحقق من البيانات المدخلة.';
      case 408:
      case 429:
      case 500:
      case 502:
      case 503:
        return 'تعذر الاتصال بالخدمة. تحقق من الإنترنت وحاول مرة أخرى.';
    }
  }
  return registering
      ? 'حدث خطأ أثناء إنشاء الحساب. حاول مرة أخرى.'
      : 'حدث خطأ أثناء تسجيل الدخول. حاول مرة أخرى.';
}

String logoutErrorMessage(Object error) =>
    'تعذر تسجيل الخروج. حاول مرة أخرى.';
