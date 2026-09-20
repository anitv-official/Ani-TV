import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/remote_plugin.dart';

class RemoteRepositoryService {
  static const _timeout = Duration(seconds: 30);

  Future<SourceRepository> fetchRepository(String url) async {
    final manifest = await _getJson(url);
    final pluginListUrls = _pluginListUrls(manifest, url);
    final plugins = <RemotePlugin>[];
    for (final listUrl in pluginListUrls) {
      final payload = await _getJson(listUrl);
      final values = payload is List ? payload : (payload is Map ? payload['plugins'] : null);
      if (values is List) {
        plugins.addAll(values.whereType<Map>().map((item) {
          final data = Map<String, dynamic>.from(item);
          data['repositoryUrl'] ??= url;
          return RemotePlugin.fromJson(data);
        }));
      }
    }
    final map = manifest is Map ? Map<String, dynamic>.from(manifest) : <String, dynamic>{};
    return SourceRepository(
      url: url,
      name: (map['name'] ?? extensionDefaultRepositoryName).toString(),
      description: (map['description'] ?? extensionDefaultRepositoryDescription).toString(),
      plugins: uniquePlugins(plugins),
      updatedAt: DateTime.now(),
    );
  }

  Future<List<String>> savedUrls() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getStringList(repositoriesStorageKey) ?? const [];
  }

  Future<List<SourceRepository>> loadSavedRepositories() async {
    final urls = await savedUrls();
    final result = <SourceRepository>[];
    for (final url in urls) {
      try {
        final raw = (await SharedPreferences.getInstance()).getString('repository:$url');
        if (raw != null) result.add(decodeRepository(raw));
      } catch (_) {}
    }
    return result;
  }

  Future<void> saveRepository(SourceRepository repository) async {
    final preferences = await SharedPreferences.getInstance();
    final urls = {...(preferences.getStringList(repositoriesStorageKey) ?? const <String>[]), repository.url}.toList();
    await preferences.setStringList(repositoriesStorageKey, urls);
    await preferences.setString('repository:${repository.url}', encodeRepository(repository));
  }

  Future<void> removeRepository(String url) async {
    final preferences = await SharedPreferences.getInstance();
    final urls = (preferences.getStringList(repositoriesStorageKey) ?? const <String>[]).where((item) => item != url).toList();
    await preferences.setStringList(repositoriesStorageKey, urls);
    await preferences.remove('repository:$url');
  }

  Future<List<RemotePlugin>> installedPlugins() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(installedPluginsStorageKey);
    return raw == null ? const [] : installedPluginsFromJson(raw);
  }

  Future<void> setInstalled(RemotePlugin plugin, bool installed) async {
    final current = (await installedPlugins()).where((item) => item.stableId != plugin.stableId).toList();
    if (installed) current.add(plugin);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(installedPluginsStorageKey, installedPluginsJson(current));
  }

  Future<dynamic> _getJson(String url) async {
    final response = await http.get(Uri.parse(url), headers: {'Accept': 'application/json'}).timeout(_timeout);
    if (response.statusCode < 200 || response.statusCode >= 300) throw Exception('HTTP ${response.statusCode}');
    return jsonDecode(response.body);
  }

  List<String> _pluginListUrls(dynamic manifest, String baseUrl) {
    if (manifest is List) return manifest.map((item) => _resolve(item.toString(), baseUrl)).toList();
    if (manifest is! Map) return const [];
    final values = manifest['pluginLists'] ?? manifest['plugins'] ?? manifest['pluginList'];
    if (values is List) return values.whereType<String>().map((item) => _resolve(item, baseUrl)).toList();
    if (values is String) return [_resolve(values, baseUrl)];
    return const [];
  }

  String _resolve(String value, String baseUrl) => Uri.parse(baseUrl).resolve(value).toString();
}

final remoteRepositoryService = RemoteRepositoryService();
