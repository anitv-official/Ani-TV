import 'package:flutter/material.dart';
import '../community/mock/mock_community_repository.dart';
import '../community/models/community_models.dart';
import '../community/widgets/community_widgets.dart';
import '../l10n/community_strings.dart';
import '../theme/app_theme.dart';

class CommunityNotificationsScreen extends StatefulWidget {
  const CommunityNotificationsScreen({super.key});
  @override
  State<CommunityNotificationsScreen> createState() =>
      _CommunityNotificationsScreenState();
}

class _CommunityNotificationsScreenState
    extends State<CommunityNotificationsScreen> {
  final repository = MockNotificationRepository();
  late Future<List<CommunityNotification>> future;
  @override
  void initState() {
    super.initState();
    future = repository.fetchNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.communityStrings;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(title: Text(strings.notifications)),
      body: FutureBuilder<List<CommunityNotification>>(
        future: future,
        builder: (_, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          final items = snapshot.data!;
          if (items.isEmpty)
            return CommunityEmptyState(
                title: strings.noNotifications,
                subtitle: strings.noNotificationsHint);
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, indent: 78, color: AppTheme.borderColor),
            itemBuilder: (_, index) {
              final item = items[index];
              final icon = item.type == NotificationType.friendRequest
                  ? Icons.person_add_alt_1_rounded
                  : item.type == NotificationType.comment
                      ? Icons.mode_comment_outlined
                      : Icons.favorite_border_rounded;
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: CircleAvatar(
                    backgroundColor: AppTheme.primaryColor.withOpacity(.16),
                    child: Icon(icon,
                        color: AppTheme.primaryColor,
                        semanticLabel: item.title)),
                title: Text(item.title,
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            item.isRead ? FontWeight.w500 : FontWeight.w800)),
                subtitle: Text(item.body,
                    style: const TextStyle(color: AppTheme.textSecondaryColor)),
                trailing: item.isRead
                    ? null
                    : const Icon(Icons.circle,
                        size: 9, color: AppTheme.primaryColor),
              );
            },
          );
        },
      ),
    );
  }
}
