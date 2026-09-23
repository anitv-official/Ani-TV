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
    final url = item['url']?.toString() ?? item['itemId']?.toString() ?? '';
    if (url.isEmpty) return;
    final category =
        (item['category'] ?? item['type'] ?? '').toString().toLowerCase();
    final page = {'comic', 'manga', 'manhwa', 'manhua'}.contains(category)
        ? ComicDetailsScreen(url: url, type: item['type']?.toString())
        : AnimeDetailsScreen(url: url);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _executeAction(AiAction action) {
    final payload = action.payload;
    if (action.type == 'open_content') {
      _openItem({'url': payload['url'], 'category': payload['category']});
    } else if (action.type == 'play_episode') {
      final url = payload['url']?.toString() ?? '';
      if (url.isEmpty) return;
      Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => VideoPlayerScreen(
                    url: url,
                    title: payload['title']?.toString() ?? 'حلقة',
                    episodeId: payload['episodeId']?.toString() ?? url,
                  )));
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = OpenRouterConfig.fromEnvironment().isConfigured;
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('مساعد AniTV'),
        backgroundColor: AppTheme.backgroundColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          if (!configured)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange.withOpacity(.35)),
              ),
              child: const Text(
                'يحتاج المساعد إلى إعداد OPENROUTER_API_KEY عبر dart-define قبل الاستخدام.',
                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
              ),
            ),
          Expanded(
            child: _entries.isEmpty
                ? _empty()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: _entries.length,
                    itemBuilder: (_, index) => _bubble(_entries[index]),
                  ),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 5),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text('يفكر المساعد ويبحث في المصادر...',
                    style: TextStyle(
                        color: AppTheme.textSecondaryColor, fontSize: 12)),
              ),
            ),
          _composer(),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppTheme.primaryColor, size: 58),
              const SizedBox(height: 14),
              const Text('ماذا تريد أن تشاهد أو تقرأ?',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('جرّب: ابحث عن Naruto أو هات آخر فصل من مانجا معينة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppTheme.textSecondaryColor)),
            ],
          ),
        ),
      );

  Widget _bubble(_ChatEntry entry) => Align(
        alignment: entry.user
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          constraints: const BoxConstraints(maxWidth: 360),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: entry.user
                ? AppTheme.primaryColor.withOpacity(.24)
                : AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: entry.user
                    ? AppTheme.primaryColor.withOpacity(.5)
                    : AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.reply?.text ?? entry.text,
                  style: TextStyle(
                      color: entry.reply?.isError == true
                          ? Colors.orangeAccent
                          : Colors.white,
                      height: 1.45)),
              if (entry.reply?.items.isNotEmpty == true)
                ...entry.reply!.items.take(8).map(_resultCard),
              if (entry.reply?.action != null)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () => _executeAction(entry.reply!.action!),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: Text(entry.reply!.action!.type == 'play_episode'
                        ? 'تشغيل'
                        : 'فتح'),
                  ),
                ),
            ],
          ),
        ),
      );

  Widget _resultCard(Map<String, dynamic> item) {
    final title = item['title']?.toString() ??
        item['name']?.toString() ??
        item['_ai_message']?.toString() ??
        'نتيجة';
    final url = item['url']?.toString() ?? '';
    return InkWell(
      onTap: url.isEmpty ? null : () => _openItem(item),
      child: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Row(
          children: [
            const Icon(Icons.movie_outlined,
                color: AppTheme.primaryColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
                child: Text(title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white70, fontWeight: FontWeight.w700))),
            if (url.isNotEmpty)
              const Icon(Icons.chevron_left, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _composer() => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _input,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _send(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'اكتب طلبك...',
                    hintStyle:
                        const TextStyle(color: AppTheme.textSecondaryColor),
                    filled: true,
                    fillColor: AppTheme.surfaceColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 15, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loading ? null : _send,
                style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white),
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ),
      );
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
