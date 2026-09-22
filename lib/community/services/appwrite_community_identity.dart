import '../../services/appwrite_service.dart';
import 'community_backend_config.dart';

class AppwriteCommunityIdentity implements CommunityIdentityProvider {
  const AppwriteCommunityIdentity();
  @override
  Future<String?> currentUserId() async {
    final user = await AppwriteService.instance.getCurrentUser();
    return user?.$id;
  }

  Future<String> createJwt() => AppwriteService.instance.createCommunityJwt();
}

/// The client sends no user-id override for protected media operations. A
/// trusted Edge Function validates this JWT against Appwrite and derives the
/// authoritative user ID before touching Supabase metadata.
class AppwriteIdentityBridge {
  const AppwriteIdentityBridge();
  String? validate(String? appwriteUserId) =>
      appwriteUserId == null || appwriteUserId.isEmpty ? null : appwriteUserId;
}
