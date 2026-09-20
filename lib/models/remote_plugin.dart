import 'dart:convert';

const defaultRepositoryUrl = 'https://raw.githubusercontent.com/Abodabodd/re-3arabi/refs/heads/main/repo.json';
const repositoriesStorageKey = 'remote-repositories-v1';
const installedPluginsStorageKey = 'remote-installed-plugins-v1';

class RemotePlugin {
  final String name;
  final String internalName;
  final String description;
  final String downloadUrl;
  final String iconUrl;
  final String language;
  final String repositoryUrl;
  final String fileHash;
  final int version;
  final int fileSize;
  final List<String> tvTypes;

  const RemotePlugin({required this.name, required this.internalName, required this.description, required this.downloadUrl, required this.iconUrl, required this.language, required this.repositoryUrl, required this.fileHash, required this.version, required this.fileSize, required this.tvTypes});

  factory RemotePlugin.fromJson(Map<String, dynamic> json) => RemotePlugin(
    name: (json['name'] ?? json['internalName'] ?? 'إضافة بدون اسم').toString(),
    internalName: (json['internalName'] ?? json['name'] ?? '').toString(),
    description: (json['description'] ?? '').toString(),
    downloadUrl: (json['url'] ?? '').toString(),
    iconUrl: (json['iconUrl'] ?? '').toString(),
    language: (json['language'] ?? '').toString(),
    repositoryUrl: (json['repositoryUrl'] ?? '').toString(),
    fileHash: (json['fileHash'] ?? '').toString(),
    version: int.tryParse('${json['version'] ?? 1}') ?? 1,
    fileSize: int.tryParse('${json['fileSize'] ?? 0}') ?? 0,
    tvTypes: json['tvTypes'] is List ? (json['tvTypes'] as List).map((e) => e.toString()).toList() : const [],
  );

  Map<String, dynamic> toJson() => {'name': name, 'internalName': internalName, 'description': description, 'url': downloadUrl, 'iconUrl': iconUrl, 'language': language, 'repositoryUrl': repositoryUrl, 'fileHash': fileHash, 'version': version, 'fileSize': fileSize, 'tvTypes': tvTypes};
  String get stableId => '$repositoryUrl|$internalName|$downloadUrl';
  bool get isCloudstream => downloadUrl.toLowerCase().endsWith('.cs3');
}

class SourceRepository {
  final String url;
  final String name;
  final String description;
  final List<RemotePlugin> plugins;
  final DateTime updatedAt;

  const SourceRepository({required this.url, required this.name, required this.description, required this.plugins, required this.updatedAt});

  SourceRepository copyWith({List<RemotePlugin>? plugins}) => SourceRepository(url: url, name: name, description: description, plugins: plugins ?? this.plugins, updatedAt: DateTime.now());
}

SourceRepository repositoryFromJson(Map<String, dynamic> json) => SourceRepository(
  url: (json['url'] ?? '').toString(),
  name: (json['name'] ?? 'مستودع بدون اسم').toString(),
  description: (json['description'] ?? '').toString(),
  updatedAt: DateTime.tryParse('${json['updatedAt'] ?? ''}') ?? DateTime.now(),
  plugins: json['plugins'] is List ? (json['plugins'] as List).whereType<Map>().map((e) => RemotePlugin.fromJson(Map<String, dynamic>.from(e))).toList() : const [],
);

Map<String, dynamic> repositoryToJson(SourceRepository repository) => {'url': repository.url, 'name': repository.name, 'description': repository.description, 'updatedAt': repository.updatedAt.toIso8601String(), 'plugins': repository.plugins.map((e) => e.toJson()).toList()};
String encodeRepository(SourceRepository repository) => jsonEncode(repositoryToJson(repository));
SourceRepository decodeRepository(String raw) => repositoryFromJson(jsonDecode(raw) as Map<String, dynamic>);
String installedPluginsJson(Iterable<RemotePlugin> plugins) => jsonEncode(plugins.map((e) => e.toJson()).toList());
List<RemotePlugin> installedPluginsFromJson(String raw) => (jsonDecode(raw) as List).whereType<Map>().map((e) => RemotePlugin.fromJson(Map<String, dynamic>.from(e))).toList();
String repositoryUrlsJson(Iterable<String> urls) => jsonEncode(urls.toList());
List<String> repositoryUrlsFromJson(String raw) => (jsonDecode(raw) as List).map((e) => e.toString()).toList();

String repositoryHost(String url) => Uri.tryParse(url)?.host ?? url;
bool isValidHttpUrl(String value) { final uri = Uri.tryParse(value.trim()); return uri != null && (uri.scheme == 'http' || uri.scheme == 'https') && uri.host.isNotEmpty; }
String pluginTypeLabel(List<String> types) => types.map((type) => switch (type.toLowerCase()) {'anime' => 'أنمي', 'movie' => 'أفلام', 'tvseries' => 'مسلسلات', 'asiandrama' || 'drama' => 'دراما', 'live' => 'مباشر', _ => type}).toSet().join(' • ');
String formatPluginSize(int bytes) => bytes <= 0 ? '' : bytes < 1024 * 1024 ? '${(bytes / 1024).toStringAsFixed(1)} KB' : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
String pluginLanguageLabel(String language) => language.toLowerCase() == 'ar' ? 'عربي' : language.toUpperCase();
String pluginDescription(RemotePlugin plugin) => plugin.description.trim().isEmpty ? 'لا يوجد وصف متاح.' : plugin.description.trim();
String displayRepositoryName(SourceRepository repository) => repository.name.trim().isEmpty ? repositoryHost(repository.url) : repository.name.trim();
String displayPluginName(RemotePlugin plugin) => plugin.name.trim().isEmpty ? plugin.internalName : plugin.name;
String pluginSummary(RemotePlugin plugin) => [pluginTypeLabel(plugin.tvTypes), pluginLanguageLabel(plugin.language), formatPluginSize(plugin.fileSize)].where((e) => e.isNotEmpty).join(' • ');
String shortHash(String hash) { final value = hash.startsWith('sha256-') ? hash.substring(7) : hash; return value.length > 12 ? '${value.substring(0, 12)}…' : value; }
String pluginHashLabel(RemotePlugin plugin) => plugin.fileHash.isEmpty ? 'غير متاح' : shortHash(plugin.fileHash);
String pluginPhaseLabel(RemotePlugin plugin) => plugin.isCloudstream ? phaseOneNotice : phaseTwoNotice;
String repositoryDescription(SourceRepository repository) => repository.description.trim().isEmpty ? 'لا يوجد وصف للمستودع.' : repository.description.trim();
String phaseOneNotice = 'المرحلة الأولى تحفظ بيانات الإضافة محلياً ولا تشغّل ملفات DEX بعد.';
String phaseTwoNotice = 'سيتم تشغيل مصادر مختارة بعد إضافة طبقة التوافق في المرحلة الثانية.';
String pluginFileLabel(RemotePlugin plugin) => plugin.downloadUrl.split('/').last;
String pluginSourceLabel(RemotePlugin plugin) => repositoryHost(plugin.repositoryUrl);
String pluginVersionLabel(RemotePlugin plugin) => 'الإصدار ${plugin.version}';
String pluginStatusLabel(bool installed) => installed ? 'مثبت' : 'متاح';
String pluginArchiveLabel(RemotePlugin plugin) => plugin.isCloudstream ? 'Cloudstream (.cs3)' : 'إضافة بعيدة';
String installedPluginCount(Iterable<RemotePlugin> plugins) => '${plugins.length} مثبتة';
String repositoryPluginCount(SourceRepository repository) => '${repository.plugins.length} إضافة';
List<RemotePlugin> uniquePlugins(Iterable<RemotePlugin> plugins) { final seen = <String>{}; return plugins.where((e) => seen.add(e.stableId)).toList(); }
const extensionMenuLabel = 'الإضافات';
const extensionRepositoryHint = 'رابط repo.json';
const extensionRepositoryInfo = 'يدعم صيغة Cloudstream repo.json وقوائم plugins.json.';
const extensionCloudstreamLabel = 'Cloudstream (.cs3)';
const extensionInstallDisclaimer = 'التثبيت الحالي يحفظ metadata فقط. تشغيل المحتوى سيكون في المرحلة الثانية.';
const extensionPhaseTwoLabel = 'سيتم تفعيل تشغيل المحتوى في المرحلة الثانية.';
const extensionAddRepositoryLabel = 'إضافة مستودع';
const extensionRefreshLabel = 'تحديث';
const extensionRemoveLabel = 'إزالة';
const extensionInstallLabel = 'تثبيت';
const extensionUninstallLabel = 'إلغاء التثبيت';
const extensionNoPlugins = 'لا توجد إضافات متاحة.';
const extensionNoRepositories = 'لم تتم إضافة أي مستودع بعد.';
const extensionNoInstalled = 'لم تثبت أي إضافة بعد.';
const extensionInvalidUrl = 'أدخل رابط HTTP أو HTTPS صحيحاً.';
const extensionLoadError = 'تعذر تحميل المستودع. تحقق من الرابط والاتصال.';
const extensionRepositoryAdded = 'تمت إضافة المستودع.';
const extensionRepositoryRemoved = 'تم حذف المستودع.';
const extensionRepositoryUpdated = 'تم تحديث المستودع.';
const extensionInstallSuccess = 'تم تثبيت بيانات الإضافة.';
const extensionUninstallSuccess = 'تمت إزالة الإضافة من الجهاز.';
const extensionPhaseOneTitle = 'المرحلة الأولى';
const extensionPhaseTwoTitle = 'المرحلة الثانية';
const extensionSecurityNote = 'لا يتم تنفيذ DEX محمّل من الإنترنت في المرحلة الأولى.';
const extensionFutureAdapter = 'ContentSource';
const extensionFutureRegistry = 'SourceRegistry';
const extensionDefaultRepositoryName = '3rabi عربي';
const extensionDefaultRepositoryDescription = 'مشاهدة الافلام والمسلسلات تجربة خالية من الاعلانات';
const extensionRepositoryManifest = 'repo.json';
const extensionPluginListManifest = 'plugins.json';
const extensionCatalogOwner = 'Abodabodd/re-3arabi';
const extensionCatalogExpectedCount = 39;
const extensionCatalogDefaultPluginList = 'https://raw.githubusercontent.com/Abodabodd/re-3arabi/refs/heads/builds/plugins.json';
const extensionCatalogPhaseOneCommit = 'feat: add remote extension repository manager';
const extensionCatalogPhaseTwoCommit = 'feat: enable selected remote source adapters';
const extensionNavigationStatus = 'community-removed-extensions-added';
const extensionRuntimeStatus = 'disabled-until-phase-two';
const extensionPersistenceStatus = 'shared-preferences-json';
const extensionSchema = 'repo.json -> pluginLists -> plugins.json';
const extensionArchive = '.cs3';
const extensionMetadataOnly = true;
const extensionDexExecutionEnabled = false;
const extensionModelVersion = 1;
const extensionApiVersion = 1;
const extensionCatalogStatus = 'phase-one';
const extensionCatalogNext = 'phase-two';
const extensionCatalogMarker = 'anitv-remote-extension-catalog';
