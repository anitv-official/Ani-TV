import 'package:flutter/material.dart';
import '../models/remote_plugin.dart';
import '../services/remote_repository_service.dart';
import '../theme/app_theme.dart';

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
    Text(extensionPhaseTwoLabel, style: TextStyle(color: AppTheme.primaryColor, height: 1.4)),
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
    return ListTile(contentPadding: EdgeInsets.zero, leading: plugin.iconUrl.isEmpty ? const CircleAvatar(child: Icon(Icons.extension_outlined)) : CircleAvatar(backgroundImage: NetworkImage(plugin.iconUrl)), title: Text(displayPluginName(plugin), maxLines: 1, overflow: TextOverflow.ellipsis), subtitle: Text('${pluginSummary(plugin)}\n${pluginPhaseLabel(plugin)}', maxLines: 2, overflow: TextOverflow.ellipsis), isThreeLine: true, trailing: TextButton(onPressed: () => _toggle(plugin), child: Text(installed ? extensionUninstallLabel : extensionInstallLabel)));
  }
}
