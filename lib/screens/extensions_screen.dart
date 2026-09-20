import 'package:flutter/material.dart';
import '../models/remote_plugin.dart';
import '../services/remote_repository_service.dart';
import '../sources/source_registry.dart';
import '../theme/app_theme.dart';
import 'fasel_explore_screen.dart';
import 'sources_screen.dart';

class ExtensionsScreen extends StatefulWidget {
  final bool embedded;
  const ExtensionsScreen({super.key, this.embedded = false});
  @override
  State<ExtensionsScreen> createState() => _ExtensionsScreenState();
}

class _ExtensionsScreenState extends State<ExtensionsScreen> {
  final _urlController = TextEditingController(text: defaultRepositoryUrl);
  final _service = remoteRepositoryService;
  List<SourceRepository> _repositories = [];
  List<RemotePlugin> _installed = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _urlController.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repositories = await _service.loadSavedRepositories();
      final installed = await _service.installedPlugins();
      if (repositories.isEmpty) {
        final repository = await _service.fetchRepository(defaultRepositoryUrl);
        await _service.saveRepository(repository);
        repositories.add(repository);
      }
      if (mounted) setState(() { _repositories = repositories; _installed = installed; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = extensionLoadError; });
    }
  }

  Future<void> _addRepository() async {
    final url = _urlController.text.trim();
    if (!isValidHttpUrl(url)) { setState(() => _error = extensionInvalidUrl); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final repository = await _service.fetchRepository(url);
      await _service.saveRepository(repository);
      _urlController.text = defaultRepositoryUrl;
      await _load();
    } catch (_) { if (mounted) setState(() { _loading = false; _error = extensionLoadError; }); }
  }

  Future<void> _refresh(SourceRepository repository) async {
    try {
      final updated = await _service.fetchRepository(repository.url);
      await _service.saveRepository(updated);
      await _load();
    } catch (_) { if (mounted) setState(() => _error = extensionLoadError); }
  }

  Future<void> _toggle(RemotePlugin plugin) async {
    final installed = _installed.any((item) => item.stableId == plugin.stableId);
    setState(() { _loading = true; _error = null; });
    try {
      if (installed) {
        await _service.uninstallPlugin(_installed.firstWhere((item) => item.stableId == plugin.stableId));
      } else {
        await _service.installPlugin(plugin);
      }
      await _load();
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'تعذر تثبيت الإضافة أو فشل التحقق من SHA-256.'; });
    }
  }

  void _openPlugin(RemotePlugin plugin) {
    final source = SourceRegistry.sourceForPlugin(plugin);
    if (source == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تثبيت الإضافة، لكن لا يوجد محول أصلي لها داخل AniTV حتى الآن.')));
      return;
    }
    final page = source.id == 'fasel_hd' ? const FaselExploreScreen() : SourceContentScreen(source: source);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _showPluginDetails(RemotePlugin plugin) async {
    final installed = _installed.any((item) => item.stableId == plugin.stableId);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (plugin.iconUrl.isNotEmpty) CircleAvatar(backgroundImage: NetworkImage(plugin.iconUrl)) else const CircleAvatar(child: Icon(Icons.extension_outlined)),
            const SizedBox(width: 12),
            Expanded(child: Text(displayPluginName(plugin), style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(sheetContext), icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 14),
          Text(pluginDescription(plugin), style: const TextStyle(color: AppTheme.textSecondaryColor, height: 1.5)),
          const SizedBox(height: 12),
          Text('الإصدار ${plugin.version} • ${pluginLanguageLabel(plugin.language)} • ${pluginArchiveLabel(plugin)}', style: const TextStyle(color: AppTheme.primaryColor)),
          if (plugin.fileHash.isNotEmpty) ...[const SizedBox(height: 6), Text('التحقق: ${pluginHashLabel(plugin)}', style: const TextStyle(color: Colors.white54, fontSize: 12))],
          const SizedBox(height: 18),
          SizedBox(width: double.infinity, child: (installed ? OutlinedButton.icon : ElevatedButton.icon)(onPressed: () { Navigator.pop(sheetContext); _toggle(plugin); }, icon: Icon(installed ? Icons.delete_outline : Icons.download), label: Text(installed ? extensionUninstallLabel : extensionInstallLabel))),
        ]),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      _intro(),
      const SizedBox(height: 16),
      _addForm(),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      const SizedBox(height: 20),
      if (_loading) const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()))
      else if (_repositories.isEmpty) const Center(child: Text(extensionNoRepositories))
      else ..._repositories.map(_repositoryCard),
    ]));
    return widget.embedded ? body : Scaffold(appBar: AppBar(title: const Text(extensionMenuLabel)), body: body);
  }

  Widget _intro() => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
    Text(extensionMenuLabel, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    SizedBox(height: 8),
    Text(extensionRepositoryInfo, style: TextStyle(color: AppTheme.textSecondaryColor)),
    SizedBox(height: 8),
    Text('مصادر موثوقة قابلة للتثبيت والتحقق قبل الاستخدام.', style: TextStyle(color: AppTheme.primaryColor, height: 1.4)),
  ])));

  Widget _addForm() => Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
    Expanded(child: TextField(controller: _urlController, textDirection: TextDirection.ltr, decoration: const InputDecoration(labelText: extensionRepositoryHint, prefixIcon: Icon(Icons.link)))),
    const SizedBox(width: 8),
    IconButton(onPressed: _loading ? null : _addRepository, tooltip: extensionAddRepositoryLabel, icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryColor)),
  ])));

  Widget _repositoryCard(SourceRepository repository) => Card(margin: const EdgeInsets.only(bottom: 14), child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [Expanded(child: Text(displayRepositoryName(repository), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))), IconButton(onPressed: () => _refresh(repository), icon: const Icon(Icons.refresh))]),
    Text(repositoryDescription(repository), style: const TextStyle(color: AppTheme.textSecondaryColor)),
    const SizedBox(height: 8),
    Text('${repository.plugins.length} إضافة • ${repositoryHost(repository.url)}', style: const TextStyle(color: AppTheme.primaryColor)),
    const SizedBox(height: 8),
    ...repository.plugins.map(_pluginTile),
  ])));

  Widget _pluginTile(RemotePlugin plugin) {
    final installed = _installed.any((item) => item.stableId == plugin.stableId);
    return GestureDetector(
      onLongPress: () => _showPluginDetails(plugin),
      child: ListTile(contentPadding: EdgeInsets.zero, onTap: installed ? () => _openPlugin(plugin) : () => _showPluginDetails(plugin), leading: plugin.iconUrl.isEmpty ? const CircleAvatar(child: Icon(Icons.extension_outlined)) : CircleAvatar(backgroundImage: NetworkImage(plugin.iconUrl)), title: Text(displayPluginName(plugin), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${pluginSummary(plugin)}\n${installed ? 'مثبت — اضغط لفتح المصدر' : 'اضغط لعرض التفاصيل والتثبيت'}', maxLines: 2, overflow: TextOverflow.ellipsis), isThreeLine: true, trailing: TextButton(onPressed: () => _toggle(plugin), child: Text(installed ? extensionUninstallLabel : extensionInstallLabel))),
    );
  }
}
