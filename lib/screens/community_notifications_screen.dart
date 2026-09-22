import 'package:flutter/material.dart';
import '../community/models/community_models.dart';
import '../community/services/community_repository_factory.dart';
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
  final repository = CommunityRepositoryFactory.notifications();
  final friends = CommunityRepositoryFactory.friends();
  late Future<List<CommunityNotification>> future;
  @override
  void initState() {
    super.initState();
    future = repository.fetchNotifications();
  }

  Future<void> _respond(String requestId, bool accept) async {
    await friends.respondToRequest(requestId, accept: accept);
    if (mounted) setState(() => future = repository.fetchNotifications());
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
                trailing: item.type == NotificationType.friendRequest &&
                        item.friendRequestId != null
                    ? Wrap(spacing: 4, children: [
                        IconButton(
                            tooltip: 'قبول',
                            onPressed: () =>
                                _respond(item.friendRequestId!, true),
                            icon: const Icon(Icons.check_circle_outline,
                                color: Colors.greenAccent)),
                        IconButton(
                            tooltip: 'رفض',
                            onPressed: () =>
                                _respond(item.friendRequestId!, false),
                            icon: const Icon(Icons.cancel_outlined,
                                color: Colors.redAccent))
                      ])
                    : item.isRead
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
