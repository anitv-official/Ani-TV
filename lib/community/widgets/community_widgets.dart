import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme/app_theme.dart';
import '../models/community_models.dart';
import '../services/community_media_cache.dart';
import '../../services/appwrite_service.dart';

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.size = 16});
  final double size;
  @override
  Widget build(BuildContext context) => Icon(Icons.verified_rounded,
      size: size, color: AppTheme.primaryColor, semanticLabel: 'موثق');
}

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar(
      {super.key,
      required this.author,
      this.radius = 24,
      this.onTap,
      this.avatarFuture,
      this.showAddBadge = false});
  final PostAuthor author;
  final double radius;
  final VoidCallback? onTap;
  final Future<Uint8List>? avatarFuture;
  final bool showAddBadge;
  static final Map<String, Future<Uint8List>> _imageCache = {};
  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.primaryColor.withOpacity(.16),
        child: Text(
            (author.label.isEmpty ? '?' : author.label.substring(0, 1))
                .toUpperCase(),
            style: TextStyle(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w900,
                fontSize: radius * .65)));
    final resolvedFuture = avatarFuture ??
        (author.avatarPath == null || author.avatarPath!.isEmpty
            ? null
            : (_imageCache[author.avatarPath!] ??= AppwriteService.instance
                .profileImageBytes(author.avatarPath!)));
    Widget avatar = resolvedFuture == null
        ? fallback
        : FutureBuilder<Uint8List>(
            future: resolvedFuture,
            builder: (_, snapshot) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                switchInCurve: Curves.easeOut,
                child: snapshot.hasData
                    ? CircleAvatar(
                        key: const ValueKey('profile-image'),
                        radius: radius,
                        backgroundImage: MemoryImage(snapshot.data!),
                        backgroundColor:
                            AppTheme.primaryColor.withOpacity(.16))
                    : SizedBox(key: const ValueKey('profile-fallback'), child: fallback)));
    final content = showAddBadge
        ? Stack(clipBehavior: Clip.none, children: [
            avatar,
            Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                    width: radius * .55,
                    height: radius * .55,
                    decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: AppTheme.backgroundColor, width: 2)),
                    child: Icon(Icons.person_add_alt_1_rounded,
                        size: radius * .32, color: Colors.white)))
          ])
        : avatar;
    return Semantics(
        label: author.label,
        button: onTap != null,
        child: InkWell(
            onTap: onTap, customBorder: const CircleBorder(), child: content));
  }
}

class CommunityPostItem extends StatelessWidget {
  const CommunityPostItem(
      {super.key,
      required this.post,
      required this.onLike,
      required this.onComment,
      required this.onProfile,
      required this.onShare,
      this.canDelete = false,
      this.onDelete});
  final CommunityPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onProfile;
  final VoidCallback onShare;
  final bool canDelete;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 14),
        Row(children: [
          CommunityAvatar(author: post.author, onTap: onProfile),
          const SizedBox(width: 10),
          Expanded(
              child: InkWell(
                  onTap: onProfile,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Flexible(
                              child: Text(post.author.displayName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800))),
                          if (post.author.isVerified) ...[
                            const SizedBox(width: 4),
                            const VerifiedBadge(size: 15)
                          ]
                        ]),
                        const SizedBox(height: 2),
                        Text(
                            '@${post.author.username} • ${_relative(post.createdAt)}',
                            style: const TextStyle(
                                color: AppTheme.textMutedColor, fontSize: 11))
                      ]))),
          IconButton(
              onPressed: () => _showPostMenu(context),
              icon: const Icon(Icons.more_horiz_rounded,
                  color: AppTheme.textSecondaryColor),
              tooltip: 'المزيد')
        ]),
        if (post.text.trim().isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(post.text,
                  style: const TextStyle(
                      color: Colors.white, height: 1.55, fontSize: 15))),
        if (post.hasImage) ...[
          const SizedBox(height: 12),
          _PostImage(
              media:
                  post.media.firstWhere((item) => item.type == MediaType.image))
        ],
        if (post.link?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 10),
          _PostLink(url: post.link!)
        ],
        if (post.hasAudio) ...[
          const SizedBox(height: 10),
          _MockAudioPlayer(
              media:
                  post.media.firstWhere((item) => item.type == MediaType.audio))
        ],
        const SizedBox(height: 8),
        Row(children: [
          _ActionButton(
              icon: post.likedByMe
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              label: '${post.likeCount}',
              color: post.likedByMe
                  ? Colors.redAccent
                  : AppTheme.textSecondaryColor,
              onTap: onLike),
          _ActionButton(
              icon: Icons.mode_comment_outlined,
              label: '${post.commentCount}',
              onTap: onComment),
          _ActionButton(
              icon: Icons.share_outlined, label: 'مشاركة', onTap: onShare)
        ]),
        const SizedBox(height: 14),
        const Divider(height: 1, color: AppTheme.borderColor),
      ]));

  void _showPostMenu(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      showDragHandle: true,
      builder: (_) => SafeArea(
              child: Wrap(children: [
            ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('نسخ النص'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: post.text));
                  Navigator.pop(context);
                }),
            ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: const Text('الإبلاغ'),
                onTap: () => Navigator.pop(context)),
            if (canDelete)
              ListTile(
                  leading: const Icon(Icons.delete_outline_rounded,
                      color: Colors.redAccent),
                  title: const Text('حذف المنشور'),
                  onTap: () {
                    Navigator.pop(context);
                    onDelete?.call();
                  })
          ])));
}

class _PostImage extends StatefulWidget {
  const _PostImage({required this.media});
  final PostMedia media;
  @override
  State<_PostImage> createState() => _PostImageState();
}

class _PostImageState extends State<_PostImage> {
  Future<File>? cachedFile;

  @override
  void initState() {
    super.initState();
    cachedFile = CommunityMediaCache.instance.get(widget.media);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
        future: cachedFile,
        builder: (_, snapshot) => snapshot.hasData
            ? _image(snapshot.data!.path)
            : snapshot.hasError
                ? const _MediaError()
                : const SizedBox(
                    height: 220,
                    child: Center(child: CircularProgressIndicator())));
  }

  Widget _image(String path) {
    final image = path.startsWith('http')
        ? Image.network(path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _MediaError())
        : Image.file(File(path),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const _MediaError());
    return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
            aspectRatio: 1.45,
            child: InkWell(
                onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                        backgroundColor: Colors.black,
                        insetPadding: const EdgeInsets.all(12),
                        child: InteractiveViewer(child: image))),
                child: image)));
  }
}

class _MediaError extends StatelessWidget {
  const _MediaError();
  @override
  Widget build(BuildContext context) => const ColoredBox(
      color: AppTheme.surfaceColor,
      child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: AppTheme.textMutedColor, size: 40)));
}

class _PostLink extends StatelessWidget {
  const _PostLink({required this.url});
  final String url;
  @override
  Widget build(BuildContext context) => InkWell(
      onTap: () => launchUrl(Uri.tryParse(url) ?? Uri(),
          mode: LaunchMode.externalApplication),
      borderRadius: BorderRadius.circular(12),
      child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderColor)),
          child: Row(children: [
            const Icon(Icons.link_rounded, color: Colors.greenAccent),
            const SizedBox(width: 10),
            Expanded(
                child: Text(url,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.greenAccent, height: 1.35))),
            const Icon(Icons.open_in_new_rounded,
                size: 18, color: Colors.greenAccent)
          ])));
}

class _MockAudioPlayer extends StatefulWidget {
  const _MockAudioPlayer({required this.media});
  final PostMedia media;
  @override
  State<_MockAudioPlayer> createState() => _MockAudioPlayerState();
}

class _MockAudioPlayerState extends State<_MockAudioPlayer> {
  final player = AudioPlayer();
  Future<File>? cachedFile;
  bool loading = false;

  @override
  void initState() {
    super.initState();
    cachedFile = CommunityMediaCache.instance.get(widget.media);
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  Future<void> toggle() async {
    try {
      if (player.playing) {
        await player.pause();
        return;
      }
      setState(() => loading = true);
      final source = await cachedFile!;
      await player.setFilePath(source.path);
      await player.play();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تعذر تشغيل المقطع الصوتي.')));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing == true;
        return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.borderColor)),
            child: Row(children: [
              IconButton(
                  onPressed: loading ? null : toggle,
                  icon: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator())
                      : Icon(
                          playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: AppTheme.primaryColor),
                  tooltip: playing ? 'إيقاف مؤقت' : 'تشغيل'),
              Expanded(
                  child: Column(children: [
                StreamBuilder<Duration>(
                    stream: player.positionStream,
                    builder: (_, position) => LinearProgressIndicator(
                        value: (player.duration?.inMilliseconds ??
                                    widget.media.duration.inMilliseconds) ==
                                0
                            ? 0
                            : (position.data ?? Duration.zero).inMilliseconds /
                                (player.duration ?? widget.media.duration)
                                    .inMilliseconds,
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(4),
                        color: AppTheme.primaryColor,
                        backgroundColor: AppTheme.borderColor)),
                const SizedBox(height: 5),
                Row(children: [
                  Text(_duration(player.position),
                      style: const TextStyle(
                          color: AppTheme.textMutedColor, fontSize: 11)),
                  const Spacer(),
                  Text(_duration(widget.media.duration),
                      style: const TextStyle(
                          color: AppTheme.textMutedColor, fontSize: 11))
                ])
              ]))
            ]));
      });
}

class _ActionButton extends StatelessWidget {
  const _ActionButton(
      {required this.icon,
      required this.label,
      required this.onTap,
      this.color});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? AppTheme.textSecondaryColor;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 19, color: foreground),
              const SizedBox(width: 5),
              Text(label,
                  style: TextStyle(
                      color: foreground,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

String _duration(Duration value) =>
    '${value.inMinutes.remainder(60).toString().padLeft(2, '0')}:${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';
String _relative(DateTime value) {
  final delta = DateTime.now().difference(value);
  if (delta.inMinutes < 1) return 'الآن';
  if (delta.inMinutes < 60) return 'منذ ${delta.inMinutes} د';
  if (delta.inHours < 24) return 'منذ ${delta.inHours} س';
  return 'منذ ${delta.inDays} ي';
}

class CommunityEmptyState extends StatelessWidget {
  const CommunityEmptyState(
      {super.key, required this.title, required this.subtitle, this.onRetry});
  final String title;
  final String subtitle;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.forum_outlined,
                color: AppTheme.primaryColor, size: 52),
            const SizedBox(height: 14),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textSecondaryColor, height: 1.45)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(
                  onPressed: onRetry, child: const Text('إعادة المحاولة')),
            ],
          ],
        ),
      ),
    );
  }
}
