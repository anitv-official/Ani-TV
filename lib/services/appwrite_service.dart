import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';

/// Shared Appwrite client for authentication and account cloud synchronization.
class AppwriteService {
  AppwriteService._internal() {
    client
      ..setEndpoint(_endpoint)
      ..setProject(_projectId);
    account = Account(client);
    databases = Databases(client);
    storage = Storage(client);
    functions = Functions(client);
  }

  static final AppwriteService instance = AppwriteService._internal();

  static const String _endpoint = 'https://nyc.cloud.appwrite.io/v1';
  static const String _projectId = '6aa4295900094d600163';
  static const String databaseId = '6aa58db9001a5f53312d';
  static const String profilesTableId = '6aa58dec001acc5ce962';
  static const String favoritesTableId = '6aa58e3a003b23556872';
  static const String profileImagesBucketId = '6aa592fc0003195a524b';
  static const String emailVerificationUrl = 'https://anitv-manga-lord.vercel.app/verify-email';
  static const String usernameLoginFunctionId = String.fromEnvironment(
    'APPWRITE_USERNAME_LOGIN_FUNCTION_ID',
    defaultValue: 'username-login',
  );

  final Client client = Client();
  late final Account account;
  late final Databases databases;
  late final Storage storage;
  late final Functions functions;

  Future<models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } on AppwriteException catch (error) {
      if (error.code == 401) return null;
      rethrow;
    }
  }

  Future<models.User> register({required String email, required String password, required String name}) async {
    await account.create(userId: ID.unique(), email: email.trim(), password: password, name: name.trim());
    try {
      await account.createEmailPasswordSession(email: email.trim(), password: password);
      return account.get();
    } catch (_) {
      // Do not leave an unusable authenticated account session behind.
      try { await account.deleteSession(sessionId: 'current'); } catch (_) {}
      rethrow;
    }
  }

  Future<models.User> login({required String email, required String password}) async {
    await account.createEmailPasswordSession(email: email.trim(), password: password);
    return account.get();
  }

  Future<models.User> loginWithUsername({required String username, required String password}) async {
    final normalized = username.trim().toLowerCase();
    final execution = await functions.createExecution(
      functionId: usernameLoginFunctionId,
      body: jsonEncode({'username': normalized, 'password': password}),
      xasync: false,
    );
    dynamic response;
    try { response = jsonDecode(execution.responseBody); } catch (_) { response = null; }
    if (response is! Map || response['ok'] != true) throw Exception('Invalid username or password.');
    final userId = response['userId']?.toString() ?? '';
    final secret = response['secret']?.toString() ?? '';
    if (userId.isEmpty || secret.isEmpty) throw Exception('Invalid username or password.');
    await account.createSession(userId: userId, secret: secret);
    return account.get();
  }

  Future<void> sendEmailVerification() async {
    try {
      await account.createVerification(url: emailVerificationUrl);
    } on AppwriteException catch (error) {
      debugPrint('Appwrite createVerification failed: code=${error.code}, type=${error.type}, message=${error.message}');
      rethrow;
    }
  }

  Future<models.User> confirmEmailVerification({required String userId, required String secret}) async {
    await account.updateVerification(userId: userId, secret: secret);
    return account.get();
  }

  Future<void> logout() async => account.deleteSession(sessionId: 'current');
  Future<void> ping() async => client.ping();
  Future<models.User> updateName(String name) async => account.updateName(name: name.trim());
  Future<models.User> updatePassword({required String password, required String oldPassword}) async => account.updatePassword(password: password, oldPassword: oldPassword);
  Future<void> sendPasswordRecovery(String email, String redirectUrl) async => account.createRecovery(email: email.trim(), url: redirectUrl);
  Future<models.Token> completePasswordRecovery({required String userId, required String secret, required String password}) async => account.updateRecovery(userId: userId, secret: secret, password: password);

  Future<models.Document?> getProfile(String userId) async {
    final result = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: profilesTableId,
      queries: [Query.equal('userId', userId), Query.limit(1)],
    );
    return result.documents.isEmpty ? null : result.documents.first;
  }

  String normalizeUsername(String value) => value.trim().toLowerCase();

  Future<models.Document> ensureProfile({
    required String userId,
    required String username,
    String displayName = '',
    String email = '',
    String birthDate = '',
    String country = '',
  }) async {
    final normalized = normalizeUsername(username);
    final existing = await getProfile(userId);
    if (existing != null) {
      if ((existing.data['username'] ?? '').toString().trim().isEmpty && normalized.isNotEmpty) {
        return updateProfile(documentId: existing.$id, username: normalized);
      }
      return existing;
    }
    // A normalized document ID makes creation a server-side atomic claim for
    // new profiles: Lord, lord and LORD cannot claim separate IDs.
    final documentId = normalized.isNotEmpty ? normalized : ID.unique();
    return databases.createDocument(
      databaseId: databaseId,
      collectionId: profilesTableId,
      documentId: documentId,
      data: {
        'userId': userId,
        'username': normalized,
        'displayName': displayName.trim(),
        'email': email.trim(),
        'birthDate': birthDate,
        'country': country.trim(),
        'profileImageId': '',
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<models.Document> updateProfile({required String documentId, required String username, String? profileImageId}) => databases.updateDocument(
    databaseId: databaseId,
    collectionId: profilesTableId,
    documentId: documentId,
    data: {
      'username': normalizeUsername(username),
      if (profileImageId != null) 'profileImageId': profileImageId,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    },
  );

  Future<bool> isUsernameAvailable(String username, {String? currentDocumentId}) async {
    final value = normalizeUsername(username);
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(value)) return false;
    // Read all bounded profile records and compare normalized values locally.
    // This also detects legacy records that were saved with uppercase letters.
    final result = await databases.listDocuments(
      databaseId: databaseId,
      collectionId: profilesTableId,
      queries: [Query.limit(5000)],
    );
    return !result.documents.any((document) =>
      normalizeUsername((document.data['username'] ?? '').toString()) == value && document.$id != currentDocumentId);
  }

  Future<models.Document> updateUsername({required String documentId, required String username}) => updateProfile(documentId: documentId, username: username);

  Future<String> uploadProfileImage({required String userId, required String path}) async {
    final file = await storage.createFile(
      bucketId: profileImagesBucketId,
      fileId: ID.unique(),
      file: InputFile.fromPath(path: path),
      permissions: [Permission.read(Role.user(userId)), Permission.update(Role.user(userId)), Permission.delete(Role.user(userId))],
    );
    return file.$id;
  }

  Future<Uint8List> profileImageBytes(String fileId) => storage.getFileView(bucketId: profileImagesBucketId, fileId: fileId);
  Future<void> deleteProfileImage(String fileId) async { if (fileId.isNotEmpty) await storage.deleteFile(bucketId: profileImagesBucketId, fileId: fileId); }

  Future<List<models.Document>> getFavorites(String userId) async {
    final result = await databases.listDocuments(databaseId: databaseId, collectionId: favoritesTableId, queries: [Query.equal('userId', userId), Query.limit(5000)]);
    return result.documents;
  }
  Future<models.Document?> findFavorite({required String userId, required String itemId}) async {
    final result = await databases.listDocuments(databaseId: databaseId, collectionId: favoritesTableId, queries: [Query.equal('userId', userId), Query.equal('itemId', itemId), Query.limit(1)]);
    return result.documents.isEmpty ? null : result.documents.first;
  }
  Future<models.Document> createFavorite({required String userId, required Map<String, dynamic> data}) => databases.createDocument(databaseId: databaseId, collectionId: favoritesTableId, documentId: ID.unique(), data: {'userId': userId, ...data});
  Future<void> deleteFavorite(String documentId) => databases.deleteDocument(databaseId: databaseId, collectionId: favoritesTableId, documentId: documentId);
}

String authErrorMessage(Object error, {required bool registering}) {
  if (error is UsernameTakenException) return 'اسم المستخدم مأخوذ بالفعل';
  if (error is AppwriteException) {
    switch (error.code) {
      case 401: return registering ? 'تعذر إنشاء الحساب بالبيانات المدخلة.' : 'بيانات الدخول غير صحيحة.';
      case 409: return registering ? 'هذا البريد الإلكتروني أو اسم المستخدم مستخدم بالفعل.' : 'بيانات الدخول غير صحيحة.';
      case 400: return registering ? 'تحقق من البيانات المدخلة.' : 'تحقق من البيانات المدخلة.';
      case 408:
      case 429:
      case 500:
      case 502:
      case 503: return 'تعذر الاتصال بالخادم، حاول مرة أخرى.';
    }
  }
  return registering ? 'حدث خطأ أثناء إنشاء الحساب. حاول مرة أخرى.' : 'حدث خطأ أثناء تسجيل الدخول. حاول مرة أخرى.';
}

String logoutErrorMessage(Object error) => 'تعذر تسجيل الخروج. حاول مرة أخرى.';

class UsernameTakenException implements Exception {
  const UsernameTakenException();
}

class UsernameValidation {
  static final RegExp pattern = RegExp(r'^[a-z0-9_]{3,24}$');
  static String normalize(String value) => value.trim().toLowerCase();
  static bool isValid(String value) => pattern.hasMatch(normalize(value));
}
