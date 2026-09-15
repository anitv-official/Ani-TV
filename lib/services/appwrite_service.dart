import 'dart:convert';
import 'dart:typed_data';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:appwrite/src/enums.dart' show HttpMethod;
import 'package:appwrite/enums.dart' as enums;
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
      messaging = Messaging(client);
  }

  static final AppwriteService instance = AppwriteService._internal();

  static const String _endpoint = 'https://nyc.cloud.appwrite.io/v1';
  static const String _projectId = '6aa4295900094d600163';
  static const String databaseId = '6aa58db9001a5f53312d';
  static const String profilesTableId = '6aa58dec001acc5ce962';
  static const String favoritesTableId = '6aa58e3a003b23556872';
  static const String profileImagesBucketId = '6aa592fc0003195a524b';
  static const String emailVerificationUrl = 'https://anitv-tau.vercel.app/verify-email';
  static const String usernameLoginFunctionId = '6aa5ed04000f66117651';
  static const String usernameLoginEndpoint = 'https://anitv-username-login.nyc.appwrite.run';
  static const String _sessionSecretKey = 'anitv_appwrite_session_secret';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  final Client client = Client();
  late final Account account;
  late final Databases databases;
  late final Storage storage;
  late final Functions functions;
  late final Messaging messaging;

  Future<models.User?> getCurrentUser() async {
    try {
      return await account.get();
    } on AppwriteException catch (error) {
      if (error.code == 401) {
        final saved = await _secureStorage.read(key: _sessionSecretKey);
        if (saved != null && saved.isNotEmpty) {
          try {
            client.setSession(saved);
            return await account.get();
          } on AppwriteException catch (restoreError) {
            if (restoreError.code == 401) await _secureStorage.delete(key: _sessionSecretKey);
          }
        }
        return null;
      }
      rethrow;
    }
  }

  Future<void> _rememberSession(String secret) async {
    if (secret.trim().isNotEmpty) {
      client.setSession(secret);
      await _secureStorage.write(key: _sessionSecretKey, value: secret);
    }
  }

  Future<models.User> register({required String email, required String password, required String name}) async {
    await account.create(userId: ID.unique(), email: email.trim(), password: password, name: name.trim());
    try {
      final session = await account.createEmailPasswordSession(email: email.trim(), password: password);
      await _rememberSession(session.secret);
      return account.get();
    } catch (error) {
      // The account was already created. Keep that truth visible to the UI
      // instead of turning a post-create session failure into registration
      // failure or deleting the newly-created account.
      throw AccountCreatedButSessionUnavailableException(error);
    }
  }

  Future<models.User> login({required String email, required String password}) async {
    final session = await account.createEmailPasswordSession(email: email.trim(), password: password);
    await _rememberSession(session.secret);
    return account.get();
  }

  Future<models.User> loginWithGoogle() async {
    const success = 'appwrite-callback-6aa4295900094d600163://auth/success';
    const failure = 'appwrite-callback-6aa4295900094d600163://auth/failure';
    // SDK 17 opens Google, waits for the Android callback, and completes the
    // Appwrite session before this future returns.
    await account.createOAuth2Session(
      provider: enums.OAuthProvider.google,
      success: success,
      failure: failure,
    );
    try {
      final session = await account.getSession(sessionId: 'current');
      await _rememberSession(session.secret);
    } catch (_) {
      // account.get() below remains the source of truth for OAuth sessions.
    }
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
    await _rememberSession(secret);
    try {
      return await account.get();
    } catch (_) {
      client.setSession('');
      rethrow;
    }
  }

  Future<bool> checkUsernameAvailability(String username, {String? currentDocumentId}) async {
    final normalized = username.trim().toLowerCase();
    if (!RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(normalized)) return false;
    final response = await http.post(
      Uri.parse(usernameLoginEndpoint),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': 'check_username',
        'username': normalized,
        if (currentDocumentId != null && currentDocumentId.isNotEmpty) 'currentDocumentId': currentDocumentId,
      }),
    );
    dynamic body;
    try {
      body = jsonDecode(response.body);
    } catch (_) {
      throw const UsernameAvailabilityException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300 || body is! Map || body['ok'] != true || body['available'] is! bool) {
      throw const UsernameAvailabilityException();
    }
    return body['available'] as bool;
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

  Future<void> logout() async {
    try {
      await account.deleteSession(sessionId: 'current');
    } finally {
      await _secureStorage.delete(key: _sessionSecretKey);
      client.setSession('');
    }
  }

  Future<models.Target> createPushTarget({required String targetId, required String identifier, String? providerId}) => account.createPushTarget(targetId: targetId, identifier: identifier, providerId: providerId);
  Future<models.Target> updatePushTarget({required String targetId, required String identifier}) => account.updatePushTarget(targetId: targetId, identifier: identifier);
  Future<void> deletePushTarget(String targetId) async => await account.deletePushTarget(targetId: targetId);
  Future<void> subscribePushTarget({required String topicId, required String subscriberId, required String targetId}) async {
    await messaging.createSubscriber(topicId: topicId, subscriberId: subscriberId, targetId: targetId);
  }

  /// Delegates account deletion to the existing trusted Appwrite Function.
  /// The Function owns the server key and validates resource ownership.
  Future<void> deleteCurrentAccount({required String password}) async {
    final user = await getCurrentUser();
    if (user == null || user.$id.isEmpty) throw const AccountDeletionException('NO_SESSION');
    if (user.email.trim().isEmpty) throw const AccountDeletionException('NO_EMAIL');

    final execution = await functions.createExecution(
      functionId: usernameLoginFunctionId,
      body: jsonEncode({'action': 'delete_account', 'userId': user.$id, 'password': password}),
      xasync: false,
    );
    Map<String, dynamic> body = const {};
    try {
      final decoded = jsonDecode(execution.responseBody);
      if (decoded is Map) body = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    if (execution.responseStatusCode != 200 || body['ok'] != true) {
      throw AccountDeletionException(body['code']?.toString() ?? 'DELETE_ERROR');
    }
    await _secureStorage.delete(key: _sessionSecretKey);
    client.setSession('');
  }

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
    String? displayName,
    String? birthDate,
    String? country,
  }) async {
    final normalized = normalizeUsername(username);
    final existing = await getProfile(userId);
    if (existing != null) {
      final existingUsername = normalizeUsername((existing.data['username'] ?? '').toString());
      if (existingUsername.isEmpty && normalized.isNotEmpty) {
        if (!await isUsernameAvailable(normalized, currentDocumentId: existing.$id)) {
          throw const UsernameTakenException();
        }
        return updateProfile(documentId: existing.$id, username: normalized, displayName: displayName, birthDate: birthDate, country: country);
      }
      if (normalized.isNotEmpty && existingUsername != normalized) {
        throw const UsernameTakenException();
      }
      if (displayName != null || birthDate != null || country != null) {
        return updateProfile(documentId: existing.$id, username: existingUsername, displayName: displayName, birthDate: birthDate, country: country);
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
            'profileImageId': '',
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
            if (displayName != null) 'displayname': displayName.trim(),
            if (birthDate != null) 'birthdate': birthDate.trim(),
            if (country != null) 'country': country.trim(),
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

  Future<models.Document> updateProfile({required String documentId, required String username, String? profileImageId, String? displayName, String? birthDate, String? country}) async {
    final response = await client.call(
      HttpMethod.patch,
      path: '/tablesdb/$databaseId/tables/$profilesTableId/rows/$documentId',
      params: {
        'data': {
          'username': normalizeUsername(username),
          if (profileImageId != null) 'profileImageId': profileImageId,
          if (displayName != null) 'displayname': displayName.trim(),
          if (birthDate != null) 'birthdate': birthDate.trim(),
          if (country != null) 'country': country.trim(),
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
    return checkUsernameAvailability(value, currentDocumentId: currentDocumentId);
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
    await _assertCurrentUser(userId);
    final result = await databases.listDocuments(databaseId: databaseId, collectionId: favoritesTableId, queries: [Query.equal('userId', userId), Query.limit(5000)]);
    return result.documents;
  }
  Future<models.Document?> findFavorite({required String userId, required String itemId, String? source}) async {
    await _assertCurrentUser(userId);
    final result = await databases.listDocuments(databaseId: databaseId, collectionId: favoritesTableId, queries: [
      Query.equal('userId', userId), Query.equal('itemId', itemId),
      if (source != null && source.isNotEmpty) Query.equal('source', source), Query.limit(1),
    ]);
    return result.documents.isEmpty ? null : result.documents.first;
  }
  Future<models.Document> createFavorite({required String userId, required Map<String, dynamic> data}) async {
    await _assertCurrentUser(userId);
    return databases.createDocument(databaseId: databaseId, collectionId: favoritesTableId, documentId: ID.unique(), data: {'userId': userId, ...data});
  }
  Future<void> deleteFavorite({required String userId, required String documentId}) async {
    await _assertCurrentUser(userId);
    await databases.deleteDocument(databaseId: databaseId, collectionId: favoritesTableId, documentId: documentId);
  }

  Future<void> _assertCurrentUser(String expectedUserId) async {
    final user = await getCurrentUser();
    if (user == null || user.$id != expectedUserId) {
      throw AppwriteException('The requested data does not belong to the current user.', 401);
    }
  }
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

class AccountDeletionException implements Exception {
  final String code;
  const AccountDeletionException(this.code);
}

class UsernameAvailabilityException implements Exception {
  const UsernameAvailabilityException();
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
