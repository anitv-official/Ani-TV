import '../../services/appwrite_service.dart';
import 'community_backend_config.dart';

class AppwriteCommunityIdentity implements CommunityIdentityProvider {
  const AppwriteCommunityIdentity();
  @override
  Future<String?> currentUserId() async {
    final user = await AppwriteService.instance.getCurrentUser();
    return user?.$id;
  }
}

/// The client sends no user-id override to RLS. A trusted server/Edge Function
/// must mint a JWT containing `appwrite_user_id` before protected writes work.
class AppwriteIdentityBridge {
  const AppwriteIdentityBridge();
  String? validate(String? appwriteUserId) =>
      appwriteUserId == null || appwriteUserId.isEmpty ? null : appwriteUserId;
}
