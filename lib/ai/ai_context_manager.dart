class AiContextSnapshot {
  final String screen;
  final Map<String, dynamic>? content;
  final Map<String, dynamic>? episode;
  final Map<String, dynamic>? chapter;

  const AiContextSnapshot(
      {this.screen = 'unknown', this.content, this.episode, this.chapter});

  Map<String, dynamic> toJson() => {
        'screen': screen,
        if (content != null) 'content': _safe(content!),
        if (episode != null) 'episode': _safe(episode!),
        if (chapter != null) 'chapter': _safe(chapter!),
      };

  static Map<String, dynamic> _safe(Map<String, dynamic> value) => {
        for (final entry in value.entries)
          if (!const {'password', 'secret', 'token', 'apiKey'}
              .contains(entry.key))
            entry.key: entry.value,
      };
}

class AiContextManager {
  AiContextSnapshot _current = const AiContextSnapshot();
  AiContextSnapshot get current => _current;

  void update(
      {String? screen,
      Map<String, dynamic>? content,
      Map<String, dynamic>? episode,
      Map<String, dynamic>? chapter}) {
    _current = AiContextSnapshot(
      screen: screen ?? _current.screen,
      content: content ?? _current.content,
      episode: episode ?? _current.episode,
      chapter: chapter ?? _current.chapter,
    );
  }

  void clear() => _current = const AiContextSnapshot();
}
