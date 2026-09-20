import 'package:flutter/services.dart';

class CloudStreamEngineService {
  static const MethodChannel _channel = MethodChannel('com.anitv.app/cloudstream');

  static Future<Map<String, dynamic>> engineInfo() async =>
      Map<String, dynamic>.from(await _channel.invokeMethod('engineInfo') as Map);

  static Future<List<Map<String, dynamic>>> listInstalledPlugins() async {
    final raw = await _channel.invokeMethod<List<dynamic>>('listInstalledPlugins') ?? const [];
    return raw.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<Map<String, dynamic>> inspectPlugin(String path) async {
    final raw = await _channel.invokeMethod('inspectPlugin', {'path': path});
    return Map<String, dynamic>.from(raw as Map);
  }

  static Future<Map<String, dynamic>> loadPlugin(String path) async {
    final raw = await _channel.invokeMethod('loadPlugin', {'path': path});
    return Map<String, dynamic>.from(raw as Map);
  }
}
