import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/src/enums.dart' show HttpMethod, OAuthProvider;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

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
  static const String usernameLoginFunctionId = '6aa5ed04000f66117651';
  static const String usernameLoginEndpoint = 'https://anitv-username-login.nyc.appwrite.run';

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
    } catch (error) {
      // The account was already created. Keep that truth visible to the UI
      // instead of turning a post-create session failure into registration
      // failure or deleting the newly-created account.
      throw AccountCreatedButSessionUnavailableException(error);
    }
  }

  Future<models.User> login({required String email, required String password}) async {
    await account.createEmailPasswordSession(email: email.trim(), password: password);
    return account.get();
  }

  Future<models.User> loginWithGoogle() async {
    final callback = await account.createOAuth2Token(
      provider: OAuthProvider.google,
      success: 'appwrite-callback-6aa4295900094d600163://auth/success',
      failure: 'appwrite-callback-6aa4295900094d600163://auth/failure',
    );
    final uri = callback is Uri ? callback : Uri.tryParse(callback.toString());
    final userId = uri?.queryParameters['userId'] ?? '';
    final secret = uri?.queryParameters['secret'] ?? '';
    if (userId.isEmpty || secret.isEmpty) {
      throw GoogleAuthException(
        uri?.queryParameters['error'] == 'access_denied' ? 'CANCELLED' : 'INVALID_CALLBACK',
      );
    }
    await account.createSession(userId: userId, secret: secret);
    return account.get();
  }

  Future<models.User> loginWithUsername({required String username, required String password}) async {
    final normalized = username.trim().toLowerCase();
    late http.Response response;
    try {
      response = await http.post(
        Uri.parse(usernameLoginEndpoint),
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'username': normalized, 'password': password}),
      );
    } on Exception {
      throw const UsernameLoginException('SERVER_ERROR');
    }

    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw UsernameLoginException(response.statusCode >= 400 ? 'SERVER_ERROR' : 'SERVER_ERROR');
    }
    if (body is! Map) throw const UsernameLoginException('SERVER_ERROR');
    final code = body['code']?.toString();
    if (response.statusCode < 200 || response.statusCode >= 300 || body['ok'] != true) {
      throw UsernameLoginException(code ?? (response.statusCode == 401 ? 'INVALID_CREDENTIALS' : 'SERVER_ERROR'));
    }

    final userId = body['userId']?.toString() ?? '';
    final secret = body['secret']?.toString() ?? '';
    if (userId.isEmpty || secret.isEmpty) throw const UsernameLoginException('SERVER_ERROR');

    // The Function already created the user's Appwrite session. Install its
    // session secret on the client; do not call createSession a second time.
    client.setSession(secret);
    try {
      return await account.get();
    } catch (_) {
      client.setSession('');
      rethrow;
    }
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
    final rows = await _listProfileRows();
    final matches = rows.where((row) => row['userId']?.toString() == userId);
    return matches.isEmpty ? null : _profileRowToDocument(matches.first);
  }

  String normalizeUsername(String value) => value.trim().toLowerCase();

  models.Document _profileRowToDocument(Map<String, dynamic> row) {
    return models.Document.fromMap({
      ...row,
      r'$collectionId': profilesTableId,
      r'$databaseId': databaseId,
      r'$permissions': row[r'$permissions'] ?? <String>[],
    });
  }

  Future<List<Map<String, dynamic>>> _listProfileRows() async {
    final response = await client.call(
      HttpMethod.get,
      path: '/tablesdb/$databaseId/tables/$profilesTableId/rows',
      params: const {'queries': ['limit(5000)']},
    );
    final body = response.data;
    if (body is! Map || body['rows'] is! List) {
      throw const FormatException('Invalid profile rows response');
    }
    return (body['rows'] as List)
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

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
      final existingUsername = normalizeUsername((existing.data['username'] ?? '').toString());
      if (existingUsername.isEmpty && normalized.isNotEmpty) {
        if (!await isUsernameAvailable(normalized, currentDocumentId: existing.$id)) {
          throw const UsernameTakenException();
        }
        return updateProfile(documentId: existing.$id, username: normalized);
      }
      if (normalized.isNotEmpty && existingUsername != normalized) {
        throw const UsernameTakenException();
      }
      return existing;
    }
    // A normalized document ID makes creation a server-side atomic claim for
    // new profiles: Lord, lord and LORD cannot claim separate IDs.
    final documentId = normalized.isNotEmpty ? normalized : ID.unique();
    if (normalized.isNotEmpty && !await isUsernameAvailable(normalized)) {
      throw const UsernameTakenException();
    }
    try {
      final response = await client.call(
        HttpMethod.post,
        path: '/tablesdb/$databaseId/tables/$profilesTableId/rows',
        params: {
          'rowId': documentId,
          'data': {
            'userId': userId,
            'username': normalized,
            'displayName': displayName.trim(),
            'email': email.trim(),
            'birthDate': birthDate,
            'country': country,
            'profileImageId': '',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
        },
      );
      final body = response.data;
      if (body is! Map) throw const FormatException('Invalid profile row response');
      return _profileRowToDocument(Map<String, dynamic>.from(body));
    } on AppwriteException catch (error) {
      if (error.code == 409 || (error.type ?? '').contains('duplicate')) {
        throw const UsernameTakenException();
      }
      rethrow;
    }
  }

  Future<models.Document> updateProfile({required String documentId, required String username, String? profileImageId}) async {
    final response = await client.call(
      HttpMethod.patch,
      path: '/tablesdb/$databaseId/tables/$profilesTableId/rows/$documentId',
      params: {
        'data': {
          'username': normalizeUsername(username),
          if (profileImageId != null) 'profileImageId': profileImageId,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      },
    );
    final body = response.data;
    if (body is! Map) throw const FormatException('Invalid profile row response');
    return _profileRowToDocument(Map<String, dynamic>.from(body));
  }

  Future<bool> isUsernameAvailable(String username, {String? currentDocumentId}) async {
    final value = normalizeUsername(username);
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(value)) return false;
    // Read all bounded profile records and compare normalized values locally.
    // This also detects legacy records that were saved with uppercase letters.
    final rows = await _listProfileRows();
    return !rows.any((row) =>
      normalizeUsername((row['username'] ?? '').toString()) == value && row[r'$id'] != currentDocumentId);
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
  if (error is GoogleAuthException) {
    return error.code == 'CANCELLED'
        ? 'تم إلغاء تسجيل الدخول باستخدام Google.'
        : 'تعذر تسجيل الدخول باستخدام Google. تحقق من اتصال الإنترنت وحاول مرة أخرى.';
  }
  if (error is AccountCreatedButSessionUnavailableException) {
    return 'تم إنشاء الحساب، لكن تعذر تسجيل الدخول تلقائيًا. سجّل الدخول باستخدام بياناتك.';
  }
  if (error is UsernameTakenException) return 'اسم المستخدم مأخوذ بالفعل';
  if (error is UsernameLoginException) {
    switch (error.code) {
      case 'INVALID_CREDENTIALS': return 'بيانات الدخول غير صحيحة.';
      case 'INVALID_INPUT': return 'تحقق من البيانات المدخلة.';
      case 'PROFILE_ERROR':
      case 'USER_ERROR':
      case 'SESSION_ERROR':
      case 'SERVER_ERROR': return 'حدث خطأ في الخادم. حاول مرة أخرى.';
      default: return 'حدث خطأ في الخادم. حاول مرة أخرى.';
    }
  }
  if (error is AppwriteException) {
    switch (error.code) {
      case 401: return registering ? 'تعذر إنشاء الحساب بالبيانات المدخلة.' : 'البريد الإلكتروني أو كلمة المرور غير صحيحة.';
      case 404: return registering ? 'تعذر إنشاء الحساب بالبيانات المدخلة.' : 'لم يتم العثور على حساب بهذا البريد الإلكتروني.';
      case 409: return registering ? 'هذا البريد الإلكتروني مستخدم بالفعل. جرّب تسجيل الدخول أو استخدم بريدًا آخر.' : 'بيانات الدخول غير صحيحة.';
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

class UsernameLoginException implements Exception {
  final String code;
  const UsernameLoginException(this.code);
}

class AccountCreatedButSessionUnavailableException implements Exception {
  final Object cause;
  const AccountCreatedButSessionUnavailableException(this.cause);
}

class GoogleAuthException implements Exception {
  final String code;
  const GoogleAuthException(this.code);
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
