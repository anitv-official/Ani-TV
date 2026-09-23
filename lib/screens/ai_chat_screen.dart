import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../ai/ai_context_manager.dart';
import '../ai/ai_controller.dart';
import '../ai/ai_models.dart';
import '../ai/ai_tool_registry.dart';
import '../ai/openrouter_service.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';
import 'anime_details_screen.dart';
import 'comic_details_screen.dart';
import 'video_player_screen.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  late final AiController _controller;
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final List<_ChatEntry> _entries = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final contextManager = AiContextManager()..update(screen: 'ai_chat');
    _controller = AiController(
      service: OpenRouterService(),
      registry: AiToolRegistry(),
      contextManager: contextManager,
      appState: context.read<AppStateProvider>(),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _loading) return;
    _input.clear();
    setState(() {
      _entries.add(_ChatEntry.user(text));
      _loading = true;
    });
    final reply = await _controller.ask(text);
    if (!mounted) return;
    setState(() {
      _entries.add(_ChatEntry.ai(reply));
      _loading = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 220), curve: Curves.easeOut);
      }
    });
  }

  void _openItem(Map<String, dynamic> item) {
    final url = item['url']?.toString() ?? '';
    if (url.isEmpty || item['external_only'] == true) return;
    final category =
        (item['category'] ?? item['type'] ?? '').toString().toLowerCase();
    final page = {'comic', 'manga', 'manhwa', 'manhua'}.contains(category)
        ? ComicDetailsScreen(url: url, type: item['type']?.toString())
        : AnimeDetailsScreen(url: url);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _playItem(Map<String, dynamic> item) {
    final url = (item['play_url'] ?? item['stream_url'])?.toString() ?? '';
    if (url.isEmpty) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
                  url: url,
                  title: item['title']?.toString() ??
                      item['name']?.toString() ??
                      'حلقة',
                  episodeId: item['episodeId']?.toString() ?? url,
                )));
  }

  void _executeAction(AiAction action) {
    if (action.type != 'play_episode') return;
    final url = action.payload['url']?.toString() ?? '';
    if (url.isEmpty) return;
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => VideoPlayerScreen(
                  url: url,
                  title: action.payload['title']?.toString() ?? 'حلقة',
                  episodeId: action.payload['episodeId']?.toString() ?? url,
                )));
  }

  @override
  Widget build(BuildContext context) {
    final configured = OpenRouterConfig.fromEnvironment().isConfigured;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(children: [
          _header(),
          if (!configured) _configurationBanner(),
          Expanded(
              child: _entries.isEmpty
                  ? _empty()
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                      itemCount: _entries.length,
                      itemBuilder: (_, index) => _bubble(_entries[index]),
                    )),
          if (_loading) _thinking(),
          _composer(),
        ]),
      ),
    );
  }

  Widget _header() => Container(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [AppTheme.surfaceColor, AppTheme.backgroundColor]),
          border: Border(
              bottom:
                  BorderSide(color: AppTheme.primaryColor.withOpacity(.18))),
        ),
        child: Row(children: [
          IconButton(
              onPressed: () => Navigator.pop(context),
              icon:
                  const Icon(Icons.arrow_forward_rounded, color: Colors.white)),
          const SizedBox(width: 4),
          const AiBrandMark(size: 46),
          const SizedBox(width: 12),
          const Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('مساعد AniTV',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w900)),
                SizedBox(height: 3),
                Text('بحث ذكي • تشغيل مباشر • أغلفة ومعلومات',
                    style: TextStyle(
                        color: AppTheme.textSecondaryColor, fontSize: 11)),
              ])),
          if (_entries.isNotEmpty)
            IconButton(
                onPressed: () => setState(() {
                      _entries.clear();
                      _controller.clear();
                    }),
                icon: const Icon(Icons.delete_sweep_outlined,
                    color: Colors.white54)),
        ]),
      );

  Widget _configurationBanner() => Container(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 2),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
            color: Colors.orange.withOpacity(.11),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(.35))),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.orangeAccent, size: 20),
          SizedBox(width: 9),
          Expanded(
              child: Text(
                  'المساعد يحتاج إعداد مفتاح OpenRouter في نسخة البناء.',
                  style: TextStyle(color: Colors.orangeAccent, fontSize: 12)))
        ]),
      );

  Widget _empty() => Center(
          child: SingleChildScrollView(
              child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AiBrandMark(size: 86),
          const SizedBox(height: 18),
          const Text('ماذا تريد أن تشاهد أو تقرأ؟',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text(
              'سأبحث في AniTV وAniList وأعرض الغلاف والمعلومات والخيارات المناسبة.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: AppTheme.textSecondaryColor,
                  height: 1.5,
                  fontSize: 13)),
          const SizedBox(height: 22),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                'ابحث عن Naruto',
                'آخر حلقة من One Piece',
                'معلومات مانجا Solo Leveling'
              ]
                  .map((text) => ActionChip(
                      label: Text(text),
                      onPressed: () {
                        _input.text = text;
                        _send();
                      },
                      backgroundColor: AppTheme.surfaceColor,
                      labelStyle:
                          const TextStyle(color: Colors.white70, fontSize: 11)))
                  .toList()),
        ]),
      )));

  Widget _thinking() => const Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 7),
      child: Row(children: [
        SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primaryColor)),
        SizedBox(width: 9),
        Text('يبحث في المصادر ويجهز النتائج...',
            style: TextStyle(color: AppTheme.textSecondaryColor, fontSize: 12))
      ]));

  Widget _bubble(_ChatEntry entry) => Align(
        alignment: entry.user
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          constraints: const BoxConstraints(maxWidth: 430),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: entry.user
                ? LinearGradient(colors: [
                    AppTheme.primaryColor.withOpacity(.38),
                    AppTheme.primaryColor.withOpacity(.18)
                  ])
                : LinearGradient(colors: [
                    AppTheme.surfaceColor,
                    AppTheme.surfaceColor.withOpacity(.72)
                  ]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: entry.user
                    ? AppTheme.primaryColor.withOpacity(.55)
                    : AppTheme.borderColor),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (!entry.user) const AiBrandMark(size: 24),
              if (!entry.user) const SizedBox(width: 8),
              Text(entry.user ? 'أنت' : 'AniTV AI',
                  style: TextStyle(
                      color:
                          entry.user ? Colors.white70 : AppTheme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w800))
            ]),
            const SizedBox(height: 7),
            Text(entry.reply?.text ?? entry.text,
                style: TextStyle(
                    color: entry.reply?.isError == true
                        ? Colors.orangeAccent
                        : Colors.white,
                    height: 1.5,
                    fontSize: 14)),
            if (entry.reply?.items.isNotEmpty == true)
              ...entry.reply!.items.take(8).map(_resultCard),
            if (entry.reply?.action != null) _playAction(entry.reply!.action!),
          ]),
        ),
      );

  Widget _resultCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ??
        item['name']?.toString() ??
        item['_ai_message']?.toString() ??
        'نتيجة';
    final cover = item['cover_url']?.toString() ??
        item['poster']?.toString() ??
        item['image']?.toString() ??
        '';
    final description = item['description']?.toString() ?? '';
    final source =
        item['source']?.toString() ?? item['source_id']?.toString() ?? 'AniTV';
    final score =
        item['score']?.toString() ?? item['averageScore']?.toString() ?? '';
    final playUrl =
        item['play_url']?.toString() ?? item['stream_url']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
          color: Colors.black.withOpacity(.16),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(.07))),
      child: InkWell(
          onTap: () => playUrl.isNotEmpty ? _playItem(item) : _openItem(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
              padding: const EdgeInsets.all(9),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _cover(cover, width: 70, height: 96),
                const SizedBox(width: 11),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.2)),
                      const SizedBox(height: 5),
                      Text(source,
                          style: const TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w700)),
                      if (score.isNotEmpty)
                        Text('التقييم: $score',
                            style: const TextStyle(
                                color: AppTheme.textSecondaryColor,
                                fontSize: 10)),
                      if (description.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(description,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                    height: 1.35))),
                      const SizedBox(height: 7),
                      Row(children: [
                        if (playUrl.isNotEmpty)
                          _smallAction(Icons.play_arrow_rounded, 'تشغيل',
                              () => _playItem(item)),
                        if (playUrl.isEmpty &&
                            item['external_only'] != true &&
                            (item['url']?.toString().isNotEmpty ?? false))
                          _smallAction(Icons.open_in_new_rounded, 'فتح',
                              () => _openItem(item))
                      ]),
                    ])),
              ]))),
    );
  }

  Widget _playAction(AiAction action) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
              onPressed: () => _executeAction(action),
              icon: const Icon(Icons.play_circle_fill_rounded),
              label: const Text('تشغيل الحلقة الآن'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13))))));

  Widget _smallAction(IconData icon, String label, VoidCallback onPressed) =>
      Padding(
          padding: const EdgeInsetsDirectional.only(end: 7),
          child: OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 15),
              label: Text(label, style: const TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side:
                      BorderSide(color: AppTheme.primaryColor.withOpacity(.5)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)))));

  Widget _cover(String url, {required double width, required double height}) =>
      ClipRRect(
          borderRadius: BorderRadius.circular(11),
          child: Container(
              width: width,
              height: height,
              color: AppTheme.backgroundColor,
              child: url.isEmpty
                  ? const Icon(Icons.image_outlined,
                      color: Colors.white24, size: 30)
                  : Image.network(url,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white24))));

  Widget _composer() => SafeArea(
      top: false,
      child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(children: [
            Expanded(
                child: TextField(
                    controller: _input,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                        hintText: 'اسأل عن أنمي، مسلسل، فيلم أو مانجا...',
                        hintStyle: const TextStyle(
                            color: AppTheme.textSecondaryColor, fontSize: 12),
                        filled: true,
                        fillColor: AppTheme.surfaceColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                            borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 13)))),
            const SizedBox(width: 8),
            IconButton(
                onPressed: _loading ? null : _send,
                style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(14)),
                icon: const Icon(Icons.arrow_upward_rounded))
          ])));
}

class _ChatEntry {
  final bool user;
  final String text;
  final AiReply? reply;
  const _ChatEntry.user(this.text)
      : user = true,
        reply = null;
  const _ChatEntry.ai(this.reply)
      : user = false,
        text = '';
}

class AiBrandMark extends StatelessWidget {
  final double size;
  const AiBrandMark({super.key, this.size = 42});
  @override
  Widget build(BuildContext context) => Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xff51b7ff),
                Color(0xff2774d8),
                Color(0xff7d4ee8)
              ]),
          boxShadow: [
            BoxShadow(
                color: AppTheme.primaryColor.withOpacity(.35),
                blurRadius: size * .35)
          ]),
      child: Stack(alignment: Alignment.center, children: [
        Text('Ai',
            style: TextStyle(
                color: Colors.white,
                fontSize: size * .34,
                fontWeight: FontWeight.w900,
                letterSpacing: -1)),
        Positioned(
            right: size * .16,
            top: size * .13,
            child: Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: size * .18))
      ]));
}
