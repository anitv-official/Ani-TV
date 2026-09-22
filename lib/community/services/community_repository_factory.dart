import '../mock/mock_community_repository.dart';
import '../repositories/community_repositories.dart';
import '../repositories/supabase_community_repositories.dart';
import 'appwrite_community_identity.dart';
import 'community_backend_config.dart';
import 'community_media_storage.dart';

class CommunityRepositoryFactory {
  static final CommunityIdentityProvider identity =
      const AppwriteCommunityIdentity();
  static CommunityRepository community() =>
      CommunityBackend.dataSource == CommunityDataSource.supabase &&
              CommunityBackend.isSupabaseConfigured
          ? SupabaseCommunityRepository(identity: identity)
          : MockCommunityRepository();
  static ProfileRepository profile() =>
      CommunityBackend.dataSource == CommunityDataSource.supabase &&
              CommunityBackend.isSupabaseConfigured
          ? SupabaseProfileRepository(identity: identity)
          : MockProfileRepository(MockCommunityRepository());
  static FriendRepository friends() =>
      CommunityBackend.dataSource == CommunityDataSource.supabase &&
              CommunityBackend.isSupabaseConfigured
          ? SupabaseFriendRepository(identity: identity)
          : MockFriendRepository();
  static ChatRepository chat() =>
      CommunityBackend.dataSource == CommunityDataSource.supabase &&
              CommunityBackend.isSupabaseConfigured
          ? SupabaseChatRepository(identity: identity)
          : MockChatRepository();
  static NotificationRepository notifications() =>
      CommunityBackend.dataSource == CommunityDataSource.supabase &&
              CommunityBackend.isSupabaseConfigured
          ? SupabaseNotificationRepository(identity: identity)
          : MockNotificationRepository();
  static VerificationRepository verification() =>
      CommunityBackend.dataSource == CommunityDataSource.supabase &&
              CommunityBackend.isSupabaseConfigured
          ? SupabaseVerificationRepository(identity: identity)
          : MockVerificationRepository();
  static MediaRepository media() =>
      CommunityBackend.dataSource == CommunityDataSource.supabase &&
              CommunityBackend.isSupabaseConfigured
          ? SupabaseMediaRepository(identity: identity)
          : BackblazeMediaRepository();
  static ShareRepository share() =>
      CommunityBackend.dataSource == CommunityDataSource.supabase &&
              CommunityBackend.isSupabaseConfigured
          ? SupabaseShareRepository()
          : MockShareRepository();
}
