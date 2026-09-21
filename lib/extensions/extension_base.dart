import '../sources/source_base.dart';

/// حالة Extension المعروضة للمستخدم. لا تحتوي على أدوات اختبار أو تشخيص.
enum ExtensionStatus { available, limited, unavailable }

extension ExtensionStatusLabel on ExtensionStatus {
  String get label => switch (this) {
        ExtensionStatus.available => 'متاح',
        ExtensionStatus.limited => 'متاح جزئياً',
        ExtensionStatus.unavailable => 'غير متاح',
      };

  bool get isAvailable => this != ExtensionStatus.unavailable;
}

/// عقد موحد للمصادر التي تظهر في صفحة الإضافات.
abstract class AniExtension extends ContentSource {
  String get contentLabel;
  String get iconUrl;
  ExtensionStatus get status;
  String get statusMessage;

  Map<String, dynamic> get extensionMetadata => {
        'id': id,
        'name': name,
        'content_label': contentLabel,
        'icon_url': iconUrl,
        'status': status.label,
        'status_message': statusMessage,
      };
}
